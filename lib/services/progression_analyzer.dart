import '../models/exercise_progression_suggestion.dart';
import '../models/workout_set.dart';

class ProgressionAnalyzer {
  const ProgressionAnalyzer();

  RepScheme detectRepScheme(List<WorkoutSet> sets) {
    if (sets.length < 2) return RepScheme.straightSets;
    final reps = sets.map((s) => s.reps).toList();
    final allEqual = reps.every((r) => r == reps[0]);
    if (allEqual) return RepScheme.straightSets;

    bool strictlyDecreasing = true;
    bool strictlyIncreasing = true;
    for (int i = 1; i < reps.length; i++) {
      if (reps[i] >= reps[i - 1]) strictlyDecreasing = false;
      if (reps[i] <= reps[i - 1]) strictlyIncreasing = false;
    }
    if (strictlyDecreasing) return RepScheme.pyramidAscending;
    if (strictlyIncreasing) return RepScheme.pyramidDescending;
    return RepScheme.unknown;
  }

  bool shouldSuggestProgression(List<WorkoutSet> sets, RepScheme scheme) {
    if (sets.isEmpty) return false;
    switch (scheme) {
      case RepScheme.straightSets:
      case RepScheme.unknown:
        return sets.every((s) => s.completed);
      case RepScheme.pyramidAscending:
        return sets.last.completed;
      case RepScheme.pyramidDescending:
        return sets.first.completed;
    }
  }

  MuscleGroupSize muscleGroupSizeFor(String muscleGroup) {
    final lower = muscleGroup.toLowerCase();
    if (lower.contains('peito') ||
        lower.contains('costas') ||
        lower.contains('perna') ||
        lower.contains('glúteo') ||
        lower.contains('gluteo')) {
      return MuscleGroupSize.large;
    }
    if (lower.contains('ombro') ||
        lower.contains('bícep') ||
        lower.contains('bicep') ||
        lower.contains('trícep') ||
        lower.contains('tricep')) {
      return MuscleGroupSize.medium;
    }
    if (lower.contains('panturrilha') ||
        lower.contains('antebraço') ||
        lower.contains('antebraco') ||
        lower.contains('rotat')) {
      return MuscleGroupSize.isolated;
    }
    if (lower.contains('cardio') ||
        lower.contains('funcional') ||
        lower.contains('abdôm') ||
        lower.contains('abdom')) {
      return MuscleGroupSize.bodyweight;
    }
    return MuscleGroupSize.medium;
  }

  ExerciseProgressionSuggestion? analyzeExercise({
    required ExerciseHistoryEntry current,
    ExerciseHistoryEntry? previous,
  }) {
    if (!shouldSuggestProgression(current.sets, current.repScheme)) return null;

    final options = buildProgressionOptions(
      sets: current.sets,
      scheme: current.repScheme,
      muscleGroup: current.muscleGroup,
    );
    if (options.isEmpty) return null;

    final prevSummary = previous?.summaryLine ?? 'Primeira sessão';

    return ExerciseProgressionSuggestion(
      exerciseName: current.exerciseName,
      muscleGroup: current.muscleGroup,
      scheme: current.repScheme,
      currentSets: current.sets,
      previousSummary: prevSummary,
      recommendedOption: options.first,
      allOptions: options,
    );
  }

  List<ProgressionOption> buildProgressionOptions({
    required List<WorkoutSet> sets,
    required RepScheme scheme,
    required String muscleGroup,
  }) {
    if (sets.isEmpty) return [];
    final mgSize = muscleGroupSizeFor(muscleGroup);
    final loadDelta = mgSize.loadIncrement;

    switch (scheme) {
      case RepScheme.straightSets:
      case RepScheme.unknown:
        return _buildStraightSetsOptions(sets, loadDelta, mgSize);
      case RepScheme.pyramidAscending:
        return _buildPyramidAscendingOptions(sets, loadDelta);
      case RepScheme.pyramidDescending:
        return _buildPyramidDescendingOptions(sets, loadDelta);
    }
  }

