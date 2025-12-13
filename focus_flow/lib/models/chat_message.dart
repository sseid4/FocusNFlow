class ChatMessage {
  final String id;
  final String groupId;
  final String userId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final Map<String, int> reactions; // emoji -> count
  final bool isEdited;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.reactions = const {},
    this.isEdited = false,
    this.editedAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reactions: Map<String, int>.from(json['reactions'] ?? {}),
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'userId': userId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'reactions': reactions,
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? content,
    Map<String, int>? reactions,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return ChatMessage(
      id: id,
      groupId: groupId,
      userId: userId,
      senderName: senderName,
      content: content ?? this.content,
      timestamp: timestamp,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}
