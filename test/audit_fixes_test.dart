import 'package:flutter_test/flutter_test.dart';
import 'package:treinai/core/utils/muscle_load.dart';
import 'package:treinai/models/exercise_progression_suggestion.dart';
import 'package:treinai/models/workout_set.dart';
import 'package:treinai/services/workout_draft_store.dart';
import 'package:treinai/models/workout_plan.dart';

void main() {
  test('muscle bars average the latest load and the change inside the group', () {
    final bars = muscleLoadBars([
      ExerciseHistoryEntry(
        userId: 1,
        sessionDate: DateTime(2026, 9, 1),
        exerciseName: 'Supino Reto',
        muscleGroup: 'Peito',
        sets: [WorkoutSet(setIndex: 0, reps: 8, load: 40, completed: true)],
        repScheme: RepScheme.straightSets,
      ),
      ExerciseHistoryEntry(
        userId: 1,
        sessionDate: DateTime(2026, 9, 8),
        exerciseName: 'Supino Reto',
        muscleGroup: 'Peito',
        sets: [WorkoutSet(setIndex: 0, reps: 8, load: 42.5, completed: true)],
        repScheme: RepScheme.straightSets,
      ),
    ]);
    expect(bars, hasLength(1));
    expect(bars.single.muscle, 'Peito');
    expect(bars.single.averageKg, 42.5);
    expect(bars.single.deltaKg, 2.5);
  });

  test('draft json keeps the recorded sets', () {
    final draft = WorkoutDraft(
      day: const WorkoutDay(
        dayLabel: 'Quinta-feira: Push B',
        muscleGroup: 'Peito',
        exercises: [
          WorkoutExercise(name: 'Supino Reto', series: 3, repetitions: 8),
        ],
      ),
      exerciseIndex: 0,
      currentSet: 2,
      loads: ['40'],
      reps: ['8'],
      recorded: {
        0: [WorkoutSet(setIndex: 0, reps: 8, load: 40, completed: true)],
      },
    );
    final restored = WorkoutDraft.fromJson(draft.toJson());
    expect(restored.day.dayLabel, 'Quinta-feira: Push B');
    expect(restored.currentSet, 2);
    expect(restored.recorded[0]!.single.load, 40);
  });
}
