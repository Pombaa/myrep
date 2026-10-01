import 'package:flutter_test/flutter_test.dart';
import 'package:treinai/core/utils/workout_day_matcher.dart';

void main() {
  test('day badge keeps weekday initials and drops the muscle phrase', () {
    expect(dayBadgeLabel('Segunda-feira'), 'Seg');
    expect(dayBadgeLabel('Segunda'), 'Seg');
    expect(
      dayBadgeLabel(
        'Segunda-feira: Push A (Peitoral, Deltoide e Tríceps — Foco Carga Estável)',
      ),
      'Seg',
    );
    expect(dayBadgeLabel('Sábado: Legs B'), 'Sáb');
    expect(dayBadgeLabel('Peito e Tríceps'), 'PT');
    expect(dayBadgeLabel('Push B'), 'PB');
    expect(dayBadgeLabel('Treino A'), 'A');
  });
}
