import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/exercise_progression_suggestion.dart';
import '../../models/workout_plan.dart';
import '../../models/workout_set.dart';
import '../../providers/exercise_selection_provider.dart';
import '../../providers/progression_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/services_providers.dart';
import '../../providers/user_providers.dart';
import '../../providers/workout_providers.dart';
import 'progression_suggestion_screen.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key, required this.day, this.plan});

  final WorkoutDay day;
  final WorkoutPlan? plan;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late final List<TextEditingController> _loadControllers;
  late final List<TextEditingController> _repsControllers;
  final _notesController = TextEditingController();
  bool _isSaving = false;

  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;
  bool _showAdjust = false;
  bool _showTips = false;
  bool _showNotes = false;

  int _restSecondsRemaining = 0;
  Timer? _restUiTimer;

  final Map<int, List<WorkoutSet>> _recordedSets = {};

  List<WorkoutExercise> get _exercises => widget.day.exercises;

  WorkoutExercise get _currentExercise => _exercises[_currentExerciseIndex];

  bool get _isCurrentDone {
    if (_exercises.isEmpty) return true;
    return (_recordedSets[_currentExerciseIndex]?.length ?? 0) >=
        _currentExercise.series;
  }

  @override
  void initState() {
    super.initState();
    _loadControllers = _exercises
        .map((e) => TextEditingController(
              text: e.suggestedLoad != null
                  ? e.suggestedLoad!.toStringAsFixed(1)
                  : '',
            ))
        .toList();
    _repsControllers = _exercises
        .map((e) => TextEditingController(text: e.repetitions.toString()))
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_exercises.isNotEmpty) {
        _initializeForegroundService();
        _prefetchLastLoads();
      }
    });
  }

  Future<void> _prefetchLastLoads() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final userId = profile?.id ?? 1;
    final repo = ref.read(exerciseHistoryRepositoryProvider);

    for (var i = 0; i < _exercises.length; i++) {
      final exercise = _exercises[i];
      // Prefer last load for the primary name; fall back to substitute name.
      final names = <String>[
        exercise.name,
        if (exercise.substituteExercise != null &&
            exercise.substituteExercise!.isNotEmpty)
          exercise.substituteExercise!,
      ];

      double? lastLoad;
      for (final name in names) {
        final entry = await repo.getLastEntryForExercise(name, userId);
        if (entry == null || entry.sets.isEmpty) continue;
        final completedWithLoad = entry.sets
            .where((s) => s.completed && s.load > 0)
            .toList();
        if (completedWithLoad.isNotEmpty) {
          lastLoad = completedWithLoad.last.load;
          break;
        }
        final anyWithLoad =
            entry.sets.where((s) => s.load > 0).toList();
        if (anyWithLoad.isNotEmpty) {
          lastLoad = anyWithLoad.last.load;
          break;
        }
      }

      if (lastLoad != null && lastLoad > 0) {
        _loadControllers[i].text = lastLoad == lastLoad.roundToDouble()
            ? lastLoad.toInt().toString()
            : lastLoad.toStringAsFixed(1);
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _initializeForegroundService() async {
    final foregroundService = ref.read(workoutForegroundServiceProvider);
    foregroundService.onCompleteSet = _completeSet;
    foregroundService.onStopRest = _stopRest;
    foregroundService.onRestComplete = _stopRest;
    foregroundService.onWorkoutCancelled = () {
      if (mounted) Navigator.of(context).pop();
    };

    final exercise = _currentExercise;
    await foregroundService.startService(
      title: 'Série 1/${exercise.series} - ${exercise.name}',
      content: 'Exercício 1/${_exercises.length}',
      isResting: false,
    );
  }

  void _stopRest() {
    _restUiTimer?.cancel();
    _restUiTimer = null;
    if (mounted) {
      setState(() {
        _isResting = false;
        _restSecondsRemaining = 0;
      });
    }
    _updateExerciseNotification();
  }

  void _skipRest() {
    _stopRest();
    // Stop native notification countdown (silent — no Flutter callback).
    ref.read(workoutForegroundServiceProvider).stopRestTimer();
  }

  void _startLocalRestCountdown(int seconds) {
    _restUiTimer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsRemaining = seconds;
    });
    _restUiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        _restUiTimer = null;
        setState(() {
          _isResting = false;
          _restSecondsRemaining = 0;
        });
        // Keep native notif in sync if UI timer wins the race.
        ref.read(workoutForegroundServiceProvider).stopRestTimer();
        _updateExerciseNotification();
      } else {
        setState(() => _restSecondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _restUiTimer?.cancel();
    ref.read(workoutForegroundServiceProvider).stopService();
    for (final c in _loadControllers) {
      c.dispose();
    }
    for (final c in _repsControllers) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  String _displayName(int index) {
    final exercise = _exercises[index];
    final isUsingSubstitute = ref
        .read(exerciseSelectionProvider.notifier)
        .isUsingSubstitute(0, index);
    final hasSubstitute = exercise.substituteExercise != null &&
        exercise.substituteExercise!.isNotEmpty;
    if (isUsingSubstitute && hasSubstitute) {
      return exercise.substituteExercise!;
    }
    return exercise.name;
  }

  int _currentReps() {
    return int.tryParse(
          _repsControllers[_currentExerciseIndex].text.trim(),
        ) ??
        _currentExercise.repetitions;
  }

  double _currentLoad() {
    return double.tryParse(
          _loadControllers[_currentExerciseIndex]
              .text
              .trim()
              .replaceAll(',', '.'),
        ) ??
        (_currentExercise.suggestedLoad ?? 0.0);
  }

  void _nudgeReps(int delta) {
    final next = (_currentReps() + delta).clamp(1, 99);
    _repsControllers[_currentExerciseIndex].text = '$next';
    setState(() {});
  }

  void _nudgeLoad(double delta) {
    final next = (_currentLoad() + delta).clamp(0.0, 999.0);
    final text = next == next.roundToDouble()
        ? next.toInt().toString()
        : next.toStringAsFixed(1);
    _loadControllers[_currentExerciseIndex].text = text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exerciseSelectionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.day.dayLabel)),
        body: const Center(child: Text('Dia de descanso — sem exercícios.')),
      );
    }

    final exercise = _currentExercise;
    final recorded = _recordedSets[_currentExerciseIndex] ?? [];
    final hasSubstitute = exercise.substituteExercise != null &&
        exercise.substituteExercise!.isNotEmpty;
    final isUsingSubstitute = ref
        .read(exerciseSelectionProvider.notifier)
        .isUsingSubstitute(0, _currentExerciseIndex);
    final tipLine = exercise.technique ?? exercise.notes;
    final hasTips = tipLine != null ||
        exercise.eccentricSeconds != null ||
        exercise.concentricSeconds != null ||
        exercise.restBetweenSetsSeconds != null ||
        (exercise.combinedExercises?.isNotEmpty ?? false) ||
        exercise.notes != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.day.dayLabel} · ${widget.day.muscleGroup}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Trocar exercício',
            onPressed: _openExerciseSwitcher,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'finish') _finishWorkout();
              if (value == 'cancel') _cancelWorkout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'finish', child: Text('Concluir treino')),
              PopupMenuItem(value: 'cancel', child: Text('Cancelar treino')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _ProgressBar(
                current: _currentExerciseIndex,
                total: _exercises.length,
                currentSet: _currentSet,
                totalSets: exercise.series,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _displayName(_currentExerciseIndex),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (hasSubstitute)
                          IconButton(
                            icon: Icon(
                              isUsingSubstitute
                                  ? Icons.swap_horiz
                                  : Icons.swap_horiz_outlined,
                              color: isUsingSubstitute
                                  ? colorScheme.primary
                                  : null,
                            ),
                            tooltip: isUsingSubstitute
                                ? 'Voltar ao original'
                                : 'Usar substituto',
                            onPressed: () {
                              ref
                                  .read(exerciseSelectionProvider.notifier)
                                  .toggleExercise(0, _currentExerciseIndex);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    if (isUsingSubstitute && hasSubstitute) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Substituto de ${exercise.name}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Série $_currentSet de ${exercise.series}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tipLine != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        tipLine,
                        maxLines: _showTips ? null : 1,
                        overflow: _showTips
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (hasTips)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () =>
                            setState(() => _showTips = !_showTips),
                        child: Text(_showTips ? 'Ocultar dicas' : 'Ver dicas'),
                      ),
                    if (_showTips && hasTips)
                      _TipsPanel(exercise: exercise),
                    if (recorded.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _RecordedSetsChips(sets: recorded),
                    ],
                    const SizedBox(height: 28),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '${_currentReps()} reps',
                            style: textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentLoad() > 0
                                ? '${_formatLoad(_currentLoad())} kg'
                                : 'sem carga',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showAdjust = !_showAdjust),
                            child: Text(
                              _showAdjust ? 'Fechar ajuste' : 'Ajustar',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_showAdjust) ...[
                      const SizedBox(height: 8),
                      _AdjustPanel(
                        onRepsDelta: _nudgeReps,
                        onLoadDelta: _nudgeLoad,
                        repsController:
                            _repsControllers[_currentExerciseIndex],
                        loadController:
                            _loadControllers[_currentExerciseIndex],
                        onChanged: () => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_showNotes)
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Observações do treino',
                          hintText: 'Opcional',
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _showNotes = true),
                          icon: const Icon(Icons.notes, size: 18),
                          label: const Text('Notas'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _BottomActionBar(
              isResting: _isResting,
              restSeconds: _restSecondsRemaining,
              isDone: _isCurrentDone,
              isSaving: _isSaving,
              currentSet: _currentSet,
              totalSets: exercise.series,
              isLastExercise:
                  _currentExerciseIndex >= _exercises.length - 1,
              onDone: _completeSet,
              onSkipRest: _skipRest,
              onSkipExercise: _skipExercise,
              onSwitch: _openExerciseSwitcher,
              onFinish: _finishWorkout,
            ),
          ],
        ),
      ),
    );
  }

  String _formatLoad(double load) {
    return load == load.roundToDouble()
        ? load.toInt().toString()
        : load.toStringAsFixed(1);
  }

  Future<void> _openExerciseSwitcher() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ExerciseSwitcherSheet(
        exercises: _exercises,
        currentIndex: _currentExerciseIndex,
        recordedSets: _recordedSets,
        displayName: _displayName,
      ),
    );
    if (selected != null && selected != _currentExerciseIndex) {
      _goToExercise(selected);
    }
  }

  void _goToExercise(int index) {
    if (index < 0 || index >= _exercises.length) return;
    _restUiTimer?.cancel();
    final recorded = _recordedSets[index] ?? [];
    final nextSet = recorded.length < _exercises[index].series
        ? recorded.length + 1
        : _exercises[index].series;
    setState(() {
      _currentExerciseIndex = index;
      _currentSet = nextSet;
      _isResting = false;
      _restSecondsRemaining = 0;
      _showAdjust = false;
      _showTips = false;
    });
    _updateExerciseNotification();
  }

  void _skipExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      _goToExercise(_currentExerciseIndex + 1);
    } else {
      _finishWorkout();
    }
  }

  void _updateExerciseNotification() {
    if (_currentExerciseIndex >= _exercises.length) return;
    final exercise = _currentExercise;
    final foregroundService = ref.read(workoutForegroundServiceProvider);
    String content =
        'Exercício ${_currentExerciseIndex + 1}/${_exercises.length}';
    if (exercise.combinedExercises != null &&
        exercise.combinedExercises!.isNotEmpty) {
      content +=
          ' • ${exercise.technique}: ${exercise.combinedExercises!.join(", ")}';
    } else if (exercise.technique != null) {
      content += ' • ${exercise.technique}';
    }
    foregroundService.updateNotification(
      title:
          'Série $_currentSet/${exercise.series} - ${_displayName(_currentExerciseIndex)}',
      content: content,
      isResting: false,
    );
  }

  void _recordCurrentSet() {
    final reps = _currentReps();
    final load = _currentLoad();

    _recordedSets.putIfAbsent(_currentExerciseIndex, () => []);
    final list = _recordedSets[_currentExerciseIndex]!;
    // Avoid duplicate if notification fired twice
    if (list.length >= _currentSet) return;

    list.add(
      WorkoutSet(
        setIndex: _currentSet - 1,
        reps: reps,
        load: load,
        completed: true,
      ),
    );
  }

  void _completeSet() {
    if (_isResting || _isCurrentDone || _isSaving) return;
    HapticFeedback.mediumImpact();
    _recordCurrentSet();
    final exercise = _currentExercise;

    if (_currentSet < exercise.series) {
      final restSeconds = exercise.restBetweenSetsSeconds ?? 60;
      setState(() => _currentSet++);
      _startLocalRestCountdown(restSeconds);
      _startRestWithNotification(restSeconds);
    } else {
      _moveToNextExercise();
    }
  }

  void _moveToNextExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      _goToExercise(_currentExerciseIndex + 1);
    } else {
      _finishWorkout();
    }
  }

  Future<void> _startRestWithNotification(int seconds) async {
    final foregroundService = ref.read(workoutForegroundServiceProvider);
    final exercise = _currentExercise;
    await foregroundService.startRestTimer(
      seconds: seconds,
      exerciseName: _displayName(_currentExerciseIndex),
      currentSet: _currentSet,
      totalSets: exercise.series,
    );
  }

  /// Only includes recorded sets; skipped / unstarted exercises get empty
  /// incomplete placeholders marked completed: false (not fabricated as done).
  Map<int, List<WorkoutSet>> _buildFinalSets(List<WorkoutExercise> exercises) {
    final result = <int, List<WorkoutSet>>{};
    for (int i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      final recorded = _recordedSets[i] ?? [];
      if (recorded.isNotEmpty) {
        result[i] = List<WorkoutSet>.from(recorded);
        // Pad remaining series as incomplete if partially done
        if (recorded.length < exercise.series) {
          final reps =
              int.tryParse(_repsControllers[i].text.trim()) ??
                  exercise.repetitions;
          final load = double.tryParse(
                _loadControllers[i].text.trim().replaceAll(',', '.'),
              ) ??
              (exercise.suggestedLoad ?? 0.0);
          for (var s = recorded.length; s < exercise.series; s++) {
            result[i]!.add(
              WorkoutSet(
                setIndex: s,
                reps: reps,
                load: load,
                completed: false,
              ),
            );
          }
        }
        continue;
      }
      final reps =
          int.tryParse(_repsControllers[i].text.trim()) ?? exercise.repetitions;
      final load = double.tryParse(
            _loadControllers[i].text.trim().replaceAll(',', '.'),
          ) ??
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
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updatedExercises = <WorkoutExercise>[];
      for (var i = 0; i < _exercises.length; i++) {
        final base = _exercises[i];
        final isUsingSubstitute = ref
            .read(exerciseSelectionProvider.notifier)
            .isUsingSubstitute(0, i);
        final reps =
            int.tryParse(_repsControllers[i].text.trim()) ?? base.repetitions;
        final load = double.tryParse(
              _loadControllers[i].text.trim().replaceAll(',', '.'),
            ) ??
            base.suggestedLoad;
        final exerciseName =
            isUsingSubstitute && base.substituteExercise != null
                ? base.substituteExercise!
                : base.name;
        updatedExercises.add(
          base.copyWith(
            name: exerciseName,
            repetitions: reps,
            suggestedLoad: load,
          ),
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

      await ref
          .read(workoutNotificationServiceProvider)
          .showWorkoutCompleteNotification();

      await ref
          .read(progressionProvider.notifier)
          .analyzeFromSavedEntries(savedEntries);

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
        const SnackBar(content: Text('Treino registrado no histórico.')),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível registrar: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancelWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar treino?'),
        content: const Text(
          'O progresso não será salvo. Deseja realmente cancelar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
}

// ─── Bottom action bar ────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isResting,
    required this.restSeconds,
    required this.isDone,
    required this.isSaving,
    required this.currentSet,
    required this.totalSets,
    required this.isLastExercise,
    required this.onDone,
    required this.onSkipRest,
    required this.onSkipExercise,
    required this.onSwitch,
    required this.onFinish,
  });

  final bool isResting;
  final int restSeconds;
  final bool isDone;
  final bool isSaving;
  final int currentSet;
  final int totalSets;
  final bool isLastExercise;
  final VoidCallback onDone;
  final VoidCallback onSkipRest;
  final VoidCallback onSkipExercise;
  final VoidCallback onSwitch;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isResting) ...[
                Text(
                  'Descanso',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatTime(restSeconds),
                  style: textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: onSkipRest,
                    child: const Text('Pular descanso'),
                  ),
                ),
              ] else if (isDone) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: isSaving
                        ? null
                        : (isLastExercise ? onFinish : onSkipExercise),
                    icon: Icon(
                      isLastExercise ? Icons.check_circle : Icons.skip_next,
                    ),
                    label: Text(
                      isSaving
                          ? 'Salvando...'
                          : (isLastExercise
                              ? 'Concluir treino'
                              : 'Próximo exercício'),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: isSaving ? null : onDone,
                    style: FilledButton.styleFrom(
                      textStyle: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text('Feito · Série $currentSet/$totalSets'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onSwitch,
                      child: const Text('Trocar'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: isLastExercise ? onFinish : onSkipExercise,
                      child: Text(
                        isLastExercise ? 'Finalizar' : 'Pular exercício',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }
}

// ─── Exercise switcher sheet ──────────────────────────────────────────────────

class _ExerciseSwitcherSheet extends StatelessWidget {
  const _ExerciseSwitcherSheet({
    required this.exercises,
    required this.currentIndex,
    required this.recordedSets,
    required this.displayName,
  });

  final List<WorkoutExercise> exercises;
  final int currentIndex;
  final Map<int, List<WorkoutSet>> recordedSets;
  final String Function(int index) displayName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Exercícios',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final exercise = exercises[index];
                  final doneCount = recordedSets[index]?.length ?? 0;
                  final isComplete = doneCount >= exercise.series;
                  final isCurrent = index == currentIndex;

                  return ListTile(
                    selected: isCurrent,
                    selectedTileColor:
                        colorScheme.primaryContainer.withValues(alpha: 0.35),
                    leading: CircleAvatar(
                      backgroundColor: isComplete
                          ? colorScheme.secondaryContainer
                          : (isCurrent
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest),
                      foregroundColor: isComplete
                          ? colorScheme.onSecondaryContainer
                          : (isCurrent
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface),
                      child: isComplete
                          ? const Icon(Icons.check, size: 18)
                          : Text('${index + 1}'),
                    ),
                    title: Text(
                      displayName(index),
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text('$doneCount/${exercise.series} séries'),
                    trailing: isCurrent
                        ? Icon(Icons.play_arrow, color: colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Adjust panel ─────────────────────────────────────────────────────────────

class _AdjustPanel extends StatelessWidget {
  const _AdjustPanel({
    required this.onRepsDelta,
    required this.onLoadDelta,
    required this.repsController,
    required this.loadController,
    required this.onChanged,
  });

  final void Function(int delta) onRepsDelta;
  final void Function(double delta) onLoadDelta;
  final TextEditingController repsController;
  final TextEditingController loadController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Reps')),
                IconButton(
                  onPressed: () => onRepsDelta(-1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 56,
                  child: TextField(
                    controller: repsController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  onPressed: () => onRepsDelta(1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Carga (kg)')),
                IconButton(
                  onPressed: () => onLoadDelta(-2.5),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: loadController,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  onPressed: () => onLoadDelta(2.5),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tips ─────────────────────────────────────────────────────────────────────

class _TipsPanel extends StatelessWidget {
  const _TipsPanel({required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exercise.technique != null)
            _TipLine(label: 'Técnica', value: exercise.technique!),
          if (exercise.notes != null)
            _TipLine(label: 'Obs', value: exercise.notes!),
          if (exercise.eccentricSeconds != null ||
              exercise.concentricSeconds != null)
            _TipLine(
              label: 'Cadência',
              value:
                  '${exercise.eccentricSeconds ?? 2}s ↓ / ${exercise.concentricSeconds ?? 1}s ↑',
            ),
          if (exercise.restBetweenSetsSeconds != null)
            _TipLine(
              label: 'Descanso',
              value: '${exercise.restBetweenSetsSeconds}s',
            ),
          if (exercise.combinedExercises != null &&
              exercise.combinedExercises!.isNotEmpty)
            _TipLine(
              label: 'Sequência',
              value: exercise.combinedExercises!.join(' → '),
            ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

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
    final progress =
        total > 0 ? (current + (currentSet / totalSets)) / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ex ${current + 1}/$total · Série $currentSet/$totalSets',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sets.map((s) {
        final loadStr =
            s.load > 0 ? ' · ${s.load.toStringAsFixed(s.load == s.load.roundToDouble() ? 0 : 1)}kg' : '';
        return Chip(
          avatar: Icon(Icons.check, size: 14, color: colorScheme.onSecondaryContainer),
          label: Text('S${s.setIndex + 1}: ${s.reps}$loadStr'),
          backgroundColor: colorScheme.secondaryContainer,
          labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}
