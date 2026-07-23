import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/workout_prompt_builder.dart';
import '../data/exercise_library.dart';
import '../models/ai_interaction.dart';
import '../models/exercise_progression_suggestion.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../models/workout_set.dart';
import '../services/openai_service.dart';
import '../services/progression_analyzer.dart';
import '../repositories/workout_repository.dart';
import 'measurement_providers.dart';
import 'progress_providers.dart';
import 'repository_providers.dart';
import 'services_providers.dart';
import 'settings_providers.dart';
import 'user_providers.dart';

final workoutPlanProvider = StateNotifierProvider<WorkoutPlanController, AsyncValue<WorkoutPlan?>>((ref) {
  return WorkoutPlanController(ref);
});

class WorkoutPlanController extends StateNotifier<AsyncValue<WorkoutPlan?>> {
  WorkoutPlanController(this._ref) : super(const AsyncValue.loading()) {
    _loadLatest();
  }

  final Ref _ref;

  WorkoutRepository get _repository => _ref.read(workoutRepositoryProvider);

  Future<void> _loadLatest() async {
    try {
      final plan = await _repository.latestPlan();
      state = AsyncValue.data(plan);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async => _loadLatest();

  Future<void> savePlanDirectly(WorkoutPlan plan) async {
    state = const AsyncValue.loading();
    try {
      final saved = await _repository.savePlan(plan);
      state = AsyncValue.data(saved);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deletePlan() async {
    try {
      await _repository.deleteAllPlans();
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> generateNewPlan({
    String? customRequest,
    int? desiredDays,
    int? sessionDurationMinutes,
  }) async {
    final previousPlan = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final profile = _ref.read(userProfileProvider).valueOrNull;
      final latestMeasurement = _ref.read(latestMeasurementProvider);
      if (profile == null) {
        throw Exception('Cadastre seu perfil para gerar um treino.');
      }
      if (latestMeasurement == null) {
        throw Exception('Registre uma avaliação corporal antes de gerar o treino.');
      }

      final aiProvider = _ref.read(selectedAiProviderProvider);
      final apiKeyState = aiProvider == AiProvider.nvidia
          ? _ref.read(nvidiaKeyProvider)
          : _ref.read(openAiKeyProvider);
      final apiKey = apiKeyState.when(
        data: (value) => value,
        loading: () => null,
        error: (_, __) => null,
      );
      if (apiKey == null || apiKey.isEmpty) {
        final name = aiProvider == AiProvider.nvidia ? 'NVIDIA' : 'OpenAI';
        throw Exception('Informe a chave da API $name nas configurações.');
      }

      final previousMeasurement = _ref.read(previousMeasurementProvider);
      final lastPlan = previousPlan;
      final lastSession = await _repository.lastSession();
      final progressSummary = await _ref.read(progressSummaryProvider.future);

      final resolvedDays = desiredDays ?? previousPlan?.desiredDays ?? 5;
      final resolvedDuration = sessionDurationMinutes ?? previousPlan?.sessionDurationMinutes ?? 60;

      final historyRepo = _ref.read(exerciseHistoryRepositoryProvider);
      final progressionHistory =
          await historyRepo.getProgressionSummary(profile.id ?? 1, limit: 4);

      const promptBuilder = WorkoutPromptBuilder();
      final prompt = promptBuilder.build(
        profile: profile,
        latestMeasurement: latestMeasurement,
        previousMeasurement: previousMeasurement,
        lastPlan: lastPlan,
        lastSession: lastSession,
        progressSummary: progressSummary,
        customRequest: customRequest,
        desiredDays: resolvedDays,
        progressionHistory: progressionHistory,
        sessionDurationMinutes: resolvedDuration,
      );

      final openAi = _ref.read(openAiServiceProvider);
      final messages = [
        {
          'role': 'system',
          'content': 'Você cria treinos estruturados sempre em JSON válido.'
        },
        {'role': 'user', 'content': prompt},
      ];
      final result = await openAi.generateWorkoutPlan(
        apiKey: apiKey!,
        messages: messages,
        baseUrl: aiProvider.baseUrl,
        model: aiProvider.defaultModel,
        useStructuredOutput: aiProvider.useStructuredOutput,
        providerLabel: aiProvider.label,
      );
      final parsed = jsonDecode(result);
      List<dynamic> daysRaw;
      if (parsed is Map<String, dynamic>) {
        final raw = parsed['treino'];
        if (raw is List) {
          daysRaw = raw;
        } else {
          throw const OpenAiException('Resposta sem campo "treino".');
        }
      } else if (parsed is List) {
        daysRaw = parsed;
      } else {
        throw const OpenAiException('Formato de resposta inválido.');
      }

      final days = daysRaw
          .map((dynamic item) => WorkoutDay.fromJson((item as Map).cast<String, Object?>()))
          .toList();

      final metadata = <String, dynamic>{};
      if (customRequest != null && customRequest.isNotEmpty) {
        metadata['custom_request'] = customRequest;
      }

      final plan = WorkoutPlan(
        userId: profile.id ?? 1,
        generatedAt: DateTime.now(),
        objective: profile.objective,
        focus: customRequest,
        days: days,
        metadata: metadata.isEmpty ? null : metadata,
        desiredDays: resolvedDays,
        sessionDurationMinutes: resolvedDuration,
      );

      final saved = await _repository.savePlan(plan);
      final aiRepository = _ref.read(aiRepositoryProvider);
      await aiRepository.saveInteraction(
        AiInteraction(
          createdAt: DateTime.now(),
          prompt: prompt,
          response: result,
          metadata: jsonEncode({'type': 'workout_plan'}),
        ),
      );
      state = AsyncValue.data(saved);
      _ref.invalidate(progressSummaryProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final workoutHistoryProvider = FutureProvider<List<WorkoutPlan>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return repository.fetchPlans(limit: 10);
});

final workoutLoggerProvider = Provider<WorkoutLogger>((ref) {
  return WorkoutLogger(ref);
});

class WorkoutLogger {
  WorkoutLogger(this._ref);

  final Ref _ref;

  Future<List<ExerciseHistoryEntry>> logSession({
    required WorkoutDay day,
    WorkoutPlan? plan,
    String? notes,
    Map<int, List<WorkoutSet>>? exerciseSets,
    int? userId,
  }) async {
    final repository = _ref.read(workoutRepositoryProvider);
    final executedAt = DateTime.now();
    final session = WorkoutSession(
      planId: plan?.id,
      executedAt: executedAt,
      dayLabel: day.dayLabel,
      exercises: day.exercises,
      notes: notes,
    );
    await repository.logSession(session);

    final savedEntries = <ExerciseHistoryEntry>[];
    if (exerciseSets != null && userId != null) {
      savedEntries.addAll(
        await _saveExerciseHistory(
          day: day,
          exerciseSets: exerciseSets,
          userId: userId,
          sessionDate: executedAt,
        ),
      );
    }

    _ref.invalidate(progressSummaryProvider);
    _ref.invalidate(workoutSessionsProvider);
    return savedEntries;
  }

  Future<List<ExerciseHistoryEntry>> _saveExerciseHistory({
    required WorkoutDay day,
    required Map<int, List<WorkoutSet>> exerciseSets,
    required int userId,
    required DateTime sessionDate,
  }) async {
    const analyzer = ProgressionAnalyzer();
    final historyRepo = _ref.read(exerciseHistoryRepositoryProvider);
    final saved = <ExerciseHistoryEntry>[];

    for (int i = 0; i < day.exercises.length; i++) {
      final exercise = day.exercises[i];
      final sets = exerciseSets[i];
      if (sets == null || sets.isEmpty) continue;

      final muscleGroup = muscleGroupForExercise(exercise.name) ?? day.muscleGroup;
      final scheme = analyzer.detectRepScheme(sets);

      final entry = ExerciseHistoryEntry(
        userId: userId,
        sessionDate: sessionDate,
        exerciseName: exercise.name,
        muscleGroup: muscleGroup,
        sets: sets,
        repScheme: scheme,
      );
      saved.add(await historyRepo.save(entry));
    }
    return saved;
  }
}
