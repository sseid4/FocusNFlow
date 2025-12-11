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
          .where((room) =>
              amenities.every((amenity) => room.amenities.contains(amenity)))
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
    return _firestore.collection(collectionPath).snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => StudyRoom.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Real-time single room stream
  Stream<StudyRoom> streamRoomById(String roomId) {
    return _firestore
        .collection(collectionPath)
        .doc(roomId)
        .snapshots()
        .map((doc) {
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

        final room =
            StudyRoom.fromJson({...roomSnapshot.data()!, 'id': roomSnapshot.id});

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
        }, SetOptions(merge: true),
        );
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

        final room =
            StudyRoom.fromJson({...roomSnapshot.data()!, 'id': roomSnapshot.id});

        // Update room occupancy (minimum 0)
        final newOccupancy = (room.currentOccupancy - 1).clamp(0, room.capacity);

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
            .update({
          'checkOutTime': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      throw Exception('Failed to check out: $e');
    }
  }

  // Get room occupancy history
  Future<List<Map<String, dynamic>>> getRoomOccupancyHistory(
      String roomId) async {
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
      final docRef = await _firestore.collection(collectionPath).add(
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
}
