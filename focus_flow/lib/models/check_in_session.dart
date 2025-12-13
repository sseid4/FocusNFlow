class CheckInSession {
  final String id;
  final String roomId;
  final String userId;
  final String userName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? groupId; // optional: if checking in for a group study
  final Map<String, dynamic> metadata; // any additional data

  CheckInSession({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.checkInTime,
    this.checkOutTime,
    this.groupId,
    this.metadata = const {},
  });

  factory CheckInSession.fromJson(Map<String, dynamic> json) {
    return CheckInSession(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      checkInTime: DateTime.parse(json['checkInTime'] as String),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.parse(json['checkOutTime'] as String)
          : null,
      groupId: json['groupId'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'userId': userId,
      'userName': userName,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'groupId': groupId,
      'metadata': metadata,
    };
  }

  Duration get duration {
    final endTime = checkOutTime ?? DateTime.now();
    return endTime.difference(checkInTime);
  }

  bool get isActive => checkOutTime == null;

  CheckInSession copyWith({
    DateTime? checkOutTime,
  }) {
    return CheckInSession(
      id: id,
      roomId: roomId,
      userId: userId,
      userName: userName,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      groupId: groupId,
      metadata: metadata,
    );
  }
}
