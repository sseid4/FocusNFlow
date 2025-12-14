import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:focusnflow/models/assignment.dart';
import 'package:focusnflow/models/course_detail.dart';
import 'package:focusnflow/services/cognitive_load_analyzer.dart';

class StudyBlock {
  final String assignmentId;
  final String assignmentTitle;
  final String courseCode;
  final DateTime startTime;
  final DateTime endTime;
  final int duration; // minutes
  final String topic;
  final List<String> resources;
  final String studyType; // review, deep-work, practice, exam-prep

  StudyBlock({
    required this.assignmentId,
    required this.assignmentTitle,
    required this.courseCode,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.topic,
    this.resources = const [],
    required this.studyType,
  });

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': assignmentId,
      'assignmentTitle': assignmentTitle,
      'courseCode': courseCode,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'duration': duration,
      'topic': topic,
      'resources': resources,
      'studyType': studyType,
    };
  }
}

class StudyScheduleOptimizer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CognitiveLoadAnalyzer _cognitiveAnalyzer = CognitiveLoadAnalyzer();

  static const String coursesCollection = 'courses';
  static const String assignmentsCollection = 'assignments';
  static const String studyBlocksCollection = 'study_blocks';

  // Generate optimized study schedule
  Future<List<StudyBlock>> generateOptimizedSchedule({
    required String userId,
    required List<CourseDetail> courses,
    required List<Assignment> assignments,
    int daysAhead = 14,
  }) async {
    try {
      // Get user's cognitive load analysis; fall back to safe defaults if analytics fail (e.g., missing Firestore index)
      Map<String, dynamic> patterns;
      Map<String, dynamic> attention;
      Map<String, dynamic> burnout;

      try {
        patterns = await _cognitiveAnalyzer.analyzeStudyPatterns(
          userId: userId,
          daysBack: 30,
        );
      } catch (_) {
        patterns = {
          'peakStudyHour': 14,
          'weekdayVsWeekend': {'weekday': 1, 'weekend': 1},
          'sessionsPerDay': 3.0,
        };
      }

      try {
        attention = await _cognitiveAnalyzer.analyzeAttentionSpan(
          userId: userId,
          daysBack: 30,
        );
      } catch (_) {
        attention = {
          'optimalSessionDuration': 25,
          'focusVariability': '0.0',
          'performanceDegradation': '0.0',
        };
      }

      try {
        burnout = await _cognitiveAnalyzer.calculateBurnoutRisk(
          userId: userId,
          daysBack: 14,
        );
      } catch (_) {
        burnout = {
          'isBurnoutRisk': false,
        };
      }

      // Extract user's optimal study parameters
      final optimalSessionLength = attention['optimalSessionDuration'] as int? ?? 25;
      final peakStudyHour = patterns['peakStudyHour'] as int? ?? 14;
      final isBurnoutRisk = burnout['isBurnoutRisk'] as bool? ?? false;

      // Sort assignments by urgency
      final sortedAssignments = List<Assignment>.from(assignments)
        ..sort((a, b) => b.urgencyScore.compareTo(a.urgencyScore));

      // Generate study blocks
      final studyBlocks = <StudyBlock>[];
      final now = DateTime.now();
      for (var assignment in sortedAssignments) {
        if (assignment.isCompleted) continue;

        final course = courses.firstWhere(
          (c) => c.id == assignment.courseId,
          orElse: () => courses.first,
        );

        // Calculate how many study sessions needed
        final hoursNeeded = assignment.estimatedHours;
        final sessionsNeeded = (hoursNeeded * 60 / optimalSessionLength).ceil();
        
        // Distribute sessions across available days
        final daysUntilDue = assignment.daysUntilDue;
        final daysToSpread = (daysUntilDue * 0.8)
          .floor()
          .clamp(1, daysAhead);
        
        // If burnout risk, reduce load
        final adjustedSessions = isBurnoutRisk 
            ? (sessionsNeeded * 0.7).ceil() 
            : sessionsNeeded;

        // Schedule sessions
        int sessionCount = 0;
        for (int day = 0; day < daysToSpread && sessionCount < adjustedSessions; day++) {
          final sessionDate = now.add(Duration(days: day));
          
          // Skip weekends only if history shows user avoids them
          final weekdayVsWeekend = patterns['weekdayVsWeekend'] as Map<String, dynamic>?;
          final weekendPreference = weekdayVsWeekend?['weekend'] as int? ?? 1;
          if (sessionDate.weekday >= 6 && weekendPreference == 0) {
            continue;
          }

          // Schedule at user's peak time
          final startTime = DateTime(
            sessionDate.year,
            sessionDate.month,
            sessionDate.day,
            peakStudyHour,
            0,
          );

          final endTime = startTime.add(Duration(minutes: optimalSessionLength));

          // Determine study type based on days until due
          String studyType;
          if (daysUntilDue <= 2) {
            studyType = 'exam-prep';
          } else if (assignment.type == 'exam') {
            studyType = 'review';
          } else if (assignment.difficulty == 'hard') {
            studyType = 'deep-work';
          } else {
            studyType = 'practice';
          }

          studyBlocks.add(StudyBlock(
            assignmentId: assignment.id,
            assignmentTitle: assignment.title,
            courseCode: course.code,
            startTime: startTime,
            endTime: endTime,
            duration: optimalSessionLength,
            topic: assignment.topics.isNotEmpty 
                ? assignment.topics[sessionCount % assignment.topics.length]
                : assignment.title,
            resources: assignment.resources,
            studyType: studyType,
          ));

          sessionCount++;
        }
      }

      // Sort by start time
      studyBlocks.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Save to Firestore
      await _saveStudyBlocks(userId, studyBlocks);

      return studyBlocks;
    } catch (e) {
      throw Exception('Failed to generate optimized schedule: $e');
    }
  }

  // Get resource recommendations based on course and assignment
  Future<List<String>> getResourceRecommendations({
    required CourseDetail course,
    required Assignment assignment,
  }) async {
    final recommendations = <String>[];

    // Add course resources
    if (course.syllabusUrl.isNotEmpty) {
      recommendations.add('📄 Course Syllabus: ${course.syllabusUrl}');
    }

    // Add assignment-specific resources
    recommendations.addAll(assignment.resources.map((r) => '📚 $r'));

    // Add study type recommendations
    switch (assignment.type) {
      case 'exam':
        recommendations.add('🎯 Review lecture notes and practice problems');
        recommendations.add('📝 Create summary sheets for each topic');
        recommendations.add('👥 Join study group for Q&A sessions');
        break;
      case 'project':
        recommendations.add('💻 Break into smaller milestones');
        recommendations.add('🔍 Research similar projects for inspiration');
        recommendations.add('👥 Collaborate with group members');
        break;
      case 'homework':
        recommendations.add('📖 Review relevant textbook chapters');
        recommendations.add('✍️ Work through practice problems');
        recommendations.add('❓ Attend office hours if stuck');
        break;
      case 'paper':
        recommendations.add('📚 Gather sources and create bibliography');
        recommendations.add('📝 Outline main arguments first');
        recommendations.add('✏️ Write draft, then revise');
        break;
      default:
        recommendations.add('📖 Review course materials');
        recommendations.add('✍️ Practice regularly');
    }

    // Add difficulty-based recommendations
    if (assignment.difficulty == 'hard') {
      recommendations.add('⚠️ Start early and break into small chunks');
      recommendations.add('🧠 Use Pomodoro technique for focused sessions');
      recommendations.add('💬 Discuss concepts with peers or TA');
    }

    return recommendations;
  }

  // Analyze learning patterns from past assignments
  Future<Map<String, dynamic>> analyzeLearningPatterns({
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(assignmentsCollection)
          .where('isCompleted', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'completionRate': 0.0,
          'averageLeadTime': 0,
          'preferredStudyType': 'practice',
          'strongestSubjects': <String>[],
          'needsImprovementSubjects': <String>[],
        };
      }

      final completedAssignments = snapshot.docs
          .map((doc) => Assignment.fromJson({...doc.data(), 'id': doc.id}))
          .toList();

      // Calculate metrics
      final totalLeadTime = completedAssignments.fold<int>(
        0,
        (sum, a) => sum + (a.completedAt?.difference(a.dueDate).inDays.abs() ?? 0),
      );
      final avgLeadTime = totalLeadTime ~/ completedAssignments.length;

      // Analyze by difficulty
      final hardCompleted = completedAssignments
          .where((a) => a.difficulty == 'hard')
          .length;
      final totalHard = completedAssignments.length;
      final completionRate = totalHard > 0 ? hardCompleted / totalHard : 0.0;

      return {
        'completionRate': completionRate,
        'averageLeadTime': avgLeadTime,
        'preferredStudyType': 'practice',
        'totalCompleted': completedAssignments.length,
        'onTimeCount': completedAssignments
            .where((a) => 
                a.completedAt != null && 
                a.completedAt!.isBefore(a.dueDate))
            .length,
      };
    } catch (e) {
      throw Exception('Failed to analyze learning patterns: $e');
    }
  }

  // Calculate optimal study load per day
  int calculateOptimalDailyLoad({
    required List<CourseDetail> courses,
    required Map<String, dynamic> patterns,
    required bool isBurnoutRisk,
  }) {
    // Base load from course workload (unused but kept for future enhancements)
    final _ = courses.fold<double>(
      0,
      (sum, course) => sum + course.workloadScore,
    );

    // Adjust based on user patterns
    final sessionsPerDay = patterns['sessionsPerDay'] as double? ?? 3.0;
    
    // If burnout risk, reduce by 30%
    final adjustedSessions = isBurnoutRisk 
        ? (sessionsPerDay * 0.7) 
        : sessionsPerDay;

    return adjustedSessions.ceil().clamp(1, 6);
  }

  // Save study blocks to Firestore
  Future<void> _saveStudyBlocks(
    String userId,
    List<StudyBlock> blocks,
  ) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);

      // Clear existing blocks
      final existingBlocks = await userRef
          .collection(studyBlocksCollection)
          .get();
      
      for (var doc in existingBlocks.docs) {
        batch.delete(doc.reference);
      }

      // Add new blocks
      for (var block in blocks) {
        final docRef = userRef
            .collection(studyBlocksCollection)
            .doc();
        batch.set(docRef, block.toJson());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to save study blocks: $e');
    }
  }

  // Get saved study blocks
  Future<List<StudyBlock>> getStudyBlocks({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _firestore
          .collection('users')
          .doc(userId)
          .collection(studyBlocksCollection)
          .orderBy('startTime');

      if (startDate != null) {
        query = query.where('startTime', 
            isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('startTime', 
            isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StudyBlock(
          assignmentId: data['assignmentId'] as String,
          assignmentTitle: data['assignmentTitle'] as String,
          courseCode: data['courseCode'] as String,
          startTime: DateTime.parse(data['startTime'] as String),
          endTime: DateTime.parse(data['endTime'] as String),
          duration: data['duration'] as int,
          topic: data['topic'] as String,
          resources: List<String>.from(data['resources'] as List? ?? []),
          studyType: data['studyType'] as String,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get study blocks: $e');
    }
  }
}
