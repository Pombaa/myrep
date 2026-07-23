import 'package:flutter/material.dart';

import '../../models/workout_plan.dart';
import 'workout_session_screen.dart';

/// One-time workout that starts a session without saving/replacing the plan.
class OneOffWorkoutScreen extends StatefulWidget {
  const OneOffWorkoutScreen({super.key});

  @override
  State<OneOffWorkoutScreen> createState() => _OneOffWorkoutScreenState();
}

class _OneOffWorkoutScreenState extends State<OneOffWorkoutScreen> {
  final _titleController = TextEditingController(text: 'Avulso');
  final _groupController = TextEditingController(text: 'Recuperação');
  final _pasteController = TextEditingController();
  List<WorkoutExercise> _exercises = [];
  String? _parseError;

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  void _parsePaste() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _exercises = [];
        _parseError = null;
      });
      return;
    }

    final parsed = parseOneOffWorkoutText(text);
    setState(() {
      _exercises = parsed;
      _parseError = parsed.isEmpty
          ? 'Não reconheci exercícios. Use linhas como:\nCadeira extensora  3x15-20  — observação'
          : null;
    });
  }

  void _start() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cole ou adicione pelo menos 1 exercício.')),
      );
      return;
    }

    final day = WorkoutDay(
      dayLabel: _titleController.text.trim().isEmpty
          ? 'Avulso'
          : _titleController.text.trim(),
      muscleGroup: _groupController.text.trim().isEmpty
          ? 'Recuperação'
          : _groupController.text.trim(),
      focus: 'Treino avulso — não altera o plano principal',
      exercises: _exercises,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(day: day, plan: null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino avulso'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Só pra hoje (ou quando precisar). Não substitui seu plano de 4 treinos.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex: Pernas leve / Recuperação',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _groupController,
            decoration: const InputDecoration(
              labelText: 'Grupo',
              hintText: 'Ex: Pernas · Recuperação',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          Text(
            'Cole o treino',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Uma linha por exercício: nome, séries×reps e observação opcional.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pasteController,
            maxLines: 10,
            onChanged: (_) => _parsePaste(),
            decoration: InputDecoration(
              hintText:
                  'Cadeira extensora  3x15-20  — leve, pausa no topo\n'
                  'Adutora  3x15-20  — moderado\n'
                  'Abdutora  3x15-20  — moderado',
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: 10),
            Text(
              _parseError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          if (_exercises.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${_exercises.length} exercícios',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _exercises[i].name,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_exercises[i].series}×${_exercises[i].repetitions}'
                              '${_exercises[i].notes != null ? ' · ${_exercises[i].notes}' : ''}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _exercises.isEmpty ? null : _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Iniciar agora'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parses free-text lines like:
/// `Cadeira extensora  3x15-20  — leve/moderado, pausa no topo`
List<WorkoutExercise> parseOneOffWorkoutText(String text) {
  final exercises = <WorkoutExercise>[];
  // name + series x reps[-reps] + optional note after dash
  final re = RegExp(
    r'^(.+?)\s+(\d+)\s*[x×]\s*(\d+)(?:\s*[-–]\s*(\d+))?\s*(?:[—\-–]\s*(.+))?$',
    caseSensitive: false,
  );

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final match = re.firstMatch(line);
    if (match == null) continue;

    final name = match.group(1)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    final series = int.parse(match.group(2)!);
    final repsLow = int.parse(match.group(3)!);
    final repsHigh = match.group(4) != null ? int.parse(match.group(4)!) : null;
    final note = match.group(5)?.trim();

    // Prefer mid of range for the default target, else the single value.
    final reps = repsHigh != null ? ((repsLow + repsHigh) / 2).round() : repsLow;

    exercises.add(
      WorkoutExercise(
        name: name,
        series: series,
        repetitions: reps,
        notes: (note != null && note.isNotEmpty)
            ? (repsHigh != null ? '$repsLow–$repsHigh · $note' : note)
            : (repsHigh != null ? 'Faixa $repsLow–$repsHigh' : null),
      ),
    );
  }

  return exercises;
}
