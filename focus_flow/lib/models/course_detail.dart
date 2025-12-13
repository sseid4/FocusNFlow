class CourseDetail {
  final String id;
  final String code; // e.g., CS4800
  final String name;
  final String instructor;
  final String semester; // Fall 2025, Spring 2026
  final int credits;
  final List<String> meetingTimes; // ["MWF 10:00-11:00", "Tu 14:00-16:00"]
  final String difficulty; // easy, medium, hard
  final String syllabusUrl;
  final Map<String, int> gradingBreakdown; // {"exams": 40, "projects": 30, "homework": 30}
  final List<String> topics;
  final List<String> learningGoals;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> preferences; // User's study preferences for this course

  CourseDetail({
    required this.id,
    required this.code,
    required this.name,
    this.instructor = '',
    required this.semester,
    this.credits = 3,
    this.meetingTimes = const [],
    this.difficulty = 'medium',
    this.syllabusUrl = '',
    this.gradingBreakdown = const {},
    this.topics = const [],
    this.learningGoals = const [],
    required this.startDate,
    required this.endDate,
    this.preferences = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'instructor': instructor,
      'semester': semester,
      'credits': credits,
      'meetingTimes': meetingTimes,
      'difficulty': difficulty,
      'syllabusUrl': syllabusUrl,
      'gradingBreakdown': gradingBreakdown,
      'topics': topics,
      'learningGoals': learningGoals,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'preferences': preferences,
    };
  }

  factory CourseDetail.fromJson(Map<String, dynamic> json) {
    return CourseDetail(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      instructor: json['instructor'] as String? ?? '',
      semester: json['semester'] as String,
      credits: json['credits'] as int? ?? 3,
      meetingTimes: List<String>.from(json['meetingTimes'] as List? ?? []),
      difficulty: json['difficulty'] as String? ?? 'medium',
      syllabusUrl: json['syllabusUrl'] as String? ?? '',
      gradingBreakdown: Map<String, int>.from(json['gradingBreakdown'] as Map? ?? {}),
      topics: List<String>.from(json['topics'] as List? ?? []),
      learningGoals: List<String>.from(json['learningGoals'] as List? ?? []),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
    );
  }

  CourseDetail copyWith({
    String? id,
    String? code,
    String? name,
    String? instructor,
    String? semester,
    int? credits,
    List<String>? meetingTimes,
    String? difficulty,
    String? syllabusUrl,
    Map<String, int>? gradingBreakdown,
    List<String>? topics,
    List<String>? learningGoals,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? preferences,
  }) {
    return CourseDetail(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      instructor: instructor ?? this.instructor,
      semester: semester ?? this.semester,
      credits: credits ?? this.credits,
      meetingTimes: meetingTimes ?? this.meetingTimes,
      difficulty: difficulty ?? this.difficulty,
      syllabusUrl: syllabusUrl ?? this.syllabusUrl,
      gradingBreakdown: gradingBreakdown ?? this.gradingBreakdown,
      topics: topics ?? this.topics,
      learningGoals: learningGoals ?? this.learningGoals,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      preferences: preferences ?? this.preferences,
    );
  }

  // Helper getters
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  int get weeksRemaining {
    return endDate.difference(DateTime.now()).inDays ~/ 7;
  }

  double get workloadScore {
    final difficultyMultiplier = difficulty == 'hard' ? 1.5 : difficulty == 'medium' ? 1.2 : 1.0;
    return credits * difficultyMultiplier;
  }
}
