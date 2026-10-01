import '../../models/exercise_progression_suggestion.dart';

class MuscleLoadBar {
  const MuscleLoadBar({
    required this.muscle,
    required this.averageKg,
    required this.deltaKg,
  });

  final String muscle;
  final double averageKg;
  final double deltaKg;
}

/// Latest completed load per exercise, averaged inside each muscle group.
/// [deltaKg] is the mean change from the first logged session of each
/// exercise to the last. Zero when the exercise was logged once.
List<MuscleLoadBar> muscleLoadBars(List<ExerciseHistoryEntry> entries) {
  final byMuscle = <String, Map<String, List<ExerciseHistoryEntry>>>{};
  for (final entry in entries) {
    byMuscle.putIfAbsent(entry.muscleGroup, () => {});
    byMuscle[entry.muscleGroup]!.putIfAbsent(entry.exerciseName, () => []).add(entry);
  }

  final bars = <MuscleLoadBar>[];
  for (final muscle in byMuscle.entries) {
    final latestLoads = <double>[];
    final deltas = <double>[];
    for (final sessions in muscle.value.values) {
      sessions.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
      final first = _loadOf(sessions.first);
      final last = _loadOf(sessions.last);
      if (last == null || last <= 0) continue;
      latestLoads.add(last);
      if (first != null && sessions.length >= 2) {
        deltas.add(last - first);
      }
    }
    if (latestLoads.isEmpty) continue;
    final average = latestLoads.reduce((a, b) => a + b) / latestLoads.length;
    final delta = deltas.isEmpty
        ? 0.0
        : deltas.reduce((a, b) => a + b) / deltas.length;
    bars.add(MuscleLoadBar(
      muscle: muscle.key,
      averageKg: double.parse(average.toStringAsFixed(1)),
      deltaKg: double.parse(delta.toStringAsFixed(1)),
    ));
  }

  bars.sort((a, b) => b.averageKg.compareTo(a.averageKg));
  return bars;
}

double? _loadOf(ExerciseHistoryEntry entry) {
  final done = entry.sets.where((set) => set.completed && set.load > 0).toList();
  if (done.isEmpty) return null;
  return done.last.load;
}
