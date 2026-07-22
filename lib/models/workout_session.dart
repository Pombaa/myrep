import 'dart:convert';

import 'workout_plan.dart';

class WorkoutSession {
  const WorkoutSession({
    this.id,
    this.planId,
    required this.executedAt,
    required this.dayLabel,
    required this.exercises,
    this.notes,
  });

  final int? id;
  final int? planId;
  final DateTime executedAt;
  final String dayLabel;
  final List<WorkoutExercise> exercises;
  final String? notes;

  WorkoutSession copyWith({
    int? id,
    int? planId,
    DateTime? executedAt,
    String? dayLabel,
    List<WorkoutExercise>? exercises,
    String? notes,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      executedAt: executedAt ?? this.executedAt,
      dayLabel: dayLabel ?? this.dayLabel,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'executed_at': executedAt.toIso8601String(),
      'day_label': dayLabel,
      'session_json': jsonEncode(exercises.map((e) => e.toJson()).toList()),
      'notes': notes,
    };
  }

  factory WorkoutSession.fromMap(Map<String, Object?> map) {
    final raw = map['session_json'] as String;
    final parsed = (jsonDecode(raw) as List<dynamic>)
        .map((dynamic e) => WorkoutExercise.fromJson((e as Map).cast<String, Object?>()))
        .toList();
    return WorkoutSession(
      id: map['id'] as int?,
      planId: map['plan_id'] as int?,
      executedAt: DateTime.parse(map['executed_at'] as String),
      dayLabel: map['day_label'] as String,
      exercises: parsed,
      notes: map['notes'] as String?,
    );
  }
}
