import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/study_room.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionPath = 'studyRooms';
  static const String occupancyPath = 'occupancy';

  // Get all study rooms
  Future<List<StudyRoom>> getAllRooms() async {
    try {
      final snapshot = await _firestore.collection(collectionPath).get();
      return snapshot.docs
          .map((doc) => StudyRoom.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch rooms: $e');
    }
  }

  // Get rooms by building
  Future<List<StudyRoom>> getRoomsByBuilding(String building) async {
    try {
      final snapshot = await _firestore
          .collection(collectionPath)
          .where('building', isEqualTo: building)
          .get();
      return snapshot.docs
          .map((doc) => StudyRoom.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch rooms by building: $e');
    }
  }

  // Get available rooms (with space)
  Future<List<StudyRoom>> getAvailableRooms() async {
    try {
      final snapshot = await _firestore
          .collection(collectionPath)
          .where('isAvailable', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => StudyRoom.fromJson({...doc.data(), 'id': doc.id}))
          .where((room) => room.hasSpace)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch available rooms: $e');
    }
  }

  // Get rooms with specific amenities
  Future<List<StudyRoom>> getRoomsByAmenities(List<String> amenities) async {
    try {
      final snapshot = await _firestore.collection(collectionPath).get();
      return snapshot.docs
          .map((doc) => StudyRoom.fromJson({...doc.data(), 'id': doc.id}))
          .where(
            (room) =>
                amenities.every((amenity) => room.amenities.contains(amenity)),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch rooms by amenities: $e');
    }
  }

  // Get single room details
  Future<StudyRoom> getRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection(collectionPath).doc(roomId).get();
      if (!doc.exists) {
        throw Exception('Room not found');
      }
      return StudyRoom.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to fetch room: $e');
    }
  }

  // Real-time room updates stream
  Stream<List<StudyRoom>> streamAllRooms() {
    return _firestore
        .collection(collectionPath)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudyRoom.fromJson({...doc.data(), 'id': doc.id}))
              .toList(),
        );
  }

  // Real-time single room stream
  Stream<StudyRoom> streamRoomById(String roomId) {
    return _firestore.collection(collectionPath).doc(roomId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) {
        throw Exception('Room not found');
      }
      return StudyRoom.fromJson({...doc.data()!, 'id': doc.id});
    });
  }

  // Check in user to room
  Future<void> checkInToRoom(String roomId, String userId) async {
    try {
      final roomDoc = _firestore.collection(collectionPath).doc(roomId);

      await _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomDoc);
        if (!roomSnapshot.exists) {
          throw Exception('Room not found');
        }

        final room = StudyRoom.fromJson({
          ...roomSnapshot.data()!,
          'id': roomSnapshot.id,
        });

        if (!room.hasSpace) {
          throw Exception('Room is full');
        }

        // Update room occupancy
        transaction.update(roomDoc, {
          'currentOccupancy': room.currentOccupancy + 1,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        // Record check-in
        await _firestore
            .collection(collectionPath)
            .doc(roomId)
            .collection(occupancyPath)
            .doc(userId)
            .set({
              'userId': userId,
              'checkInTime': DateTime.now().toIso8601String(),
              'checkOutTime': null,
            }, SetOptions(merge: true));
      });
    } catch (e) {
      throw Exception('Failed to check in: $e');
    }
  }

  // Check out user from room
  Future<void> checkOutFromRoom(String roomId, String userId) async {
    try {
      final roomDoc = _firestore.collection(collectionPath).doc(roomId);

      await _firestore.runTransaction((transaction) async {
        final roomSnapshot = await transaction.get(roomDoc);
        if (!roomSnapshot.exists) {
          throw Exception('Room not found');
        }

        final room = StudyRoom.fromJson({
          ...roomSnapshot.data()!,
          'id': roomSnapshot.id,
        });

        // Update room occupancy (minimum 0)
        final newOccupancy = (room.currentOccupancy - 1).clamp(
          0,
          room.capacity,
        );

        transaction.update(roomDoc, {
          'currentOccupancy': newOccupancy,
          'lastUpdated': DateTime.now().toIso8601String(),
        });

        // Record check-out
        await _firestore
            .collection(collectionPath)
            .doc(roomId)
            .collection(occupancyPath)
            .doc(userId)
            .update({'checkOutTime': DateTime.now().toIso8601String()});
      });
    } catch (e) {
      throw Exception('Failed to check out: $e');
    }
  }

  // Get room occupancy history
  Future<List<Map<String, dynamic>>> getRoomOccupancyHistory(
    String roomId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(collectionPath)
          .doc(roomId)
          .collection(occupancyPath)
          .orderBy('checkInTime', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to fetch occupancy history: $e');
    }
  }

  // Update room status
  Future<void> updateRoomStatus(String roomId, bool isAvailable) async {
    try {
      await _firestore.collection(collectionPath).doc(roomId).update({
        'isAvailable': isAvailable,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update room status: $e');
    }
  }

  // Create new room (admin function)
  Future<String> createRoom(StudyRoom room) async {
    try {
      final docRef = await _firestore
          .collection(collectionPath)
          .add(
            room.toJson()..['lastUpdated'] = DateTime.now().toIso8601String(),
          );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  // Delete room (admin function)
  Future<void> deleteRoom(String roomId) async {
    try {
      await _firestore.collection(collectionPath).doc(roomId).delete();
    } catch (e) {
      throw Exception('Failed to delete room: $e');
    }
  }

  // Enhanced: Create check-in session
  Future<String> createCheckInSession({
    required String roomId,
    required String userId,
    required String userName,
    String? groupId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final sessionId = _firestore.collection('checkInSessions').doc().id;
      final now = DateTime.now();

      // Check room capacity in transaction
      await _firestore.runTransaction((transaction) async {
        final roomRef = _firestore.collection(collectionPath).doc(roomId);
        final roomSnapshot = await transaction.get(roomRef);

        if (!roomSnapshot.exists) {
          throw Exception('Room not found');
        }

        final room = StudyRoom.fromJson({
          ...roomSnapshot.data()!,
          'id': roomSnapshot.id,
        });

        if (!room.hasSpace) {
          throw Exception('Room is full');
        }

        // Create check-in session
        transaction.set(
          _firestore.collection('checkInSessions').doc(sessionId),
          {
            'id': sessionId,
            'roomId': roomId,
            'userId': userId,
            'userName': userName,
            'checkInTime': now.toIso8601String(),
            'checkOutTime': null,
            'groupId': groupId,
            'metadata': metadata ?? {},
            'isActive': true,
          },
        );

        // Update room occupancy
        transaction.update(roomRef, {
          'currentOccupancy': room.currentOccupancy + 1,
          'lastUpdated': now.toIso8601String(),
        });

        // Track active sessions in room
        transaction.update(
          roomRef,
          {
            'activeSessions': FieldValue.arrayUnion([sessionId])
          },
        );
      });

      return sessionId;
    } catch (e) {
      throw Exception('Failed to create check-in session: $e');
    }
  }

  // Enhanced: End check-in session
  Future<void> endCheckInSession(String sessionId, String roomId) async {
    try {
      final now = DateTime.now();

      await _firestore.runTransaction((transaction) async {
        final sessionRef =
            _firestore.collection('checkInSessions').doc(sessionId);
        final roomRef = _firestore.collection(collectionPath).doc(roomId);

        final sessionSnapshot = await transaction.get(sessionRef);
        if (!sessionSnapshot.exists) {
          throw Exception('Session not found');
        }

        final roomSnapshot = await transaction.get(roomRef);
        if (!roomSnapshot.exists) {
          throw Exception('Room not found');
        }

        final room = StudyRoom.fromJson({
          ...roomSnapshot.data()!,
          'id': roomSnapshot.id,
        });

        // Update session
        transaction.update(sessionRef, {
          'checkOutTime': now.toIso8601String(),
          'isActive': false,
        });

        // Update room occupancy
        final newOccupancy = (room.currentOccupancy - 1).clamp(0, room.capacity);
        transaction.update(roomRef, {
          'currentOccupancy': newOccupancy,
          'lastUpdated': now.toIso8601String(),
        });

        // Remove from active sessions
        transaction.update(
          roomRef,
          {
            'activeSessions': FieldValue.arrayRemove([sessionId])
          },
        );
      });
    } catch (e) {
      throw Exception('Failed to end check-in session: $e');
    }
  }

  // Get active sessions in a room
  Future<List<Map<String, dynamic>>> getActiveSessionsInRoom(
    String roomId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('checkInSessions')
          .where('roomId', isEqualTo: roomId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to fetch active sessions: $e');
    }
  }

  // Get user's current check-in
  Future<Map<String, dynamic>?> getUserCurrentCheckIn(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('checkInSessions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }
      return snapshot.docs.first.data();
    } catch (e) {
      throw Exception('Failed to fetch user check-in: $e');
    }
  }

  // Get user's check-in history
  Future<List<Map<String, dynamic>>> getUserCheckInHistory(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('checkInSessions')
          .where('userId', isEqualTo: userId)
          .orderBy('checkInTime', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to fetch check-in history: $e');
    }
  }

  // Get room statistics
  Future<Map<String, dynamic>> getRoomStatistics(String roomId) async {
    try {
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).toIso8601String();

      final snapshot = await _firestore
          .collection('checkInSessions')
          .where('roomId', isEqualTo: roomId)
          .where('checkInTime', isGreaterThanOrEqualTo: startOfDay)
          .get();

      final sessions = snapshot.docs.map((doc) => doc.data()).toList();

      int totalCheckIns = sessions.length;
      final totalUniqueUsers = <String>{};
      Duration totalStudyTime = Duration.zero;

      for (var session in sessions) {
        // Count unique users
        final userId = session['userId'] as String?;
        if (userId != null) {
          totalUniqueUsers.add(userId);
        }

        // Calculate study time
        final checkInTime = DateTime.parse(session['checkInTime'] as String);
        final checkOutTime = session['checkOutTime'] != null
            ? DateTime.parse(session['checkOutTime'] as String)
            : DateTime.now();
        totalStudyTime = totalStudyTime + checkOutTime.difference(checkInTime);
      }

      return {
        'totalCheckIns': totalCheckIns,
        'uniqueUsers': totalUniqueUsers.length,
        'totalStudyTime': totalStudyTime.inMinutes,
        'averageSessionTime':
            totalCheckIns > 0 ? totalStudyTime.inMinutes ~/ totalCheckIns : 0,
      };
    } catch (e) {
      throw Exception('Failed to fetch room statistics: $e');
    }
  }
}
