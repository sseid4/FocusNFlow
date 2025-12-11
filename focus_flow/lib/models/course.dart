class Course {
  final String id;
  final String code; // e.g., "CSC 4350"
  final String name;
  final String department;
  final String? description;
  final String? instructor;
  final int studentCount;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    this.description,
    this.instructor,
    this.studentCount = 0,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      department: json['department'] as String,
      description: json['description'] as String?,
      instructor: json['instructor'] as String?,
      studentCount: json['studentCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'department': department,
      'description': description,
      'instructor': instructor,
      'studentCount': studentCount,
    };
  }
}
