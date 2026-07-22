import 'dart:convert';

class WorkoutReminder {
  const WorkoutReminder({
    this.id,
    required this.userId,
    required this.createdAt,
    required this.content,
    required this.category,
    this.isActive = true,
  });

  final int? id;
  final int userId;
  final DateTime createdAt;
  final String content;
  final String
  category; // 'injury', 'preference', 'equipment', 'schedule', 'other'
  final bool isActive;

  WorkoutReminder copyWith({
    int? id,
    int? userId,
    DateTime? createdAt,
    String? content,
    String? category,
    bool? isActive,
  }) {
    return WorkoutReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      content: content ?? this.content,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'content': content,
      'category': category,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory WorkoutReminder.fromMap(Map<String, Object?> map) {
    return WorkoutReminder(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      content: map['content'] as String,
      category: map['category'] as String,
      isActive: (map['is_active'] as int) == 1,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory WorkoutReminder.fromJson(String source) =>
      WorkoutReminder.fromMap(jsonDecode(source) as Map<String, Object?>);
}
