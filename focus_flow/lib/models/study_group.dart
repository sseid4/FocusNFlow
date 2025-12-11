class StudyGroup {
  final String id;
  final String name;
  final String courseId;
  final String courseName;
  final String description;
  final String adminId;
  final List<String> memberIds;
  final int maxMembers;
  final bool isPublic;
  final DateTime createdAt;
  final Map<String, dynamic> settings;

  StudyGroup({
    required this.id,
    required this.name,
    required this.courseId,
    required this.courseName,
    required this.description,
    required this.adminId,
    this.memberIds = const [],
    this.maxMembers = 10,
    this.isPublic = true,
    required this.createdAt,
    this.settings = const {},
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      description: json['description'] as String,
      adminId: json['adminId'] as String,
      memberIds: List<String>.from(json['memberIds'] ?? []),
      maxMembers: json['maxMembers'] as int? ?? 10,
      isPublic: json['isPublic'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'courseId': courseId,
      'courseName': courseName,
      'description': description,
      'adminId': adminId,
      'memberIds': memberIds,
      'maxMembers': maxMembers,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'settings': settings,
    };
  }

  bool get isFull => memberIds.length >= maxMembers;
  int get memberCount => memberIds.length;
}
