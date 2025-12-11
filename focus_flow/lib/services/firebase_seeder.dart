import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/services/seed_data.dart';

class FirebaseSeeder {
  static const String _seededKey = 'firebaseSeeded';

  static Future<void> seedIfNeeded() async {
    final prefs = await _getPrefs();
    final isSeeded = prefs['seeded'] ?? false;

    if (!isSeeded) {
      await seedGSUStudyRooms();
      await seedGSUStudyGroups();
      prefs['seeded'] = true;
    }
  }

  static Future<Map<String, dynamic>> _getPrefs() async {
    // For now, we'll use Firestore to track if seeding is done
    // In a real app, you'd use SharedPreferences
    return {};
  }

  static Future<void> seedGSUStudyRooms() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final roomsCollection = firestore.collection('studyRooms');

      for (var room in SeedData.gsuStudyRooms) {
        final docRef = roomsCollection.doc(room.id);
        batch.set(docRef, room.toJson());
      }

      await batch.commit();
      print('✓ GSU study rooms seeded successfully');
    } catch (e) {
      print('✗ Error seeding data: $e');
    }
  }

  static Future<void> clearAllRooms() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('studyRooms').get();
      final batch = firestore.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✓ All rooms cleared');
    } catch (e) {
      print('✗ Error clearing rooms: $e');
    }
  }

  static Future<void> seedGSUStudyGroups() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final groupsCollection = firestore.collection('groups');

      for (var group in SeedData.gsuStudyGroups) {
        final docRef = groupsCollection.doc(group.id);
        batch.set(docRef, group.toJson());
      }

      await batch.commit();
      print('✓ GSU study groups seeded successfully');
    } catch (e) {
      print('✗ Error seeding study groups: $e');
    }
  }

  static Future<void> clearAllGroups() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('groups').get();
      final batch = firestore.batch();

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✓ All study groups cleared');
    } catch (e) {
      print('✗ Error clearing study groups: $e');
    }
  }
}
