import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CognitiveLoadAnalyzer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String usersCollection = 'users';
  static const String pomodoroCollection = 'pomodoro_sessions';
  static const String sessionsCollection = 'sessions';

  // Thresholds for burnout detection
  static const int maxSessionsPerDay = 8;
  static const int minBreakMinutes = 5;
  static const int optimalSessionLength = 25;
  static const double burnoutRiskThreshold = 0.7;

  // Study pattern analysis
  Future<Map<String, dynamic>> analyzeStudyPatterns({
    required String userId,
    int daysBack = 30,
  }) async {
    try {
      final startDate =
          DateTime.now().subtract(Duration(days: daysBack)).toIso8601String();
      
      // Get all completed Pomodoro sessions
      final sessionsSnapshot = await _firestore
          .collectionGroup(pomodoroCollection)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThan: startDate)
          .get();

      final userSessions = <Map<String, dynamic>>[];
      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as Map<String, dynamic>?;
        if (participants?.containsKey(userId) ?? false) {
          userSessions.add(data);
        }
      }

      if (userSessions.isEmpty) {
        return {
          'averageSessionLength': 0,
          'sessionsPerDay': 0.0,
          'breakFrequency': 0,
          'totalSessionsAnalyzed': 0,
          'peakStudyHour': 0,
          'weekdayVsWeekend': {'weekday': 0, 'weekend': 0},
        };
      }

      // Calculate session statistics
      final sessionLengths = <int>[];
      final sessionTimes = <DateTime>[];
      final breakDurations = <int>[];
      int totalCycles = 0;

      for (var session in userSessions) {
        final workDuration = session['workDuration'] as int? ?? 0;
        final completedCycles = session['completedCycles'] as int? ?? 0;
        final breakDuration = session['breakDuration'] as int? ?? 0;

        if (completedCycles > 0) {
          sessionLengths.add((workDuration ~/ 60) * completedCycles);
          breakDurations.add((breakDuration ~/ 60) * completedCycles);
          totalCycles += completedCycles;

          final createdAt = DateTime.parse(session['createdAt'] as String);
          sessionTimes.add(createdAt);
        }
      }

      // Calculate metrics
      final avgSessionLength = sessionLengths.isNotEmpty
          ? (sessionLengths.reduce((a, b) => a + b) ~/ sessionLengths.length)
          : 0;

      final daysActive = _getDaysActive(sessionTimes);
      final sessionsPerDay = daysActive > 0
          ? (userSessions.length / daysActive).toStringAsFixed(2)
          : '0.0';

      final avgBreak = breakDurations.isNotEmpty
          ? (breakDurations.reduce((a, b) => a + b) ~/ breakDurations.length)
          : 0;

      final peakHour = _getPeakStudyHour(sessionTimes);
      final weekdayVsWeekend = _analyzeWeekdayVsWeekend(sessionTimes);

      return {
        'averageSessionLength': avgSessionLength,
        'sessionsPerDay': double.parse(sessionsPerDay),
        'breakFrequency': avgBreak,
        'totalSessionsAnalyzed': userSessions.length,
        'totalCyclesCompleted': totalCycles,
        'peakStudyHour': peakHour,
        'weekdayVsWeekend': weekdayVsWeekend,
        'daysAnalyzed': daysActive,
      };
    } catch (e) {
      throw Exception('Failed to analyze study patterns: $e');
    }
  }

  // Attention span modeling
  Future<Map<String, dynamic>> analyzeAttentionSpan({
    required String userId,
    int daysBack = 30,
  }) async {
    try {
      final startDate =
          DateTime.now().subtract(Duration(days: daysBack)).toIso8601String();
      
      final sessionsSnapshot = await _firestore
          .collectionGroup(pomodoroCollection)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThan: startDate)
          .get();

      final userSessions = <Map<String, dynamic>>[];
      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as Map<String, dynamic>?;
        if (participants?.containsKey(userId) ?? false) {
          userSessions.add(data);
        }
      }

      if (userSessions.isEmpty) {
        return {
          'averageFocusTime': 0,
          'averageFocusSessions': 0,
          'performanceDegradation': 0.0,
          'focusVariability': 0.0,
          'optimalSessionDuration': 25,
        };
      }

      // Analyze focus times and degradation
      final workDurations = <int>[];
      final focusScores = <double>[];

      for (var session in userSessions) {
        final completedCycles = session['completedCycles'] as int? ?? 0;
        if (completedCycles > 0) {
          workDurations.add(completedCycles);
          // Simple heuristic: more cycles = better focus
          focusScores.add(completedCycles * 0.25);
        }
      }

      final avgFocusTime = workDurations.isNotEmpty
          ? workDurations.reduce((a, b) => a + b) ~/ workDurations.length
          : 0;

      final avgFocusScore = focusScores.isNotEmpty
          ? focusScores.reduce((a, b) => a + b) / focusScores.length
          : 0.0;

      // Calculate degradation (sessions getting shorter = degradation)
      double degradation = 0.0;
      if (workDurations.length > 2) {
        final recent = workDurations.sublist(
            (workDurations.length * 0.75).toInt());
        final earlier = workDurations.sublist(
            0, (workDurations.length * 0.25).toInt());
        
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final earlierAvg = earlier.reduce((a, b) => a + b) / earlier.length;
        
        degradation = ((earlierAvg - recentAvg) / earlierAvg).clamp(0.0, 1.0);
      }

      // Variability (standard deviation of focus times)
      double variability = 0.0;
      if (workDurations.length > 1) {
        final mean = avgFocusTime.toDouble();
        final sumSquareDiffs = workDurations.fold<double>(
          0.0,
          (sum, val) => sum + ((val - mean) * (val - mean)),
        );
        final variance = sumSquareDiffs / workDurations.length;
        variability = variance > 0 ? (sqrt(variance) / mean).clamp(0.0, 1.0) : 0.0;
      }

      return {
        'averageFocusTime': avgFocusTime,
        'averageFocusSessions': userSessions.length,
        'performanceDegradation': (degradation * 100).toStringAsFixed(1),
        'focusVariability': (variability * 100).toStringAsFixed(1),
        'optimalSessionDuration': _calculateOptimalDuration(workDurations),
        'avgFocusScore': avgFocusScore.toStringAsFixed(2),
      };
    } catch (e) {
      throw Exception('Failed to analyze attention span: $e');
    }
  }

  // Burnout risk detection
  Future<Map<String, dynamic>> calculateBurnoutRisk({
    required String userId,
    int daysBack = 14,
  }) async {
    try {
      final patterns = await analyzeStudyPatterns(userId: userId, daysBack: daysBack);
      final attention = await analyzeAttentionSpan(userId: userId, daysBack: daysBack);

      // Calculate burnout factors
      double sessionsPerDayScore = 0.0;
      double breakAdequacyScore = 0.0;
      double focusConsistencyScore = 0.0;
      double recoveryTimeScore = 0.0;

      // Factor 1: Sessions per day (high = risky)
      final sessionsPerDay = patterns['sessionsPerDay'] as double? ?? 0.0;
      sessionsPerDayScore = (sessionsPerDay / maxSessionsPerDay).clamp(0.0, 1.0);

      // Factor 2: Break adequacy
      final breakFreq = patterns['breakFrequency'] as int? ?? 0;
      breakAdequacyScore =
          (breakFreq < minBreakMinutes ? 0.8 : 0.2);

      // Factor 3: Focus consistency (variability = risk)
      final focusVar = double.tryParse(
              attention['focusVariability'] as String? ?? '0') ?? 0.0;
      focusConsistencyScore = (focusVar / 100).clamp(0.0, 1.0);

      // Factor 4: Recovery time (check if adequate rest between sessions)
      final weekdayVsWeekend =
          patterns['weekdayVsWeekend'] as Map<String, dynamic>?;
      recoveryTimeScore = weekdayVsWeekend == null
          ? 0.5
          : ((weekdayVsWeekend['weekend'] as int? ?? 0) > 0 ? 0.2 : 0.6);

      // Calculate overall burnout risk
      final burnoutRisk = (sessionsPerDayScore * 0.35 +
              breakAdequacyScore * 0.25 +
              focusConsistencyScore * 0.25 +
              recoveryTimeScore * 0.15)
          .clamp(0.0, 1.0);

      return {
        'burnoutRiskScore': (burnoutRisk * 100).toStringAsFixed(1),
        'isBurnoutRisk': burnoutRisk >= burnoutRiskThreshold,
        'factors': {
          'overSessioning': (sessionsPerDayScore * 100).toStringAsFixed(1),
          'inadequateBreaks': (breakAdequacyScore * 100).toStringAsFixed(1),
          'inconsistentFocus': (focusConsistencyScore * 100).toStringAsFixed(1),
          'insufficientRecovery': (recoveryTimeScore * 100).toStringAsFixed(1),
        },
        'riskLevel': _getRiskLevel(burnoutRisk),
        'recommendations': _generateBurnoutRecommendations(burnoutRisk),
      };
    } catch (e) {
      throw Exception('Failed to calculate burnout risk: $e');
    }
  }

  // Performance metrics calculation
  Future<Map<String, dynamic>> calculatePerformanceMetrics({
    required String userId,
  }) async {
    try {
      // Get user's test scores from performance data
      final userDoc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return {
          'comprehensionScore': 0,
          'taskCompletionRate': 0.0,
          'knowledgeRetention': 0.0,
          'improvementTrend': 'neutral',
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      final performance = userData?['performance'] as Map<String, dynamic>? ?? {};

      return {
        'comprehensionScore':
            (performance['comprehension'] as int?) ?? 0,
        'taskCompletionRate':
            ((performance['taskCompletion'] as double?) ?? 0.0),
        'knowledgeRetention':
            ((performance['retention'] as double?) ?? 0.0),
        'improvementTrend':
            (performance['trend'] as String?) ?? 'neutral',
        'lastUpdated': (performance['lastUpdated'] as String?) ?? '',
      };
    } catch (e) {
      throw Exception('Failed to calculate performance metrics: $e');
    }
  }

  // Optimal session recommendation
  Future<Map<String, dynamic>> getOptimalSessionRecommendation({
    required String userId,
  }) async {
    try {
      final patterns = await analyzeStudyPatterns(userId: userId);
      final attention = await analyzeAttentionSpan(userId: userId);
      final burnout = await calculateBurnoutRisk(userId: userId);

      final avgLength = patterns['averageSessionLength'] as int? ?? 25;
      final optimalLength =
          attention['optimalSessionDuration'] as int? ?? 25;
      final sessionsPerDay = patterns['sessionsPerDay'] as double? ?? 0.0;

      // Determine recommended session count
      int recommendedSessions = 3;
      if (sessionsPerDay > 6) recommendedSessions = 2;
      if (sessionsPerDay < 2) recommendedSessions = 4;

      return {
        'optimalSessionDuration': optimalLength,
        'recommendedSessionsPerDay': recommendedSessions,
        'recommendedBreakDuration': 5,
        'suggestedLongBreakFrequency': 4,
        'bestStudyTime': _getBestStudyTime(patterns),
        'shouldReduceLoad': burnout['isBurnoutRisk'] as bool? ?? false,
        'sessionProgression': _getSessionProgression(avgLength, optimalLength),
      };
    } catch (e) {
      throw Exception('Failed to get session recommendation: $e');
    }
  }

  // Helper methods
  int _getDaysActive(List<DateTime> sessionTimes) {
    if (sessionTimes.isEmpty) return 0;
    final days = <DateTime>{};
    for (var time in sessionTimes) {
      days.add(DateTime(time.year, time.month, time.day));
    }
    return days.length;
  }

  int _getPeakStudyHour(List<DateTime> sessionTimes) {
    if (sessionTimes.isEmpty) return 0;
    final hourCounts = <int, int>{};
    for (var time in sessionTimes) {
      hourCounts[time.hour] = (hourCounts[time.hour] ?? 0) + 1;
    }
    return hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Map<String, int> _analyzeWeekdayVsWeekend(List<DateTime> sessionTimes) {
    int weekday = 0, weekend = 0;
    for (var time in sessionTimes) {
      if (time.weekday >= 6) {
        weekend++;
      } else {
        weekday++;
      }
    }
    return {'weekday': weekday, 'weekend': weekend};
  }

  int _calculateOptimalDuration(List<int> durations) {
    if (durations.isEmpty) return 25;
    durations.sort();
    final median = durations[durations.length ~/ 2];
    return (median ~/ 5 * 5).clamp(15, 50);
  }

  String _getRiskLevel(double risk) {
    if (risk < 0.3) return 'Low';
    if (risk < 0.6) return 'Moderate';
    if (risk < 0.85) return 'High';
    return 'Critical';
  }

  List<String> _generateBurnoutRecommendations(double risk) {
    final recommendations = <String>[];
    
    if (risk < 0.3) {
      recommendations.add('You\'re maintaining a healthy study balance!');
      recommendations.add('Keep up your current study routine.');
    } else if (risk < 0.6) {
      recommendations.add('Consider taking longer breaks between sessions.');
      recommendations.add('Try scheduling some rest days this week.');
    } else if (risk < 0.85) {
      recommendations.add('⚠️ Reduce study load immediately.');
      recommendations.add('Take a full day off from studying.');
      recommendations.add('Increase break duration to 10-15 minutes.');
    } else {
      recommendations.add('🚨 URGENT: Burnout risk detected!');
      recommendations.add('Take 1-2 days off from studying.');
      recommendations.add('Reach out to study group members for support.');
      recommendations.add('Consider consulting with a campus counselor.');
    }
    
    return recommendations;
  }

  String _getBestStudyTime(Map<String, dynamic> patterns) {
    final peakHour = patterns['peakStudyHour'] as int? ?? 14;
    if (peakHour < 12) return 'Morning (6-12 AM)';
    if (peakHour < 18) return 'Afternoon (12-6 PM)';
    return 'Evening (6 PM+)';
  }

  String _getSessionProgression(int current, int optimal) {
    if (current < optimal) return 'Increase session duration gradually';
    if (current > optimal) return 'Consider shorter, more frequent sessions';
    return 'Your sessions are optimally paced';
  }
}
