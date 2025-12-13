import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/study_session.dart';

class StudySessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String groupsCollection = 'groups';
  static const String sessionsSubcollection = 'sessions';
  static const String usersCollection = 'users';

  // Create a new study session
  Future<String> createSession({
    required String groupId,
    required String createdBy,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? description,
    String? agenda,
    bool isRecurring = false,
  }) async {
    try {
      if (startTime.isAfter(endTime)) {
        throw Exception('Start time must be before end time');
      }

      if (startTime.isBefore(DateTime.now())) {
        throw Exception('Start time must be in the future');
      }

      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .doc();

      final session = StudySession(
        id: sessionRef.id,
        groupId: groupId,
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        location: location,
        createdBy: createdBy,
        isRecurring: isRecurring,
        agenda: agenda,
        createdAt: DateTime.now(),
      );

      await sessionRef.set(session.toJson());
      return sessionRef.id;
    } catch (e) {
      throw Exception('Failed to create session: $e');
    }
  }

  // Get upcoming sessions for a group
  Future<List<StudySession>> getUpcomingSessions(String groupId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .where('startTime', isGreaterThanOrEqualTo: now.toIso8601String())
          .get();

      final sessions = snapshot.docs
          .map((doc) => StudySession.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort by start time
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      return sessions;
    } catch (e) {
      throw Exception('Failed to fetch upcoming sessions: $e');
    }
  }

  // Get past sessions for a group
  Future<List<StudySession>> getPastSessions(String groupId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .where('endTime', isLessThan: now.toIso8601String())
          .get();

      final sessions = snapshot.docs
          .map((doc) => StudySession.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Sort by start time (newest first)
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return sessions;
    } catch (e) {
      throw Exception('Failed to fetch past sessions: $e');
    }
  }

  // Stream upcoming sessions for real-time updates
  Stream<List<StudySession>> streamUpcomingSessions(String groupId) {
    return _firestore
        .collection(groupsCollection)
        .doc(groupId)
        .collection(sessionsSubcollection)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final sessions = snapshot.docs
          .map((doc) => StudySession.fromJson({...doc.data(), 'id': doc.id}))
          .where((session) => session.startTime.isAfter(now))
          .toList();

      // Sort by start time
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      return sessions;
    });
  }

  // Get a specific session
  Future<StudySession> getSession(String groupId, String sessionId) async {
    try {
      final doc = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .doc(sessionId)
          .get();

      if (!doc.exists) {
        throw Exception('Session not found');
      }

      return StudySession.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to fetch session: $e');
    }
  }

  // Update session (only creator can update)
  Future<void> updateSession({
    required String groupId,
    required String sessionId,
    required String userId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    String? agenda,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .doc(sessionId);

      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session =
          StudySession.fromJson({...sessionDoc.data()!, 'id': sessionId});
      if (session.createdBy != userId) {
        throw Exception('Only creator can update session');
      }

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (startTime != null) updates['startTime'] = startTime.toIso8601String();
      if (endTime != null) updates['endTime'] = endTime.toIso8601String();
      if (location != null) updates['location'] = location;
      if (description != null) updates['description'] = description;
      if (agenda != null) updates['agenda'] = agenda;

      await sessionRef.update(updates);
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  // Delete session (only creator can delete)
  Future<void> deleteSession({
    required String groupId,
    required String sessionId,
    required String userId,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .doc(sessionId);

      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final session =
          StudySession.fromJson({...sessionDoc.data()!, 'id': sessionId});
      if (session.createdBy != userId) {
        throw Exception('Only creator can delete session');
      }

      await sessionRef.delete();
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  // RSVP to a session
  Future<void> rsvpToSession({
    required String groupId,
    required String sessionId,
    required String userId,
    required String status, // 'yes', 'no', 'maybe'
  }) async {
    try {
      if (!['yes', 'no', 'maybe'].contains(status)) {
        throw Exception('Invalid RSVP status');
      }

      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(sessionsSubcollection)
          .doc(sessionId);

      await sessionRef.update({
        'rsvpStatus.$userId': status,
      });
    } catch (e) {
      throw Exception('Failed to RSVP: $e');
    }
  }

  // Get members' availability for scheduling
  Future<Map<String, List<DateTime>>> getMembersAvailability({
    required String groupId,
    required List<String> memberIds,
    required DateTime dateStart,
    required DateTime dateEnd,
  }) async {
    try {
      final availability = <String, List<DateTime>>{};

      for (var memberId in memberIds) {
        // Get user's check-in sessions to see when they're typically available
        final sessionSnapshot = await _firestore
            .collection('checkInSessions')
            .where('userId', isEqualTo: memberId)
            .where('checkInTime',
                isGreaterThanOrEqualTo: dateStart.toIso8601String())
            .where('checkInTime', isLessThanOrEqualTo: dateEnd.toIso8601String())
            .get();

        final times = <DateTime>[];
        for (var session in sessionSnapshot.docs) {
          final checkInTime =
              DateTime.parse(session['checkInTime'] as String);
          times.add(checkInTime);
        }
        availability[memberId] = times;
      }

      return availability;
    } catch (e) {
      throw Exception('Failed to get availability: $e');
    }
  }

  // Find best time slot for all members
  Future<List<DateTimeRange>> findBestTimeSlots({
    required String groupId,
    required List<String> memberIds,
    required DateTime dateStart,
    required DateTime dateEnd,
    int slotDurationMinutes = 60,
  }) async {
    try {
      final availability =
          await getMembersAvailability(
            groupId: groupId,
            memberIds: memberIds,
            dateStart: dateStart,
            dateEnd: dateEnd,
          );

      // Simple algorithm: find hours where most members are available
      final slots = <DateTimeRange>[];
      var currentTime = DateTime(dateStart.year, dateStart.month, dateStart.day,
          9, 0); // Start at 9 AM

      while (currentTime.isBefore(dateEnd)) {
        var slotEnd = currentTime.add(Duration(minutes: slotDurationMinutes));
        if (slotEnd.isAfter(dateEnd)) break;

        // Check how many members might be available
        int availableCount = 0;
        for (var times in availability.values) {
          // Simple heuristic: if member has a session during this time, they're available
          if (times.any((t) =>
              t.isAfter(currentTime) && t.isBefore(slotEnd))) {
            availableCount++;
          }
        }

        // If at least 70% of members are potentially available
        if (availableCount >= (memberIds.length * 0.7).ceil()) {
          slots.add(DateTimeRange(start: currentTime, end: slotEnd));
        }

        currentTime = currentTime.add(Duration(minutes: slotDurationMinutes));
      }

      return slots.isNotEmpty
          ? slots
          : [DateTimeRange(start: dateStart, end: dateStart.add(const Duration(hours: 1)))];
    } catch (e) {
      throw Exception('Failed to find time slots: $e');
    }
  }
}

class DateTimeRange {
  final DateTime start;
  final DateTime end;

  DateTimeRange({required this.start, required this.end});

  Duration get duration => end.difference(start);
}
