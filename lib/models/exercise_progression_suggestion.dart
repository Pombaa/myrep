import 'dart:convert';

import 'workout_set.dart';

enum MuscleGroupSize {
  large,
  medium,
  isolated,
  bodyweight;

  double get loadIncrement {
    switch (this) {
      case MuscleGroupSize.large:
        return 2.5;
      case MuscleGroupSize.medium:
        return 1.25;
      case MuscleGroupSize.isolated:
        return 1.0;
      case MuscleGroupSize.bodyweight:
        return 0.0;
    }
  }
}

class ProgressionOption {
  const ProgressionOption({
    required this.label,
    required this.projectedSets,
    this.description,
  });

  final String label;
  final List<WorkoutSet> projectedSets;
  final String? description;
}

class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    this.id,
    required this.userId,
    required this.sessionDate,
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    this.progressionDecisionLabel,
    required this.repScheme,
  });

  final int? id;
  final int userId;
  final DateTime sessionDate;
  final String exerciseName;
  final String muscleGroup;
  final List<WorkoutSet> sets;
  final String? progressionDecisionLabel;
  final RepScheme repScheme;

  ExerciseHistoryEntry copyWith({
    int? id,
    int? userId,
    DateTime? sessionDate,
    String? exerciseName,
    String? muscleGroup,
    List<WorkoutSet>? sets,
    String? progressionDecisionLabel,
    RepScheme? repScheme,
  }) {
    return ExerciseHistoryEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sessionDate: sessionDate ?? this.sessionDate,
      exerciseName: exerciseName ?? this.exerciseName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      progressionDecisionLabel: progressionDecisionLabel ?? this.progressionDecisionLabel,
      repScheme: repScheme ?? this.repScheme,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'session_date': sessionDate.toIso8601String(),
      'exercise_name': exerciseName,
      'muscle_group': muscleGroup,
      'sets_data': WorkoutSet.listToJsonString(sets),
      'progression_decision': progressionDecisionLabel != null
          ? jsonEncode({'label': progressionDecisionLabel})
          : null,
      'rep_scheme': repScheme.dbValue,
    };
  }

  factory ExerciseHistoryEntry.fromMap(Map<String, Object?> map) {
    String? decisionLabel;
    final decisionRaw = map['progression_decision'] as String?;
    if (decisionRaw != null && decisionRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(decisionRaw) as Map<String, dynamic>;
        decisionLabel = decoded['label'] as String?;
      } catch (_) {}
    }
    return ExerciseHistoryEntry(
      id: map['id'] as int?,
      userId: (map['user_id'] as num).toInt(),
      sessionDate: DateTime.parse(map['session_date'] as String),
      exerciseName: map['exercise_name'] as String,
      muscleGroup: map['muscle_group'] as String,
      sets: WorkoutSet.listFromJsonString(map['sets_data'] as String),
      progressionDecisionLabel: decisionLabel,
      repScheme: RepScheme.fromString(map['rep_scheme'] as String),
    );
  }

  String get summaryLine {
    if (sets.isEmpty) return exerciseName;
    final firstLoad = sets.first.load;
    final totalSets = sets.length;
    final repsStr = sets.map((s) => s.reps.toString()).toSet().length == 1
        ? '${totalSets}x${sets.first.reps}'
        : sets.map((s) => s.reps.toString()).join('/');
    final loadStr = firstLoad > 0 ? ' com ${firstLoad.toStringAsFixed(1)}kg' : '';
    return '$repsStr$loadStr';
  }
}

class ExerciseProgressionSuggestion {
  const ExerciseProgressionSuggestion({
    required this.exerciseName,
    required this.muscleGroup,
    required this.scheme,
    required this.currentSets,
    required this.previousSummary,
    required this.recommendedOption,
    required this.allOptions,
  });

  final String exerciseName;
  final String muscleGroup;
  final RepScheme scheme;
  final List<WorkoutSet> currentSets;
  final String previousSummary;
  final ProgressionOption recommendedOption;
  final List<ProgressionOption> allOptions;
}
