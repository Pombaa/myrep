import 'dart:convert';

enum EquipmentType { livre, maquina, polia }

extension EquipmentTypeX on EquipmentType {
  String get label {
    switch (this) {
      case EquipmentType.livre:
        return 'Livre';
      case EquipmentType.maquina:
        return 'Máquina';
      case EquipmentType.polia:
        return 'Polia';
    }
  }

  static EquipmentType? fromString(String? value) {
    if (value == null) return null;
    return EquipmentType.values.where((e) => e.name == value).firstOrNull;
  }
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.name,
    required this.series,
    required this.repetitions,
    this.equipmentType,
    this.suggestedLoad,
    this.notes,
    this.substituteExercise,
    this.technique,
    this.eccentricSeconds,
    this.concentricSeconds,
    this.restBetweenSetsSeconds,
    this.combinedExercises,
  });

  final String name;
  final int series;
  final int repetitions;
  final EquipmentType? equipmentType;
  final double? suggestedLoad;
  final String? notes;
  final String? substituteExercise;
  final String? technique;
  final int? eccentricSeconds;
  final int? concentricSeconds;
  final int? restBetweenSetsSeconds;
  final List<String>? combinedExercises;

  WorkoutExercise copyWith({
    String? name,
    int? series,
    int? repetitions,
    EquipmentType? equipmentType,
    double? suggestedLoad,
    String? notes,
    String? substituteExercise,
    String? technique,
    int? eccentricSeconds,
    int? concentricSeconds,
    int? restBetweenSetsSeconds,
    List<String>? combinedExercises,
  }) {
    return WorkoutExercise(
      name: name ?? this.name,
      series: series ?? this.series,
      repetitions: repetitions ?? this.repetitions,
      equipmentType: equipmentType ?? this.equipmentType,
      suggestedLoad: suggestedLoad ?? this.suggestedLoad,
      notes: notes ?? this.notes,
      substituteExercise: substituteExercise ?? this.substituteExercise,
      technique: technique ?? this.technique,
      eccentricSeconds: eccentricSeconds ?? this.eccentricSeconds,
      concentricSeconds: concentricSeconds ?? this.concentricSeconds,
      restBetweenSetsSeconds: restBetweenSetsSeconds ?? this.restBetweenSetsSeconds,
      combinedExercises: combinedExercises ?? this.combinedExercises,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'nome': name,
      'series': series,
      'reps': repetitions,
      'equipamento': equipmentType?.name,
      'carga_sugerida': suggestedLoad,
      'observacoes': notes,
      'exercicio_substituto': substituteExercise,
      'tecnica': technique,
      'tempo_excentrica': eccentricSeconds,
      'tempo_concentrica': concentricSeconds,
      'descanso_entre_series': restBetweenSetsSeconds,
      'exercicios_combinados': combinedExercises,
    };
  }

  factory WorkoutExercise.fromJson(Map<String, Object?> json) {
    final combinedRaw = json['exercicios_combinados'] as List<dynamic>?;
    return WorkoutExercise(
      name: json['nome'] as String,
      series: (json['series'] as num).toInt(),
      repetitions: (json['reps'] as num).toInt(),
      equipmentType: EquipmentTypeX.fromString(json['equipamento'] as String?),
      suggestedLoad: (json['carga_sugerida'] as num?)?.toDouble(),
      notes: json['observacoes'] as String?,
      substituteExercise: json['exercicio_substituto'] as String?,
      technique: json['tecnica'] as String?,
      eccentricSeconds: (json['tempo_excentrica'] as num?)?.toInt(),
      concentricSeconds: (json['tempo_concentrica'] as num?)?.toInt(),
      restBetweenSetsSeconds: (json['descanso_entre_series'] as num?)?.toInt(),
      combinedExercises: combinedRaw?.map((e) => e.toString()).toList(),
    );
  }
}

class WorkoutDay {
  const WorkoutDay({
    required this.dayLabel,
    required this.muscleGroup,
    required this.exercises,
    this.focus,
  });

  final String dayLabel;
  final String muscleGroup;
  final List<WorkoutExercise> exercises;
  final String? focus;

