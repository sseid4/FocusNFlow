class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final List<String> courses; // Course IDs
  final List<String> groups; // Group IDs
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime? lastActive;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.courses = const [],
    this.groups = const [],
    this.preferences = const {},
    required this.createdAt,
    this.lastActive,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      courses: List<String>.from(json['courses'] ?? []),
      groups: List<String>.from(json['groups'] ?? []),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'courses': courses,
      'groups': groups,
      'preferences': preferences,
      'createdAt': createdAt.toIso8601String(),
      'lastActive': lastActive?.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    List<String>? courses,
    List<String>? groups,
    Map<String, dynamic>? preferences,
    DateTime? lastActive,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      courses: courses ?? this.courses,
      groups: groups ?? this.groups,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }
}
