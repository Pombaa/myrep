import 'dart:convert';

enum RepScheme {
  straightSets,
  pyramidAscending,
  pyramidDescending,
  unknown;

  String get label {
    switch (this) {
      case RepScheme.straightSets:
        return 'Straight Sets';
      case RepScheme.pyramidAscending:
        return 'Pirâmide Crescente';
      case RepScheme.pyramidDescending:
        return 'Pirâmide Decrescente';
      case RepScheme.unknown:
        return 'Desconhecido';
    }
  }

  String get dbValue {
    switch (this) {
      case RepScheme.straightSets:
        return 'straightSets';
      case RepScheme.pyramidAscending:
        return 'pyramidAscending';
      case RepScheme.pyramidDescending:
        return 'pyramidDescending';
      case RepScheme.unknown:
        return 'unknown';
    }
  }

  static RepScheme fromString(String value) {
    return RepScheme.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => RepScheme.unknown,
    );
  }
}

class WorkoutSet {
  const WorkoutSet({
    required this.setIndex,
    required this.reps,
    required this.load,
    this.completed = false,
  });

  final int setIndex;
  final int reps;
  final double load;
  final bool completed;

  WorkoutSet copyWith({int? setIndex, int? reps, double? load, bool? completed}) {
    return WorkoutSet(
      setIndex: setIndex ?? this.setIndex,
      reps: reps ?? this.reps,
      load: load ?? this.load,
      completed: completed ?? this.completed,
    );
  }

  Map<String, Object?> toJson() => {
        'setIndex': setIndex,
        'reps': reps,
        'load': load,
        'completed': completed,
      };

  factory WorkoutSet.fromJson(Map<String, Object?> json) {
    return WorkoutSet(
      setIndex: (json['setIndex'] as num).toInt(),
      reps: (json['reps'] as num).toInt(),
      load: (json['load'] as num).toDouble(),
      completed: json['completed'] as bool? ?? false,
    );
  }

  static List<WorkoutSet> listFromJsonString(String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => WorkoutSet.fromJson((e as Map).cast<String, Object?>()))
        .toList();
  }

  static String listToJsonString(List<WorkoutSet> sets) {
    return jsonEncode(sets.map((s) => s.toJson()).toList());
  }
}
