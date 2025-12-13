class Assignment {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String type; // exam, project, homework, quiz, paper
  final int estimatedHours;
  final String difficulty; // easy, medium, hard
  final int priority; // 1-5
  final bool isCompleted;
  final DateTime? completedAt;
  final List<String> topics;
  final List<String> resources;

  Assignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.description = '',
    required this.dueDate,
    required this.type,
    this.estimatedHours = 2,
    this.difficulty = 'medium',
    this.priority = 3,
    this.isCompleted = false,
    this.completedAt,
    this.topics = const [],
    this.resources = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'type': type,
      'estimatedHours': estimatedHours,
      'difficulty': difficulty,
      'priority': priority,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'topics': topics,
      'resources': resources,
    };
  }

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as String,
      courseId: json['courseId'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      dueDate: DateTime.parse(json['dueDate'] as String),
      type: json['type'] as String,
      estimatedHours: json['estimatedHours'] as int? ?? 2,
      difficulty: json['difficulty'] as String? ?? 'medium',
      priority: json['priority'] as int? ?? 3,
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      topics: List<String>.from(json['topics'] as List? ?? []),
      resources: List<String>.from(json['resources'] as List? ?? []),
    );
  }

  Assignment copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? type,
    int? estimatedHours,
    String? difficulty,
    int? priority,
    bool? isCompleted,
    DateTime? completedAt,
    List<String>? topics,
    List<String>? resources,
  }) {
    return Assignment(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      type: type ?? this.type,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      difficulty: difficulty ?? this.difficulty,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      topics: topics ?? this.topics,
      resources: resources ?? this.resources,
    );
  }

  // Helper getters
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
  bool get isOverdue => DateTime.now().isAfter(dueDate) && !isCompleted;
  bool get isDueSoon => daysUntilDue <= 3 && daysUntilDue >= 0 && !isCompleted;
  
  double get urgencyScore {
    if (isCompleted) return 0;
    final daysLeft = daysUntilDue.toDouble();
    final difficultyMultiplier = difficulty == 'hard' ? 1.5 : difficulty == 'medium' ? 1.2 : 1.0;
    return (priority * difficultyMultiplier * estimatedHours) / (daysLeft + 1).clamp(1, 30);
  }
}
