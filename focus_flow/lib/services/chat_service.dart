import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String groupsCollection = 'groups';
  static const String messagesSubcollection = 'messages';

  // Send a new message
  Future<String> sendMessage({
    required String groupId,
    required String userId,
    required String senderName,
    required String content,
  }) async {
    try {
      if (content.trim().isEmpty) {
        throw Exception('Message cannot be empty');
      }

      final messageRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .doc();

      final message = ChatMessage(
        id: messageRef.id,
        groupId: groupId,
        userId: userId,
        senderName: senderName,
        content: content.trim(),
        timestamp: DateTime.now(),
      );

      await messageRef.set(message.toJson());
      return messageRef.id;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get message history (paginated)
  Future<List<ChatMessage>> getMessageHistory(
    String groupId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .orderBy('timestamp', descending: false)
          .limitToLast(limit)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch message history: $e');
    }
  }

  // Stream real-time messages
  Stream<List<ChatMessage>> streamGroupMessages(
    String groupId, {
    int limit = 50,
  }) {
    return _firestore
        .collection(groupsCollection)
        .doc(groupId)
        .collection(messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Edit message
  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newContent,
    required String userId,
  }) async {
    try {
      if (newContent.trim().isEmpty) {
        throw Exception('Message cannot be empty');
      }

      final messageRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final message = ChatMessage.fromJson({...messageDoc.data()!, 'id': messageId});
      if (message.userId != userId) {
        throw Exception('Only message author can edit');
      }

      await messageRef.update({
        'content': newContent.trim(),
        'isEdited': true,
        'editedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  // Delete message
  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw Exception('Message not found');
      }

      final message = ChatMessage.fromJson({...messageDoc.data()!, 'id': messageId});
      if (message.userId != userId) {
        throw Exception('Only message author can delete');
      }

      await messageRef.delete();
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Add reaction to message
  Future<void> addReaction({
    required String groupId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final messageRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final messageDoc = await transaction.get(messageRef);
        if (!messageDoc.exists) {
          throw Exception('Message not found');
        }

        final reactions =
            Map<String, int>.from(messageDoc.get('reactions') ?? {});
        reactions[emoji] = (reactions[emoji] ?? 0) + 1;

        transaction.update(messageRef, {'reactions': reactions});
      });
    } catch (e) {
      throw Exception('Failed to add reaction: $e');
    }
  }

  // Remove reaction from message
  Future<void> removeReaction({
    required String groupId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final messageRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final messageDoc = await transaction.get(messageRef);
        if (!messageDoc.exists) {
          throw Exception('Message not found');
        }

        final reactions =
            Map<String, int>.from(messageDoc.get('reactions') ?? {});
        if (reactions.containsKey(emoji)) {
          reactions[emoji] = reactions[emoji]! - 1;
          if (reactions[emoji]! <= 0) {
            reactions.remove(emoji);
          }
        }

        transaction.update(messageRef, {'reactions': reactions});
      });
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount(
    String groupId,
    DateTime lastReadTime,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .where('timestamp', isGreaterThan: lastReadTime)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }

  // Delete all messages in a group (admin only)
  Future<void> clearGroupMessages(String groupId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(messagesSubcollection)
          .get();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear messages: $e');
    }
  }
}
