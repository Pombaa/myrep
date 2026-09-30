import 'package:flutter_test/flutter_test.dart';
import 'package:treinai/core/utils/workout_text_parser.dart';

void main() {
  test('parse PPL markdown plan with 6 training days', () {
    const text = '''
### O Teu Plano de Treino Final (Push / Pull / Legs — 6 Dias)

#### Segunda-feira: Push A (Peitoral, Deltoide e Tríceps — Foco Carga Estável)

1. **Supino Reto na Máquina:** 3 séries de 6 a 8 repetições (RIR 2 — *cuidado com o tríceps*) | *2 a 3 min de descanso*
2. **Supino Inclinado na Máquina:** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
3. **Desenvolvimento na Máquina Hammer:** 3 séries de 8 a 10 repetições (RIR 2) | *2 min de descanso*
4. **Crucifixo na Máquina (Peck Deck):** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
5. **Elevações Laterais com Halteres ou Polia:** 4 séries de 10 a 12 repetições (RIR 1) | *60 a 90 s de descanso*
6. **Tríceps na Polia com Barra Reta:** 2 a 3 séries de 10 a 12 repetições (*carga controlada, sem dor*) | *90 s de descanso*

---

#### Terça-feira: Pull A (Dorsais, Deltoide Posterior, Trapézio e Bíceps)

1. **Puxador Alto (Pega aberta tradicional):** 3 séries de 6 a 8 repetições (RIR 1–2) | *2 a 3 min de descanso*
2. **Remada na Máquina Convergente (apoio de pés/movimento ascendente):** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
3. **Máquina de Remada (Pega fechada ou neutra):** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
4. **Posterior de Ombro no Peck Deck Invertido:** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
5. **Encolhimento para Trapézio (com Halteres ou Máquina):** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
6. **Bíceps com Barra Reta:** 3 séries de 8 a 10 repetições (RIR 1) | *90 s de descanso*

---

#### Quarta-feira: Legs A (Ênfase Estrutural e Cadeia Posterior)

1. **Agachamento Livre:** 3 séries de 6 a 8 repetições (RIR 2 — *guarda sempre 2 reps no tanque*) | *2 a 3 min de descanso*
2. **Stiff (com Barra ou Halteres):** 3 séries de 8 a 10 repetições (RIR 2) | *2 min de descanso*
3. **Cadeira Extensora:** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
4. **Cadeira Flexora:** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
5. **Gémeos / Panturrilha em Pé (Smith ou Máquina):** 4 séries de 10 a 12 repetições (pausa de 2 s no pico de alongamento) | *60 s de descanso*

---

#### Quinta-feira: Push B (Peitoral, Deltoide e Tríceps — Foco Máquinas e Tensão Contínua)

1. **Supino Inclinado na Máquina:** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
2. **Supino Reto na Máquina:** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
3. **Crucifixo na Máquina:** 3 séries de 12 a 15 repetições (RIR 1) | *90 s de descanso*
4. **Elevações Laterais:** 4 séries de 12 a 15 repetições (RIR 0–1) | *60 a 90 s de descanso*
5. **Tríceps Corda Francês:** 3 séries de 10 a 12 repetições (RIR 1 — *execução suave na extensão*) | *90 s de descanso*
6. **Tríceps Barra Y / Testa na Polia:** 2 a 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*

---

#### Sexta-feira: Pull B (Dorsais, Posterior e Bíceps — Variação de Ângulos)

1. **Máquina de Costas para Puxada Alta (ângulo alternativo):** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
2. **Remada Baixa ou Máquina Convergente:** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
3. **Puxador Alto (Pega neutra ou triângulo):** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*
4. **Posterior de Ombro no Peck Deck Invertido:** 3 séries de 12 a 15 repetições (RIR 0–1) | *90 s de descanso*
5. **Bíceps Rosca Martelo com Halteres:** 3 séries de 10 a 12 repetições (RIR 1) | *90 s de descanso*

---

#### Sábado: Legs B (Economia Articular / Foco em Máquinas)

1. **Leg Press 45°:** 3 séries de 8 a 10 repetições (RIR 1–2) | *2 min de descanso*
2. **Cadeira Flexora:** 3 séries de 8 a 10 repetições (RIR 1) | *90 s de descanso*
3. **Cadeira Extensora:** 3 séries de 12 a 15 repetições (RIR 1) | *90 s de descanso*
4. **Cadeira Abdutora (alternar semanalmente com Adutora):** 3 séries de 12 a 15 repetições (RIR 1) | *60 a 90 s de descanso*
5. **Gémeos / Panturrilha Sentado:** 4 séries de 12 a 15 repetições (RIR 0–1) | *60 s de descanso*

---

#### Domingo: Descanso Absoluto

* Sono reforçado, hidratação adequada e alimentação rica em proteína.

---

### 3 Regras para o Sucesso a Partir de Segunda-Feira

1. **Regista as tuas marcas:** Mantém um caderno.
''';

    final days = tryParseWorkoutText(text);
    expect(days, isNotNull);
    expect(days!.length, 6);
    expect(days[0].dayLabel, contains('Push A'));
    expect(days[0].exercises.length, 6);
    expect(days[0].exercises.first.name, 'Supino Reto na Máquina');
    expect(days[0].exercises.first.series, 3);
    expect(days[0].exercises.first.repetitions, 6);
    expect(days[0].exercises.last.series, 2); // "2 a 3 séries"
    expect(days[5].dayLabel, contains('Legs B'));
    expect(days[5].exercises.length, 5);
    expect(days.any((d) => d.dayLabel.toLowerCase().contains('descanso')),
        isFalse);
  });

  test('extractJsonPayload strips fence and prose', () {
    const raw = '''
Aqui está o JSON:
```json
{"treinos":[{"nome":"A","exercicios":[{"nome":"Supino","series":3,"repeticoes":"8-10","observacao":""}]}]}
```
''';
    final payload = extractJsonPayload(raw);
    expect(payload, isNotNull);
    expect(payload!.startsWith('{'), isTrue);
  });

  test('workoutDayFromLooseMap tolerates string series/reps', () {
    final day = workoutDayFromLooseMap({
      'nome': 'Push',
      'exercicios': [
        {
          'nome': 'Supino',
          'series': '3',
          'repeticoes': '8-10',
          'observacao': 'RIR 2',
        }
      ],
    });
    expect(day.exercises.single.series, 3);
    expect(day.exercises.single.repetitions, 8);
    expect(day.exercises.single.notes, contains('Faixa 8–10'));
  });
}
