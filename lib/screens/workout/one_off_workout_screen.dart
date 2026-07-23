import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise_library.dart';
import '../../models/workout_plan.dart';
import '../../providers/services_providers.dart';
import '../../providers/settings_providers.dart';
import 'workout_session_screen.dart';

/// One-time workout that starts a session without saving/replacing the plan.
class OneOffWorkoutScreen extends ConsumerStatefulWidget {
  const OneOffWorkoutScreen({super.key});

  @override
  ConsumerState<OneOffWorkoutScreen> createState() =>
      _OneOffWorkoutScreenState();
}

class _OneOffWorkoutScreenState extends ConsumerState<OneOffWorkoutScreen> {
  final _titleController = TextEditingController(text: 'Avulso');
  final _groupController = TextEditingController(text: 'Recuperação');
  final _pasteController = TextEditingController();
  List<WorkoutExercise> _exercises = [];
  String? _parseError;
  String? _parseHint;
  bool _isConverting = false;

  static const _systemPrompt =
      'Analise o texto de treino e converta para JSON estruturado. '
      'Responda APENAS com o JSON, sem markdown, sem explicação.\n\n'
      'Este é um treino AVULSO (um único dia). Formato obrigatório:\n'
      '{\n'
      '  "treinos": [\n'
      '    {\n'
      '      "nome": "Pernas leve",\n'
      '      "exercicios": [\n'
      '        { "nome": "Cadeira Extensora", "series": 3, "repeticoes": "15-20", "observacao": "leve/moderado" }\n'
      '      ]\n'
      '    }\n'
      '  ]\n'
      '}\n\n'
      'Regras:\n'
      '- Em "3x15-20": series=3 e repeticoes="15-20" (NÃO use a média como séries)\n'
      '- series: número inteiro\n'
      '- repeticoes: string ("10", "8-12", "15-20")\n'
      '- observacao: o que vier após — ou notas; "" se não houver\n'
      '- Um único item em "treinos" se for só um treino do dia';

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  void _parseLocal() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _exercises = [];
        _parseError = null;
        _parseHint = null;
      });
      return;
    }

    final fromJson = _tryParseOneOffJson(text);
    if (fromJson != null) {
      setState(() {
        _exercises = fromJson.exercises;
        _parseError =
            fromJson.exercises.isEmpty ? 'JSON sem exercícios.' : null;
        _parseHint = fromJson.exercises.isEmpty ? null : 'Lido como JSON';
        _applyMeta(fromJson.dayLabel, fromJson.muscleGroup);
      });
      return;
    }

    final parsed = parseOneOffWorkoutText(text);
    setState(() {
      _exercises = parsed;
      _parseHint = parsed.isEmpty ? null : 'Lido como texto';
      _parseError = parsed.isEmpty
          ? 'Não reconheci automaticamente. Toque em “Converter com IA”.'
          : null;
    });
  }

  void _applyMeta(String dayLabel, String muscleGroup) {
    if (dayLabel.isNotEmpty &&
        (_titleController.text.trim().isEmpty ||
            _titleController.text.trim() == 'Avulso')) {
      _titleController.text = dayLabel;
    }
    if (muscleGroup.isNotEmpty &&
        (_groupController.text.trim().isEmpty ||
            _groupController.text.trim() == 'Recuperação')) {
      _groupController.text = muscleGroup;
    }
  }

  Future<void> _convertWithAi() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isConverting = true;
      _parseError = null;
    });

    try {
      final aiProvider = ref.read(selectedAiProviderProvider);
      final apiKeyState = aiProvider == AiProvider.nvidia
          ? ref.read(nvidiaKeyProvider)
          : ref.read(openAiKeyProvider);
      final apiKey = apiKeyState.valueOrNull;

      if (apiKey == null || apiKey.isEmpty) {
        final name = aiProvider == AiProvider.nvidia ? 'NVIDIA' : 'OpenAI';
        throw Exception('Configure a chave da API $name nas configurações.');
      }

      final service = ref.read(openAiServiceProvider);
      final result = await service.generateWorkoutPlan(
        apiKey: apiKey,
        baseUrl: aiProvider.baseUrl,
        model: aiProvider == AiProvider.nvidia
            ? aiProvider.defaultModel
            : 'gpt-4o-mini',
        useStructuredOutput: false,
        temperature: 0.2,
        providerLabel: aiProvider.label,
        messages: [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': text},
        ],
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final raw = decoded['treinos'];
      final List<dynamic> workouts = raw is List ? raw : [decoded];
      if (workouts.isEmpty) throw Exception('A IA não retornou exercícios.');

      final day = _dayFromAiMap(workouts.first);
      setState(() {
        _exercises = day.exercises;
        _parseHint = 'Convertido com IA';
        _parseError = null;
        _applyMeta(day.dayLabel, day.muscleGroup);
      });
    } catch (e) {
      setState(() {
        _parseError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  WorkoutDay _dayFromAiMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final exercisesRaw = map['exercicios'] as List<dynamic>? ?? [];

    final exercises = exercisesRaw.map((e) {
      final em = e as Map<String, dynamic>;

      final repsRaw = em['repeticoes'];
      int reps = 10;
      String? rangeNote;
      if (repsRaw != null) {
        final str = repsRaw.toString();
        final range = RegExp(r'(\d+)\s*[-–]\s*(\d+)').firstMatch(str);
        if (range != null) {
          reps = int.parse(range.group(1)!);
          rangeNote = 'Faixa ${range.group(1)}–${range.group(2)}';
        } else {
          final match = RegExp(r'\d+').firstMatch(str);
          if (match != null) reps = int.parse(match.group(0)!);
        }
      }

      final seriesRaw = em['series'];
      final series = seriesRaw != null ? (seriesRaw as num).toInt() : 3;
      final obs = em['observacao'] as String?;
      final notes = [
        if (rangeNote != null) rangeNote,
        if (obs != null && obs.isNotEmpty) obs,
      ].join(' · ');

      return WorkoutExercise(
        name: em['nome'] as String,
        series: series,
        repetitions: reps,
        notes: notes.isEmpty ? null : notes,
      );
    }).toList();

    final muscleGroup = exercises.isNotEmpty
        ? (muscleGroupForExercise(exercises.first.name) ??
            _groupController.text.trim())
        : _groupController.text.trim();

    return WorkoutDay(
      dayLabel: (map['nome'] as String?) ?? _titleController.text.trim(),
      muscleGroup:
          muscleGroup.isEmpty ? 'Recuperação' : muscleGroup,
      exercises: exercises,
    );
  }

  void _start() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cole o treino e converta antes de iniciar.'),
        ),
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
    final hasText = _pasteController.text.trim().isNotEmpty;

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
                    'Só pra hoje — não mexe no plano.\n'
                    'Cole em qualquer formato; a IA deixa no formato do app se precisar.',
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
            'Texto livre, WhatsApp ou JSON — igual ao importar.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pasteController,
            maxLines: 12,
            onChanged: (_) => _parseLocal(),
            decoration: InputDecoration(
              hintText:
                  'Cadeira extensora  3x15-20  — leve, pausa no topo\n'
                  'Adutora  3x15-20  — moderado',
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_parseHint != null) ...[
            const SizedBox(height: 8),
            Text(
              _parseHint!,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_parseError != null) ...[
            const SizedBox(height: 10),
            Text(
              _parseError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  (!hasText || _isConverting) ? null : _convertWithAi,
              icon: _isConverting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isConverting ? 'Convertendo com IA...' : 'Converter com IA',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
          if (_exercises.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '${_exercises.length} exercícios',
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                              '${_exercises[i].series} séries × ${_exercises[i].repetitions} reps'
                              '${_exercises[i].notes != null ? '\n${_exercises[i].notes}' : ''}',
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

class _ParsedOneOff {
  const _ParsedOneOff({
    required this.exercises,
    this.dayLabel = '',
    this.muscleGroup = '',
  });

  final List<WorkoutExercise> exercises;
  final String dayLabel;
  final String muscleGroup;
}

_ParsedOneOff? _tryParseOneOffJson(String text) {
  if (!(text.startsWith('[') || text.startsWith('{'))) return null;

  try {
    final decoded = jsonDecode(text);

    if (decoded is List) {
      if (decoded.isEmpty) {
        return const _ParsedOneOff(exercises: []);
      }
      final first = decoded.first;
      if (first is! Map) return null;
      final map = first.cast<String, Object?>();

      if (map.containsKey('dia') && map.containsKey('exercicios')) {
        final days = decoded
            .map((e) => WorkoutDay.fromJson((e as Map).cast<String, Object?>()))
            .toList();
        final day = days.firstWhere(
          (d) => d.exercises.isNotEmpty,
          orElse: () => days.first,
        );
        return _ParsedOneOff(
          exercises: day.exercises,
          dayLabel: day.dayLabel,
          muscleGroup: day.muscleGroup,
        );
      }

      if (map.containsKey('nome') &&
          (map.containsKey('series') || map.containsKey('reps'))) {
        return _ParsedOneOff(
          exercises: decoded
              .map((e) =>
                  WorkoutExercise.fromJson((e as Map).cast<String, Object?>()))
              .toList(),
        );
      }
      return null;
    }

    if (decoded is Map) {
      final map = decoded.cast<String, Object?>();

      if (map.containsKey('dia') && map.containsKey('exercicios')) {
        final day = WorkoutDay.fromJson(map);
        return _ParsedOneOff(
          exercises: day.exercises,
          dayLabel: day.dayLabel,
          muscleGroup: day.muscleGroup,
        );
      }

      if (map['exercicios'] is List) {
        final list = map['exercicios'] as List;
        return _ParsedOneOff(
          exercises: list
              .map((e) =>
                  WorkoutExercise.fromJson((e as Map).cast<String, Object?>()))
              .toList(),
          dayLabel: (map['dia'] as String?) ?? '',
          muscleGroup: (map['grupo_muscular'] as String?) ?? '',
        );
      }
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// `Nome  3x15-20  — obs` → 3 séries, 15 reps, faixa nas notas.
List<WorkoutExercise> parseOneOffWorkoutText(String text) {
  final exercises = <WorkoutExercise>[];
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
    final repsHigh =
        match.group(4) != null ? int.parse(match.group(4)!) : null;
    final note = match.group(5)?.trim();

    final noteParts = <String>[];
    if (repsHigh != null) noteParts.add('Faixa $repsLow–$repsHigh');
    if (note != null && note.isNotEmpty) noteParts.add(note);

    exercises.add(
      WorkoutExercise(
        name: name,
        series: series,
        repetitions: repsLow,
        notes: noteParts.isEmpty ? null : noteParts.join(' · '),
      ),
    );
  }

  return exercises;
}
