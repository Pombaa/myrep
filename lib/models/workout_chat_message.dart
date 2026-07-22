enum WorkoutChatRole { user, assistant }

class WorkoutChatMessage {
  const WorkoutChatMessage({
    required this.role,
    required this.content,
    required this.sentAt,
    this.rawContent,
  });

  final WorkoutChatRole role;
  final String content;
  final DateTime sentAt;
  final String? rawContent;

  WorkoutChatMessage copyWith({
    WorkoutChatRole? role,
    String? content,
    DateTime? sentAt,
    String? rawContent,
  }) {
    return WorkoutChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      rawContent: rawContent ?? this.rawContent,
    );
  }
}
