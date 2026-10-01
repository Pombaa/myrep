import '../../models/exercise_progression_suggestion.dart';
import '../../models/workout_set.dart';

class MonthProgressLine {
  const MonthProgressLine({
    required this.exerciseName,
    required this.change,
  });

  final String exerciseName;
  final String change;
}

/// First vs last completed performance in [entries], which must already be
/// limited to one month. Unchanged exercises are omitted. At most six lines,
/// largest load change first.
List<MonthProgressLine> monthProgressLines(List<ExerciseHistoryEntry> entries) {
  final grouped = <String, List<ExerciseHistoryEntry>>{};
  for (final entry in entries) {
    grouped.putIfAbsent(entry.exerciseName, () => []).add(entry);
  }

  final ranked = <({MonthProgressLine line, double weight})>[];
  for (final group in grouped.values) {
    if (group.length < 2) continue;
    group.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    final first = _workingSet(group.first);
    final last = _workingSet(group.last);
    if (first == null || last == null) continue;

    final loadDelta = last.load - first.load;
    final repsDelta = last.reps - first.reps;
    if (loadDelta.abs() < 0.4 && repsDelta == 0) continue;

    final change = switch ((loadDelta.abs() >= 0.4, repsDelta != 0)) {
      (true, true) => '${_signedLoad(loadDelta)} · ${_signedReps(repsDelta)}',
      (true, false) => _signedLoad(loadDelta),
      (false, true) => _signedReps(repsDelta),
      _ => '',
    };
    if (change.isEmpty) continue;
    ranked.add((
      line: MonthProgressLine(
        exerciseName: group.first.exerciseName,
        change: change,
      ),
      weight: loadDelta.abs() + repsDelta.abs() * 0.1,
    ));
  }

  ranked.sort((a, b) => b.weight.compareTo(a.weight));
  return ranked.take(6).map((item) => item.line).toList();
}

WorkoutSet? _workingSet(ExerciseHistoryEntry entry) {
  final done = entry.sets.where((set) => set.completed).toList();
  if (done.isEmpty) return null;
  return done.last;
}

String _signedLoad(double delta) {
  final text = delta == delta.roundToDouble()
      ? delta.abs().toInt().toString()
      : delta.abs().toStringAsFixed(1);
  final sign = delta > 0 ? '+' : '−';
  return '$sign$text kg';
}

String _signedReps(int delta) {
  final sign = delta > 0 ? '+' : '−';
  final label = delta.abs() == 1 ? 'rep' : 'reps';
  return '$sign${delta.abs()} $label';
}
