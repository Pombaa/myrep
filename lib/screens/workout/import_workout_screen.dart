import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exercise_library.dart';
import '../../models/workout_plan.dart';
import '../../providers/services_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/user_providers.dart';
import '../../providers/workout_providers.dart';

class ImportWorkoutScreen extends ConsumerStatefulWidget {
  const ImportWorkoutScreen({super.key});

  @override
  ConsumerState<ImportWorkoutScreen> createState() => _ImportWorkoutScreenState();
}

class _ImportWorkoutScreenState extends ConsumerState<ImportWorkoutScreen> {
  final _textController = TextEditingController();
  List<WorkoutDay>? _preview;
  String? _error;
  bool _isConverting = false;
  bool _isSaving = false;

  static const _systemPrompt =
      'Analise o texto de treino e converta para JSON estruturado. '
      'Responda APENAS com o JSON, sem markdown, sem explicação.\n\n'
      'Identifique TODOS os dias de treino no texto — cada bloco separado por "---", '
      'por uma linha "Dia →" ou por título de treino é um dia diferente.\n\n'
      'Formato obrigatório (objeto com campo "treinos" contendo array):\n'
      '{\n'
      '  "treinos": [\n'
      '    {\n'
      '      "nome": "Segunda - Peito e Ombro",\n'
      '      "exercicios": [\n'
      '        { "nome": "Supino Inclinado Com Halter", "series": 4, "repeticoes": "8-10", "observacao": "" },\n'
      '        { "nome": "Peck Deck", "series": 3, "repeticoes": "12-15", "observacao": "" }\n'
      '      ]\n'
      '    },\n'
      '    {\n'
      '      "nome": "Terça - Costas",\n'
      '      "exercicios": [\n'
      '        { "nome": "Barra Fixa", "series": 4, "repeticoes": "6-10", "observacao": "" }\n'
      '      ]\n'
      '    }\n'
      '  ]\n'
      '}\n\n'
      'Regras:\n'
      '- series: número inteiro ou null\n'
      '- repeticoes: string ("10", "8-12", "até a falha") ou null\n'
      '- observacao: drop set, rest-pause, etc. String vazia "" se não houver\n'
      '- Linhas com ↳ são substitutos — coloque em observacao: "Substituto: [nome]"\n'
      '- Capitalize os nomes dos exercícios\n'
      '- Ignore separadores (---), notas e linhas que não são exercícios';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isConverting = true;
      _error = null;
      _preview = null;
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
        messages: [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': text},
        ],
      );

      final decoded = jsonDecode(result) as Map<String, dynamic>;
      final raw = decoded['treinos'];
      final List<dynamic> workouts = raw is List ? raw : [decoded];
      final days = workouts.map(_dayFromMap).toList();

      setState(() => _preview = days);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isConverting = false);
    }
  }

  WorkoutDay _dayFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final exercisesRaw = map['exercicios'] as List<dynamic>? ?? [];

    final exercises = exercisesRaw.map((e) {
      final em = e as Map<String, dynamic>;

      final repsRaw = em['repeticoes'];
      int reps = 10;
      if (repsRaw != null) {
        final match = RegExp(r'\d+').firstMatch(repsRaw.toString());
        if (match != null) reps = int.parse(match.group(0)!);
      }

      final seriesRaw = em['series'];
      final series = seriesRaw != null ? (seriesRaw as num).toInt() : 3;
      final obs = em['observacao'] as String?;

      return WorkoutExercise(
        name: em['nome'] as String,
        series: series,
        repetitions: reps,
        notes: (obs != null && obs.isNotEmpty) ? obs : null,
      );
    }).toList();

    final muscleGroup = exercises.isNotEmpty
        ? (muscleGroupForExercise(exercises.first.name) ?? 'Misto')
        : 'Misto';

    return WorkoutDay(
      dayLabel: map['nome'] as String,
      muscleGroup: muscleGroup,
      exercises: exercises,
    );
  }

  Future<void> _save() async {
    if (_preview == null || _preview!.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile == null) throw Exception('Perfil não encontrado.');

      final plan = WorkoutPlan(
        userId: profile.id ?? 1,
        generatedAt: DateTime.now(),
        objective: profile.objective,
        days: _preview!,
        source: 'manual',
      );

      await ref.read(workoutPlanProvider.notifier).savePlanDirectly(plan);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar treino'),
        actions: [
          if (_preview != null)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Instrução
          Card(
            color: colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 18, color: colorScheme.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cole o texto do treino do seu personal (WhatsApp, foto, anotação…) e a IA converte automaticamente.',
                      style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Texto do treino',
              style: textTheme.labelMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Ex:\nTreino A – Peito\nSupino reto 4x10\nSupino inclinado 3x12\n...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _textController.clear();
                        setState(() {
                          _preview = null;
                          _error = null;
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colorScheme.error)),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_isConverting || _textController.text.trim().isEmpty)
                  ? null
                  : _convert,
              icon: _isConverting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isConverting ? 'Convertendo...' : 'Converter com IA'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
            ),
          ),

          // Preview
          if (_preview != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_preview!.length} dia(s) encontrado(s)',
                  style: textTheme.labelLarge
                      ?.copyWith(color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _preview!.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(_preview![i].dayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${_preview![i].muscleGroup} · ${_preview![i].exercises.length} exercícios'),
                  children: _preview![i]
                      .exercises
                      .map((e) => ListTile(
                            dense: true,
                            title: Text(e.name),
                            subtitle: Text(
                                '${e.series} séries × ${e.repetitions} reps'
                                '${e.notes != null ? ' · ${e.notes}' : ''}'),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar treino'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