  List<ProgressionOption> _buildStraightSetsOptions(
    List<WorkoutSet> sets,
    double loadDelta,
    MuscleGroupSize mgSize,
  ) {
    final options = <ProgressionOption>[];

    if (mgSize == MuscleGroupSize.bodyweight || sets.first.load == 0) {
      final newSets = sets.map((s) => s.copyWith(reps: s.reps + 1, completed: false)).toList();
      options.add(ProgressionOption(
        label: '+1 repetição',
        projectedSets: newSets,
        description: 'Adicione 1 rep em todas as séries',
      ));
      options.add(ProgressionOption(
        label: 'Manter',
        projectedSets: sets.map((s) => s.copyWith(completed: false)).toList(),
      ));
      return options;
    }

    final currentReps = sets.first.reps;
    final currentLoad = sets.first.load;
    final isAtTopRange = currentReps >= 12;

    if (!isAtTopRange) {
      final newSets = sets.map((s) => s.copyWith(reps: s.reps + 2, completed: false)).toList();
      options.add(ProgressionOption(
        label: '+2 reps → ${sets.length}x${currentReps + 2} com ${currentLoad.toStringAsFixed(1)}kg',
        projectedSets: newSets,
        description: 'Mantenha a carga e aumente as repetições',
      ));
    }

    final newLoad = _round(currentLoad + loadDelta);
    final newReps = isAtTopRange ? (currentReps - 4).clamp(6, 12) : currentReps;
    final loadSets = sets
        .map((s) => s.copyWith(load: newLoad, reps: newReps, completed: false))
        .toList();
    options.add(ProgressionOption(
      label: '+${loadDelta}kg → ${sets.length}x$newReps com ${newLoad.toStringAsFixed(1)}kg',
      projectedSets: loadSets,
      description: isAtTopRange
          ? 'Aumente a carga e reajuste as repetições'
          : 'Aumente apenas a carga',
    ));

    options.add(ProgressionOption(
      label: 'Manter',
      projectedSets: sets.map((s) => s.copyWith(completed: false)).toList(),
    ));
    return options;
  }

  List<ProgressionOption> _buildPyramidAscendingOptions(
    List<WorkoutSet> sets,
    double loadDelta,
  ) {
    final options = <ProgressionOption>[];

    final allLoadSets = sets
        .map((s) => s.copyWith(load: _round(s.load + loadDelta), completed: false))
        .toList();
    options.add(ProgressionOption(
      label: '+${loadDelta}kg em todas as séries',
      projectedSets: allLoadSets,
      description: 'Mantém o esquema de pirâmide e aumenta a carga',
    ));

    final lastRepSets = List<WorkoutSet>.from(
      sets.map((s) => s.copyWith(completed: false)),
    );
    lastRepSets[lastRepSets.length - 1] =
        lastRepSets.last.copyWith(reps: lastRepSets.last.reps + 1);
    options.add(ProgressionOption(
      label: '+1 rep na última série',
      projectedSets: lastRepSets,
      description: 'Aumenta a dificuldade na série mais pesada',
    ));

    if (sets.length < 5) {
      final penultimate = sets[sets.length - 2];
      final last = sets.last;
      final intermediateReps = ((penultimate.reps + last.reps) / 2).round();
      final intermediateLoad = _round((penultimate.load + last.load) / 2);
      final newSets = <WorkoutSet>[];
      for (int i = 0; i < sets.length - 1; i++) {
        newSets.add(sets[i].copyWith(completed: false));
      }
      newSets.add(WorkoutSet(
        setIndex: sets.length - 1,
        reps: intermediateReps,
        load: intermediateLoad,
        completed: false,
      ));
      newSets.add(last.copyWith(setIndex: sets.length, completed: false));
      options.add(ProgressionOption(
        label: '+1 série antes do pico',
        projectedSets: newSets,
        description: 'Adiciona volume com carga intermediária',
      ));
    }

    options.add(ProgressionOption(
      label: 'Manter',
      projectedSets: sets.map((s) => s.copyWith(completed: false)).toList(),
    ));
    return options;
  }

  List<ProgressionOption> _buildPyramidDescendingOptions(
    List<WorkoutSet> sets,
    double loadDelta,
  ) {
    final options = <ProgressionOption>[];

    final firstLoad = sets.first.load;
    if (firstLoad > 0) {
      final ratio = (firstLoad + loadDelta) / firstLoad;
      final propSets = sets
          .map((s) => s.copyWith(load: _round(s.load * ratio), completed: false))
          .toList();
      options.add(ProgressionOption(
        label: '+${loadDelta}kg na primeira série (proporcional)',
        projectedSets: propSets,
        description: 'Aumenta a carga em todas as séries proporcionalmente',
      ));
    }

    final lastRepSets = List<WorkoutSet>.from(
      sets.map((s) => s.copyWith(completed: false)),
    );
    lastRepSets[lastRepSets.length - 1] =
        lastRepSets.last.copyWith(reps: lastRepSets.last.reps + 2);
    options.add(ProgressionOption(
      label: '+2 reps na última série',
      projectedSets: lastRepSets,
      description: 'Aumenta o volume na série final (mais leve)',
    ));

    options.add(ProgressionOption(
      label: 'Manter',
      projectedSets: sets.map((s) => s.copyWith(completed: false)).toList(),
    ));
    return options;
  }

  double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
