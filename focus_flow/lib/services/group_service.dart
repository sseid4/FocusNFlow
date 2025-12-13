import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/study_group.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String groupsCollection = 'groups';
  static const String usersCollection = 'users';

  // Get all groups for a specific course
  Future<List<StudyGroup>> getGroupsByCourse(String courseId) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .where('courseId', isEqualTo: courseId)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => StudyGroup.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch groups for course: $e');
    }
  }

  // Get user's groups
  Future<List<StudyGroup>> getUserGroups(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .where('memberIds', arrayContains: userId)
          .get();

      final groups = snapshot.docs
          .map((doc) => StudyGroup.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort in memory to avoid composite index requirement
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    } catch (e) {
      throw Exception('Failed to fetch user groups: $e');
    }
  }

  // Stream user's groups for real-time updates
  Stream<List<StudyGroup>> streamUserGroups(String userId) {
    return _firestore
        .collection(groupsCollection)
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => StudyGroup.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
          // Sort in memory to avoid composite index requirement
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        });
  }

  // Get single group details
  Future<StudyGroup> getGroupById(String groupId) async {
    try {
      final doc = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .get();
      if (!doc.exists) {
        throw Exception('Group not found');
      }
      return StudyGroup.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to fetch group: $e');
    }
  }

  // Stream single group for real-time updates
  Stream<StudyGroup> streamGroupById(String groupId) {
    return _firestore.collection(groupsCollection).doc(groupId).snapshots().map(
      (doc) {
        if (!doc.exists) {
          throw Exception('Group not found');
        }
        return StudyGroup.fromJson({...doc.data()!, 'id': doc.id});
      },
    );
  }

  // Create new study group
  Future<String> createGroup({
    required String name,
    required String courseId,
    required String courseName,
    required String description,
    required String adminId,
    int maxMembers = 10,
    bool isPublic = true,
  }) async {
    try {
      final groupRef = await _firestore.collection(groupsCollection).add({
        'name': name,
        'courseId': courseId,
        'courseName': courseName,
        'description': description,
        'adminId': adminId,
        'memberIds': [adminId],
        'maxMembers': maxMembers,
        'isPublic': isPublic,
        'createdAt': DateTime.now().toIso8601String(),
        'settings': {
          'notificationsEnabled': true,
          'allowChat': true,
          'allowScheduling': true,
        },
      });

      // Update user's groups
      await _firestore
          .collection(usersCollection)
          .doc(adminId)
          .update({
            'groups': FieldValue.arrayUnion([groupRef.id]),
          })
          .catchError((_) {
            // User doc might not exist yet, that's okay
          });

      return groupRef.id;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }

  // Join a group
  Future<void> joinGroup(String groupId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final groupRef = _firestore.collection(groupsCollection).doc(groupId);
        final userRef = _firestore.collection(usersCollection).doc(userId);

        final groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) {
          throw Exception('Group not found');
        }

        final group = StudyGroup.fromJson({
          ...groupSnapshot.data()!,
          'id': groupId,
        });

        // Check if already a member
        if (group.memberIds.contains(userId)) {
          throw Exception('Already a member of this group');
        }

        // Check if group is full
        if (group.isFull) {
          throw Exception('Group is full');
        }

        // Add user to group
        transaction.update(groupRef, {
          'memberIds': FieldValue.arrayUnion([userId]),
        });

        // Add group to user's groups
        final userSnapshot = await transaction.get(userRef);
        if (userSnapshot.exists) {
          transaction.update(userRef, {
            'groups': FieldValue.arrayUnion([groupId]),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to join group: $e');
    }
  }

  // Leave a group
  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final groupRef = _firestore.collection(groupsCollection).doc(groupId);
        final userRef = _firestore.collection(usersCollection).doc(userId);

        final groupSnapshot = await transaction.get(groupRef);
        if (!groupSnapshot.exists) {
          throw Exception('Group not found');
        }

        final group = StudyGroup.fromJson({
          ...groupSnapshot.data()!,
          'id': groupId,
        });

        // Admin cannot leave without transferring ownership
        if (group.adminId == userId && group.memberIds.length > 1) {
          throw Exception('Admin cannot leave. Transfer ownership first.');
        }

        // Remove user from group
        transaction.update(groupRef, {
          'memberIds': FieldValue.arrayRemove([userId]),
        });

        // Remove group from user's groups
        transaction.update(userRef, {
          'groups': FieldValue.arrayRemove([groupId]),
        });

        // If admin leaves and group is empty, delete the group
        if (group.adminId == userId && group.memberIds.length == 1) {
          transaction.delete(groupRef);
        }
      });
    } catch (e) {
      throw Exception('Failed to leave group: $e');
    }
  }

  // Update group info
  Future<void> updateGroup(
    String groupId, {
    String? name,
    String? description,
    bool? isPublic,
    int? maxMembers,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (isPublic != null) updates['isPublic'] = isPublic;
      if (maxMembers != null) updates['maxMembers'] = maxMembers;

      if (updates.isNotEmpty) {
        await _firestore
            .collection(groupsCollection)
            .doc(groupId)
            .update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }

  // Delete group (admin only)
  Future<void> deleteGroup(String groupId, String userId) async {
    try {
      final groupDoc = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = StudyGroup.fromJson({...groupDoc.data()!, 'id': groupId});

      if (group.adminId != userId) {
        throw Exception('Only admin can delete group');
      }

      // Remove group from all members
      for (var memberId in group.memberIds) {
        await _firestore
            .collection(usersCollection)
            .doc(memberId)
            .update({
              'groups': FieldValue.arrayRemove([groupId]),
            })
            .catchError((_) {
              // User doc might not exist
            });
      }

      // Delete group
      await _firestore.collection(groupsCollection).doc(groupId).delete();
    } catch (e) {
      throw Exception('Failed to delete group: $e');
    }
  }

  // Transfer group admin to another member
  Future<void> transferAdmin(
    String groupId,
    String currentAdminId,
    String newAdminId,
  ) async {
    try {
      final groupRef = _firestore.collection(groupsCollection).doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = StudyGroup.fromJson({...groupDoc.data()!, 'id': groupId});

      if (group.adminId != currentAdminId) {
        throw Exception('Only current admin can transfer ownership');
      }

      if (!group.memberIds.contains(newAdminId)) {
        throw Exception('New admin must be a group member');
      }

      await groupRef.update({'adminId': newAdminId});
    } catch (e) {
      throw Exception('Failed to transfer admin: $e');
    }
  }

  // Search groups
  Future<List<StudyGroup>> searchGroups(String query) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .where('isPublic', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => StudyGroup.fromJson({...doc.data(), 'id': doc.id}))
          .where(
            (group) =>
                group.name.toLowerCase().contains(query.toLowerCase()) ||
                group.description.toLowerCase().contains(query.toLowerCase()) ||
                group.courseName.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to search groups: $e');
    }
  }

  // Get group members (returns user info if available)
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      final groupDoc = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final group = StudyGroup.fromJson({...groupDoc.data()!, 'id': groupId});
      final members = <Map<String, dynamic>>[];

      for (var memberId in group.memberIds) {
        try {
          final userDoc = await _firestore
              .collection(usersCollection)
              .doc(memberId)
              .get();
          if (userDoc.exists) {
            members.add({
              'id': memberId,
              'email': userDoc.data()?['email'],
              'displayName': userDoc.data()?['displayName'],
              'isAdmin': group.adminId == memberId,
            });
          }
        } catch (_) {
          // User not found, add placeholder
          members.add({
            'id': memberId,
            'email': 'Unknown',
            'displayName': 'Unknown User',
            'isAdmin': group.adminId == memberId,
          });
        }
      }

      return members;
    } catch (e) {
      throw Exception('Failed to fetch group members: $e');
    }
  }
}
