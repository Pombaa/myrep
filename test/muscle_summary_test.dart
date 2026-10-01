import 'package:flutter_test/flutter_test.dart';
import 'package:treinai/core/utils/muscle_summary.dart';
import 'package:treinai/core/utils/workout_day_matcher.dart';
import 'package:treinai/models/workout_plan.dart';

WorkoutDay _day(String label, List<String> names) {
  return WorkoutDay(
    dayLabel: label,
    muscleGroup: 'Peito',
    exercises: [
      for (final name in names)
        WorkoutExercise(name: name, series: 3, repetitions: 8),
    ],
  );
}

void main() {
  test('push day lists chest, shoulder and triceps', () {
    final day = _day('Quinta-feira: Push B', [
      'Supino Inclinado na Máquina',
      'Supino Reto na Máquina',
      'Crucifixo na Máquina',
      'Elevações Laterais',
      'Tríceps Corda Francês',
      'Tríceps Barra Y / Testa na Polia',
    ]);
    expect(foldPt('Elevações Laterais'), 'elevacoes laterais');
    expect(muscleForExerciseName('Elevações Laterais'), 'Ombro');
    expect(muscleSummaryForDay(day), 'Peito, Ombro e Tríceps');
  });

  test('legs day is not Misto when names are not in the library verbatim', () {
    final day = _day('Sábado: Legs B', [
      'Leg Press 45°',
      'Cadeira Flexora',
      'Cadeira Extensora',
      'Cadeira Abdutora (alternar semanalmente com Adutora)',
      'Gémeos / Panturrilha Sentado',
    ]);
    expect(muscleSummaryForDay(day), 'Pernas e Panturrilha');
  });

  test('rear delt machine is shoulder, not chest', () {
    expect(
      muscleForExerciseName('Posterior de Ombro no Peck Deck Invertido'),
      'Ombro',
    );
  });

  test('today is moved to the front and the other days keep order', () {
    final plan = WorkoutPlan(
      userId: 1,
      generatedAt: DateTime(2026, 9, 30),
      objective: 'Hipertrofia',
      days: [
        _day('Segunda-feira: Push A', ['Supino Reto na Máquina']),
        _day('Terça-feira: Pull A', ['Puxador Alto']),
        _day('Quarta-feira: Legs A', ['Agachamento Livre']),
        _day('Quinta-feira: Push B', ['Supino Reto na Máquina']),
      ],
    );
    final ordered = planDaysWithTodayFirst(plan, DateTime(2026, 10, 1));
    expect(ordered.first.dayLabel, contains('Quinta'));
    expect(ordered.map((d) => d.dayLabel.split(':').first).toList(), [
      'Quinta-feira',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
    ]);
  });
}
