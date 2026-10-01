import 'package:flutter_test/flutter_test.dart';
import 'package:treinai/core/utils/month_progress.dart';
import 'package:treinai/models/exercise_progression_suggestion.dart';
import 'package:treinai/models/workout_set.dart';
import 'package:treinai/services/progression_analyzer.dart';

ExerciseHistoryEntry _entry({
  required String name,
  required DateTime date,
  required List<WorkoutSet> sets,
  String muscle = 'Peito',
  RepScheme scheme = RepScheme.straightSets,
}) {
  return ExerciseHistoryEntry(
    userId: 1,
    sessionDate: date,
    exerciseName: name,
    muscleGroup: muscle,
    sets: sets,
    repScheme: scheme,
  );
}

List<WorkoutSet> _sets(int reps, double load, {int count = 3, bool done = true}) {
  return [
    for (var i = 0; i < count; i++)
      WorkoutSet(setIndex: i, reps: reps, load: load, completed: done),
  ];
}

void main() {
  const analyzer = ProgressionAnalyzer();

  test('completed straight sets under 12 reps step up reps, not load', () {
    final target = analyzer.nextSessionTarget(
      _entry(
        name: 'Supino Reto',
        date: DateTime(2026, 9, 28),
        sets: _sets(8, 40),
      ),
    );
    expect(target, isNotNull);
    expect(target!.reps, 10);
    expect(target.load, 40);
    expect(target.hint, contains('→ 10 reps'));
  });

  test('top of the rep range steps the load', () {
    final target = analyzer.nextSessionTarget(
      _entry(
        name: 'Supino Reto',
        date: DateTime(2026, 9, 28),
        sets: _sets(12, 40),
      ),
    );
    expect(target!.reps, 8);
    expect(target.load, 42.5);
    expect(target.hint, contains('42.5 kg'));
  });

  test('an unfinished session repeats the last completed numbers', () {
    final target = analyzer.nextSessionTarget(
      _entry(
        name: 'Supino Reto',
        date: DateTime(2026, 9, 28),
        sets: [
          WorkoutSet(setIndex: 0, reps: 8, load: 40, completed: true),
          WorkoutSet(setIndex: 1, reps: 8, load: 40, completed: false),
          WorkoutSet(setIndex: 2, reps: 8, load: 40, completed: false),
        ],
      ),
    );
    expect(target!.reps, 8);
    expect(target.load, 40);
    expect(target.hint, isNot(contains('→')));
  });

  test('month list keeps only exercises that moved, heaviest first', () {
    final lines = monthProgressLines([
      _entry(
        name: 'Rosca Direta',
        date: DateTime(2026, 10, 1),
        muscle: 'Bíceps',
        sets: _sets(8, 10),
      ),
      _entry(
        name: 'Rosca Direta',
        date: DateTime(2026, 10, 8),
        muscle: 'Bíceps',
        sets: _sets(10, 10),
      ),
      _entry(
        name: 'Supino Reto',
        date: DateTime(2026, 10, 2),
        sets: _sets(8, 40),
      ),
      _entry(
        name: 'Supino Reto',
        date: DateTime(2026, 10, 9),
        sets: _sets(8, 42.5),
      ),
      _entry(
        name: 'Leg Press',
        date: DateTime(2026, 10, 3),
        muscle: 'Pernas',
        sets: _sets(10, 100),
      ),
    ]);

    expect(lines.map((line) => line.exerciseName).toList(), [
      'Supino Reto',
      'Rosca Direta',
    ]);
    expect(lines[0].change, '+2.5 kg');
    expect(lines[1].change, '+2 reps');
  });
}