  Map<String, Object?> toJson() {
    return {
      'dia': dayLabel,
      'grupo_muscular': muscleGroup,
      'foco': focus,
      'exercicios': exercises.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory WorkoutDay.fromJson(Map<String, Object?> json) {
    final exercisesRaw = json['exercicios'] as List<dynamic>? ?? [];
    return WorkoutDay(
      dayLabel: json['dia'] as String,
      muscleGroup: json['grupo_muscular'] as String,
      focus: json['foco'] as String?,
      exercises: exercisesRaw
          .map((dynamic item) => WorkoutExercise.fromJson((item as Map).cast<String, Object?>()))
          .toList(),
    );
  }
}

class WorkoutPlan {
  const WorkoutPlan({
    this.id,
    required this.userId,
    required this.generatedAt,
    required this.objective,
    this.focus,
    required this.days,
    this.metadata,
    this.desiredDays,
    this.sessionDurationMinutes,
    this.source = 'ai',
  });

  final int? id;
  final int userId;
  final DateTime generatedAt;
  final String objective;
  final String? focus;
  final List<WorkoutDay> days;
  final Map<String, dynamic>? metadata;
  final int? desiredDays;
  final int? sessionDurationMinutes;
  /// 'ai' | 'auto' | 'manual'
  final String source;

  Map<String, Object?> toMap() {
    final meta = metadata != null ? Map<String, dynamic>.from(metadata!) : <String, dynamic>{};
    if (desiredDays != null) {
      meta['desired_days'] = desiredDays;
    }
    if (sessionDurationMinutes != null) {
      meta['session_duration_minutes'] = sessionDurationMinutes;
    }
    meta['source'] = source;
    return {
      'id': id,
      'user_id': userId,
      'generated_at': generatedAt.toIso8601String(),
      'objective': objective,
      'focus': focus,
      'metadata': jsonEncode(meta),
      'plan_json': jsonEncode(days.map((e) => e.toJson()).toList()),
    };
  }

  factory WorkoutPlan.fromMap(Map<String, Object?> map) {
    final planJson = map['plan_json'] as String;
    final List<dynamic> parsed = jsonDecode(planJson) as List<dynamic>;
    final metadataString = map['metadata'] as String?;
    Map<String, dynamic>? metadata;
    int? desiredDays;
    int? sessionDurationMinutes;
    if (metadataString != null && metadataString.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadataString);
        if (decoded is Map<String, dynamic>) {
          metadata = Map<String, dynamic>.from(decoded);
          final desired = metadata['desired_days'];
          final duration = metadata['session_duration_minutes'];
          if (desired is num) {
            desiredDays = desired.toInt();
          }
          if (duration is num) {
            sessionDurationMinutes = duration.toInt();
          }
        }
      } catch (_) {
        metadata = null;
      }
    }
    final sourceValue = metadata?['source'] as String? ?? 'ai';
    return WorkoutPlan(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      generatedAt: DateTime.parse(map['generated_at'] as String),
      objective: map['objective'] as String,
      focus: map['focus'] as String?,
      metadata: metadata,
      desiredDays: desiredDays,
      sessionDurationMinutes: sessionDurationMinutes,
      source: sourceValue,
      days: parsed
          .map((dynamic e) => WorkoutDay.fromJson((e as Map).cast<String, Object?>()))
          .toList(),
    );
  }

  WorkoutPlan copyWith({
    int? id,
    int? userId,
    DateTime? generatedAt,
    String? objective,
    String? focus,
    List<WorkoutDay>? days,
    Map<String, dynamic>? metadata,
    int? desiredDays,
    int? sessionDurationMinutes,
    String? source,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      generatedAt: generatedAt ?? this.generatedAt,
      objective: objective ?? this.objective,
      focus: focus ?? this.focus,
      days: days ?? this.days,
      metadata: metadata ?? this.metadata,
      desiredDays: desiredDays ?? this.desiredDays,
      sessionDurationMinutes: sessionDurationMinutes ?? this.sessionDurationMinutes,
      source: source ?? this.source,
    );
  }
}
