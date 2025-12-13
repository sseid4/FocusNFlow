import 'package:cloud_firestore/cloud_firestore.dart';

class PomodoroService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String groupsCollection = 'groups';
  static const String pomodoroSubcollection = 'pomodoro_sessions';

  // Pomodoro timers (in seconds)
  static const int defaultWorkDuration = 25 * 60; // 25 minutes
  static const int defaultBreakDuration = 5 * 60; // 5 minutes
  static const int longBreakDuration = 15 * 60; // 15 minutes

  // Start a new Pomodoro session for a group
  Future<String> startPomodoroSession({
    required String groupId,
    required String userId,
    required String userName,
    String? goal,
    int workDurationSeconds = defaultWorkDuration,
    int breakDurationSeconds = defaultBreakDuration,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc();

      final now = DateTime.now();

      await sessionRef.set({
        'id': sessionRef.id,
        'groupId': groupId,
        'status': 'active', // active, paused, completed
        'phase': 'work', // work, short_break, long_break
        'startTime': now.toIso8601String(),
        'endTime': null,
        'workDuration': workDurationSeconds,
        'breakDuration': breakDurationSeconds,
        'currentCycleStart': now.toIso8601String(),
        'participants': {
          userId: {
            'name': userName,
            'joinedAt': now.toIso8601String(),
            'goal': goal,
            'isActive': true,
          }
        },
        'cycleCount': 1,
        'completedCycles': 0,
        'phaseStartTime': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
      });

      return sessionRef.id;
    } catch (e) {
      throw Exception('Failed to start Pomodoro session: $e');
    }
  }

  // Join existing Pomodoro session
  Future<void> joinPomodoroSession({
    required String groupId,
    required String sessionId,
    required String userId,
    required String userName,
    String? goal,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc(sessionId);

      await sessionRef.update({
        'participants.$userId': {
          'name': userName,
          'joinedAt': DateTime.now().toIso8601String(),
          'goal': goal,
          'isActive': true,
        }
      });
    } catch (e) {
      throw Exception('Failed to join Pomodoro session: $e');
    }
  }

  // Leave Pomodoro session
  Future<void> leavePomodoroSession({
    required String groupId,
    required String sessionId,
    required String userId,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc(sessionId);

      await sessionRef.update({
        'participants.$userId.isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to leave Pomodoro session: $e');
    }
  }

  // Get active Pomodoro session for a group
  Future<Map<String, dynamic>?> getActivePomodoroSession(
      String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return snapshot.docs.first.data();
    } catch (e) {
      throw Exception('Failed to get active Pomodoro session: $e');
    }
  }

  // Stream active Pomodoro session
  Stream<Map<String, dynamic>?> streamActivePomodoroSession(
      String groupId) {
    return _firestore
        .collection(groupsCollection)
        .doc(groupId)
        .collection(pomodoroSubcollection)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null;
    });
  }

  // Update phase (work to break, break to work)
  Future<void> updatePhase({
    required String groupId,
    required String sessionId,
    required String newPhase,
    required int nextPhaseDuration,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc(sessionId);

      final now = DateTime.now();
      int newCycleCount = 1;
      int newCompletedCycles = 0;

      // If transitioning from work to break, increment cycle count
      if (newPhase.contains('break')) {
        final sessionDoc = await sessionRef.get();
        if (sessionDoc.exists) {
          final currentCycle = sessionDoc['cycleCount'] as int? ?? 1;
          newCycleCount = currentCycle;
          newCompletedCycles = (sessionDoc['completedCycles'] as int? ?? 0) + 1;
        }
      }

      await sessionRef.update({
        'phase': newPhase,
        'phaseStartTime': now.toIso8601String(),
        'cycleCount': newCycleCount,
        'completedCycles': newCompletedCycles,
      });
    } catch (e) {
      throw Exception('Failed to update phase: $e');
    }
  }

  // Pause session
  Future<void> pauseSession({
    required String groupId,
    required String sessionId,
  }) async {
    try {
      await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc(sessionId)
          .update({'status': 'paused'});
    } catch (e) {
      throw Exception('Failed to pause session: $e');
    }
  }

  // Resume session
  Future<void> resumeSession({
    required String groupId,
    required String sessionId,
  }) async {
    try {
      await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc(sessionId)
          .update({'status': 'active'});
    } catch (e) {
      throw Exception('Failed to resume session: $e');
    }
  }

  // Complete session
  Future<void> completeSession({
    required String groupId,
    required String sessionId,
  }) async {
    try {
      await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .doc(sessionId)
          .update({
        'status': 'completed',
        'endTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to complete session: $e');
    }
  }

  // Get session history for group
  Future<List<Map<String, dynamic>>> getSessionHistory(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .where('status', isEqualTo: 'completed')
          .orderBy('endTime', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Failed to get session history: $e');
    }
  }

  // Get statistics for user
  Future<Map<String, dynamic>> getUserStatistics({
    required String groupId,
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .where('status', isEqualTo: 'completed')
          .get();

      int totalSessions = 0;
      int totalMinutes = 0;
      int totalCycles = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as Map<String, dynamic>?;

        if (participants != null && participants.containsKey(userId)) {
          totalSessions++;
          final workDuration = (data['workDuration'] as int?) ?? 0;
          final completedCycles = (data['completedCycles'] as int?) ?? 0;
          totalMinutes += (workDuration ~/ 60) * completedCycles;
          totalCycles += completedCycles;
        }
      }

      return {
        'totalSessions': totalSessions,
        'totalMinutes': totalMinutes,
        'totalCycles': totalCycles,
        'averageMinutesPerSession':
            totalSessions > 0 ? totalMinutes ~/ totalSessions : 0,
        'averageCyclesPerSession':
            totalSessions > 0 ? totalCycles ~/ totalSessions : 0,
      };
    } catch (e) {
      throw Exception('Failed to get user statistics: $e');
    }
  }

  // Get group statistics
  Future<Map<String, dynamic>> getGroupStatistics(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(groupsCollection)
          .doc(groupId)
          .collection(pomodoroSubcollection)
          .where('status', isEqualTo: 'completed')
          .get();

      final userStats = <String, Map<String, int>>{};
      int totalGroupMinutes = 0;
      int totalGroupCycles = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as Map<String, dynamic>?;
        final workDuration = (data['workDuration'] as int?) ?? 0;
        final completedCycles = (data['completedCycles'] as int?) ?? 0;

        if (participants != null) {
          for (var userId in participants.keys) {
            userStats.putIfAbsent(userId, () => {'sessions': 0, 'minutes': 0});
            userStats[userId]!['sessions'] =
                (userStats[userId]!['sessions']! + 1);
            userStats[userId]!['minutes'] =
                (userStats[userId]!['minutes']! +
                    (workDuration ~/ 60) * completedCycles);
          }
        }

        totalGroupMinutes += (workDuration ~/ 60) * completedCycles;
        totalGroupCycles += completedCycles;
      }

      return {
        'totalCompletedSessions': snapshot.docs.length,
        'totalGroupMinutes': totalGroupMinutes,
        'totalGroupCycles': totalGroupCycles,
        'userStats': userStats,
        'averageMinutesPerSession':
            snapshot.docs.isNotEmpty
                ? totalGroupMinutes ~/ snapshot.docs.length
                : 0,
      };
    } catch (e) {
      throw Exception('Failed to get group statistics: $e');
    }
  }
}
