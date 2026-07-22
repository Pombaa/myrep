import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise_progression_suggestion.dart';
import '../../models/workout_plan.dart';
import '../../models/workout_set.dart';
import '../../providers/exercise_selection_provider.dart';
import '../../providers/progression_provider.dart';
import '../../providers/services_providers.dart';
import '../../providers/user_providers.dart';
import '../../providers/workout_providers.dart';
import 'progression_suggestion_screen.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key, required this.day, this.plan});

  final WorkoutDay day;
  final WorkoutPlan? plan;

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late final List<TextEditingController> _loadControllers;
  late final List<TextEditingController> _repsControllers;
  final _notesController = TextEditingController();
  bool _isSaving = false;

  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;

  // exerciseIndex → list of WorkoutSet recorded (one per series completed)
  final Map<int, List<WorkoutSet>> _recordedSets = {};

  @override
  void initState() {
    super.initState();
    _loadControllers = widget.day.exercises
        .map((e) => TextEditingController(
              text: e.suggestedLoad != null ? e.suggestedLoad!.toStringAsFixed(1) : '',
            ))
        .toList();
    _repsControllers = widget.day.exercises
        .map((e) => TextEditingController(text: e.repetitions.toString()))
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForegroundService();
    });
  }

  Future<void> _initializeForegroundService() async {
    final foregroundService = ref.read(workoutForegroundServiceProvider);
    foregroundService.onCompleteSet = _completeSet;
    foregroundService.onStopRest = () {
      if (mounted) setState(() => _isResting = false);
      _updateExerciseNotification();
    };
    foregroundService.onRestComplete = () {
      if (mounted) setState(() => _isResting = false);
      _updateExerciseNotification();
    };
    foregroundService.onWorkoutCancelled = () {
      if (mounted) Navigator.of(context).pop();
    };

    final exercise = widget.day.exercises[_currentExerciseIndex];
    await foregroundService.startService(
      title: 'Série 1/${exercise.series} - ${exercise.name}',
      content: 'Exercício 1/${widget.day.exercises.length}',
      isResting: false,
    );
  }

  @override
  void dispose() {
    ref.read(workoutForegroundServiceProvider).stopService();
    for (final c in _loadControllers) c.dispose();
    for (final c in _repsControllers) c.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exerciseSelection = ref.watch(exerciseSelectionProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.day.dayLabel} • ${widget.day.muscleGroup}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProgressBar(
              current: _currentExerciseIndex,
              total: widget.day.exercises.length,
              currentSet: _currentSet,
              totalSets: widget.day.exercises.isNotEmpty
                  ? widget.day.exercises[_currentExerciseIndex].series
                  : 1,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < widget.day.exercises.length; i++)
              _buildExerciseCard(context, i, exerciseSelection),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações do treino',
                hintText: 'Como você se sentiu, ajustes realizados, etc.',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle),
              label: Text(_isSaving ? 'Registrando...' : 'Concluir treino'),
              onPressed: _isSaving ? null : _finishWorkout,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Cancelar treino'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _isSaving ? null : _cancelWorkout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, int index, Map<String, bool> exerciseSelection) {
    final exercise = widget.day.exercises[index];
    final isUsingSubstitute =
        ref.read(exerciseSelectionProvider.notifier).isUsingSubstitute(0, index);
    final hasSubstitute =
        exercise.substituteExercise != null && exercise.substituteExercise!.isNotEmpty;
    final displayName =
        isUsingSubstitute && hasSubstitute ? exercise.substituteExercise! : exercise.name;
    final isDone = _recordedSets[index]?.length == exercise.series;
    final isActive = index == _currentExerciseIndex;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isDone
          ? colorScheme.secondaryContainer.withOpacity(0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isDone)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.check_circle,
                                  size: 16, color: colorScheme.secondary),
                            ),
                          Expanded(
                            child: Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${exercise.series} séries'),
                      if (exercise.combinedExercises != null &&
                          exercise.combinedExercises!.isNotEmpty)
                        _CombinedExercisesTag(exercises: exercise.combinedExercises!),
                    ],
                  ),
                ),
                if (hasSubstitute)
                  IconButton(
                    icon: Icon(
                      isUsingSubstitute ? Icons.swap_horiz : Icons.swap_horiz_outlined,
                      color: isUsingSubstitute ? colorScheme.primary : null,
                    ),
                    tooltip: isUsingSubstitute ? 'Voltar ao original' : 'Exercício substituto',
                    onPressed: () =>
                        ref.read(exerciseSelectionProvider.notifier).toggleExercise(0, index),
                  ),
              ],
            ),
            if (hasSubstitute && isUsingSubstitute)
              _SubstituteTag(originalName: exercise.name),
            if (exercise.technique != null ||
                exercise.eccentricSeconds != null ||
                exercise.concentricSeconds != null ||
                exercise.restBetweenSetsSeconds != null)
              _ExecutionNotesBox(exercise: exercise),

            // Séries registradas
            if (_recordedSets[index] != null && _recordedSets[index]!.isNotEmpty)
              _RecordedSetsChips(sets: _recordedSets[index]!),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _repsControllers[index],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Repetições'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _loadControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Carga (kg)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isActive && !_isResting && !isDone)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text('Concluir série $_currentSet/${exercise.series}'),
                      onPressed: _completeSet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.timer_outlined),
                    label: Text('${exercise.restBetweenSetsSeconds ?? 60}s'),
                    onPressed: () => _startRestTimer(
                      Duration(seconds: exercise.restBetweenSetsSeconds ?? 60),
                    ),
                  ),
                ],
              ),
            if (isActive && _isResting)
              _RestingIndicator(
                onStop: () => setState(() => _isResting = false),
              ),
            if (!isActive && !isDone)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.timer_outlined),
                  label: Text('Descanso ${exercise.restBetweenSetsSeconds ?? 60}s'),
                  onPressed: () => _startRestTimer(
                    Duration(seconds: exercise.restBetweenSetsSeconds ?? 60),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _updateExerciseNotification() {
    if (_currentExerciseIndex >= widget.day.exercises.length) return;
    final exercise = widget.day.exercises[_currentExerciseIndex];
    final foregroundService = ref.read(workoutForegroundServiceProvider);
    String content = 'Exercício ${_currentExerciseIndex + 1}/${widget.day.exercises.length}';
    if (exercise.combinedExercises != null && exercise.combinedExercises!.isNotEmpty) {
      content += ' • ${exercise.technique}: ${exercise.combinedExercises!.join(", ")}';
    } else if (exercise.technique != null) {
      content += ' • ${exercise.technique}';
    }
    foregroundService.updateNotification(
      title: 'Série $_currentSet/${exercise.series} - ${exercise.name}',
      content: content,
      isResting: false,
    );
  }

  void _recordCurrentSet() {
    final exercise = widget.day.exercises[_currentExerciseIndex];
    final reps = int.tryParse(_repsControllers[_currentExerciseIndex].text.trim()) ??
        exercise.repetitions;
    final load =
        double.tryParse(_loadControllers[_currentExerciseIndex].text.trim().replaceAll(',', '.')) ??
            (exercise.suggestedLoad ?? 0.0);

    _recordedSets.putIfAbsent(_currentExerciseIndex, () => []);
    _recordedSets[_currentExerciseIndex]!.add(
      WorkoutSet(
        setIndex: _currentSet - 1,
        reps: reps,
        load: load,
        completed: true,
      ),
    );
  }

  void _completeSet() {
    _recordCurrentSet();
    final exercise = widget.day.exercises[_currentExerciseIndex];

    if (_currentSet < exercise.series) {
      setState(() {
        _currentSet++;
        _isResting = true;
      });
      _startRestWithNotification(exercise.restBetweenSetsSeconds ?? 60);
    } else {
      _moveToNextExercise();
    }
  }

  void _moveToNextExercise() {
    if (_currentExerciseIndex < widget.day.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSet = 1;
        _isResting = false;
      });
      _updateExerciseNotification();
    } else {
      _finishWorkout();
    }
  }

  Future<void> _startRestWithNotification(int seconds) async {
    final foregroundService = ref.read(workoutForegroundServiceProvider);
    final exercise = widget.day.exercises[_currentExerciseIndex];
    await foregroundService.startRestTimer(
      seconds: seconds,
      exerciseName: exercise.name,
      currentSet: _currentSet,
      totalSets: exercise.series,
    );
  }

  Map<int, List<WorkoutSet>> _buildFinalSets(List<WorkoutExercise> exercises) {
    final result = <int, List<WorkoutSet>>{};
    for (int i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      final recorded = _recordedSets[i] ?? [];
      if (recorded.isNotEmpty) {
        result[i] = recorded;
        continue;
      }
      // Exercício não iniciado: usa valores dos campos como fallback
      final reps =
          int.tryParse(_repsControllers[i].text.trim()) ?? exercise.repetitions;
      final load = double.tryParse(
              _loadControllers[i].text.trim().replaceAll(',', '.')) ??
          (exercise.suggestedLoad ?? 0.0);
      result[i] = List.generate(
        exercise.series,
        (s) => WorkoutSet(
          setIndex: s,
          reps: reps,
          load: load,
          completed: false,
        ),
      );
    }
    return result;
  }

  Future<void> _finishWorkout() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updatedExercises = <WorkoutExercise>[];
      for (var i = 0; i < widget.day.exercises.length; i++) {
        final base = widget.day.exercises[i];
        final isUsingSubstitute =
            ref.read(exerciseSelectionProvider.notifier).isUsingSubstitute(0, i);
        final reps =
            int.tryParse(_repsControllers[i].text.trim()) ?? base.repetitions;
        final load = double.tryParse(
                _loadControllers[i].text.trim().replaceAll(',', '.')) ??
            base.suggestedLoad;
        final exerciseName =
            isUsingSubstitute && base.substituteExercise != null
                ? base.substituteExercise!
                : base.name;
        updatedExercises.add(
          base.copyWith(name: exerciseName, repetitions: reps, suggestedLoad: load),
        );
      }

      final updatedDay = WorkoutDay(
        dayLabel: widget.day.dayLabel,
        muscleGroup: widget.day.muscleGroup,
        focus: widget.day.focus,
        exercises: updatedExercises,
      );

      final profile = ref.read(userProfileProvider).valueOrNull;
      final userId = profile?.id ?? 1;
      final finalSets = _buildFinalSets(updatedExercises);

      final savedEntries = await ref.read(workoutLoggerProvider).logSession(
            day: updatedDay,
            plan: widget.plan,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            exerciseSets: finalSets,
            userId: userId,
          );

      await ref.read(workoutNotificationServiceProvider).showWorkoutCompleteNotification();

      // Análise de progressão baseada nas entradas recém-salvas
      await ref.read(progressionProvider.notifier).analyzeFromSavedEntries(savedEntries);

      final suggestions = ref.read(progressionProvider).valueOrNull ?? [];

      if (suggestions.isNotEmpty && mounted) {
        final decisions = await Navigator.of(context)
            .push<Map<String, ProgressionOption?>>(
          MaterialPageRoute(
            builder: (_) =>
                ProgressionSuggestionScreen(suggestions: suggestions),
          ),
        );
        if (decisions != null && mounted) {
          for (final entry in savedEntries) {
            final decision = decisions[entry.exerciseName];
            if (decision != null) {
              await ref.read(progressionProvider.notifier).saveDecision(
                    entry: entry,
                    selectedOption: decision,
                  );
            }
          }
        }
      }

      messenger.showSnackBar(
          const SnackBar(content: Text('Treino registrado no histórico.')));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(
          SnackBar(content: Text('Não foi possível registrar: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancelWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar treino?'),
        content: const Text('O progresso não será salvo. Deseja realmente cancelar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(workoutForegroundServiceProvider).stopService();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _startRestTimer(Duration duration) async {
    int secondsRemaining = duration.inSeconds;
    Timer? timer;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (secondsRemaining <= 1) {
                t.cancel();
                Navigator.of(context).pop();
              } else {
                secondsRemaining--;
                setStateDialog(() {});
              }
            });
            return AlertDialog(
              title: const Text('Tempo de descanso'),
              content: Text('$secondsRemaining segundos restantes'),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Encerrar'),
                ),
              ],
            );
          },
        );
      },
    );
    timer?.cancel();
  }
}

