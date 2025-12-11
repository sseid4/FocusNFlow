class StudySession {
  final String id;
  final String groupId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location; // Room ID or description
  final String createdBy;
  final List<String> attendeeIds;
  final Map<String, String> rsvpStatus; // userId: 'yes'|'no'|'maybe'
  final bool isRecurring;
  final String? agenda;
  final DateTime createdAt;

  StudySession({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    required this.createdBy,
    this.attendeeIds = const [],
    this.rsvpStatus = const {},
    this.isRecurring = false,
    this.agenda,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String?,
      createdBy: json['createdBy'] as String,
      attendeeIds: List<String>.from(json['attendeeIds'] ?? []),
      rsvpStatus: Map<String, String>.from(json['rsvpStatus'] ?? {}),
      isRecurring: json['isRecurring'] as bool? ?? false,
      agenda: json['agenda'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'createdBy': createdBy,
      'attendeeIds': attendeeIds,
      'rsvpStatus': rsvpStatus,
      'isRecurring': isRecurring,
      'agenda': agenda,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Duration get duration => endTime.difference(startTime);
  bool get isUpcoming => startTime.isAfter(DateTime.now());
  bool get isInProgress {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }
}