// ─── Widgets auxiliares ────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.current,
    required this.total,
    required this.currentSet,
    required this.totalSets,
  });

  final int current;
  final int total;
  final int currentSet;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = total > 0 ? (current + (currentSet / totalSets)) / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Exercício ${current + 1}/$total · Série $currentSet/$totalSets',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colorScheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}

class _RecordedSetsChips extends StatelessWidget {
  const _RecordedSetsChips({required this.sets});

  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 6,
        children: sets.map((s) {
          final loadStr = s.load > 0 ? '/${s.load.toStringAsFixed(1)}kg' : '';
          return Chip(
            label: Text('S${s.setIndex + 1}: ${s.reps}rep$loadStr'),
            backgroundColor: colorScheme.secondaryContainer,
            labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }
}

class _RestingIndicator extends StatelessWidget {
  const _RestingIndicator({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Descansando...',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: onStop,
            child: const Text('Pular'),
          ),
        ],
      ),
    );
  }
}

class _SubstituteTag extends StatelessWidget {
  const _SubstituteTag({required this.originalName});

  final String originalName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Substituto de: $originalName',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
        ),
      ),
    );
  }
}

class _CombinedExercisesTag extends StatelessWidget {
  const _CombinedExercisesTag({required this.exercises});

  final List<String> exercises;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.double_arrow,
                    size: 14, color: colorScheme.onTertiaryContainer),
                const SizedBox(width: 4),
                Text(
                  'Em sequência:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            for (final ex in exercises)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Text(
                  '→ $ex',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionNotesBox extends StatelessWidget {
  const _ExecutionNotesBox({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: colorScheme.onSecondaryContainer),
              const SizedBox(width: 6),
              Text(
                'Observações de Execução',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (exercise.technique != null) ...[
            _ObsRow(
                icon: Icons.fitness_center,
                label: 'Técnica',
                value: exercise.technique!),
            const SizedBox(height: 6),
          ],
          if (exercise.eccentricSeconds != null ||
              exercise.concentricSeconds != null) ...[
            _ObsRow(
              icon: Icons.speed,
              label: 'Cadência',
              value:
                  '${exercise.concentricSeconds ?? 1}s (concêntrica) / ${exercise.eccentricSeconds ?? 2}s (excêntrica)',
            ),
            const SizedBox(height: 6),
          ],
          if (exercise.restBetweenSetsSeconds != null)
            _ObsRow(
              icon: Icons.timer,
              label: 'Descanso',
              value: '${exercise.restBetweenSetsSeconds}s entre séries',
            ),
        ],
      ),
    );
  }
}

class _ObsRow extends StatelessWidget {
  const _ObsRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 14, color: colorScheme.onSecondaryContainer.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
