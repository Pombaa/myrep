import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/exercise_progression_suggestion.dart';
import '../services/progression_analyzer.dart';
import 'repository_providers.dart';

final progressionProvider =
    AsyncNotifierProvider<ProgressionNotifier, List<ExerciseProgressionSuggestion>>(
  ProgressionNotifier.new,
);

class ProgressionNotifier
    extends AsyncNotifier<List<ExerciseProgressionSuggestion>> {
  @override
  Future<List<ExerciseProgressionSuggestion>> build() async => [];

  /// [savedEntries] are already persisted; this method only reads previous
  /// history and builds suggestions — no double-write.
  Future<void> analyzeFromSavedEntries(
    List<ExerciseHistoryEntry> savedEntries,
  ) async {
    if (savedEntries.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final historyRepo = ref.read(exerciseHistoryRepositoryProvider);
      const analyzer = ProgressionAnalyzer();
      final suggestions = <ExerciseProgressionSuggestion>[];

      for (final entry in savedEntries) {
        final previous = await historyRepo.getLastEntryBeforeSession(
          entry.exerciseName,
          entry.userId,
          entry.sessionDate,
        );

        final suggestion = analyzer.analyzeExercise(
          current: entry,
          previous: previous,
        );
        if (suggestion != null) {
          suggestions.add(suggestion);
        }
      }

      state = AsyncValue.data(suggestions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveDecision({
    required ExerciseHistoryEntry entry,
    required ProgressionOption selectedOption,
  }) async {
    if (entry.id == null) return;
    final historyRepo = ref.read(exerciseHistoryRepositoryProvider);
    await historyRepo.updateProgressionDecision(entry.id!, selectedOption.label);
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final progressionAnalyzerProvider = Provider<ProgressionAnalyzer>((ref) {
  return const ProgressionAnalyzer();
});

final progressionHistoryProvider =
    FutureProvider.family<Map<String, List<ExerciseHistoryEntry>>, int>(
  (ref, userId) async {
    final repo = ref.watch(exerciseHistoryRepositoryProvider);
    return repo.getProgressionSummary(userId, limit: 4);
  },
);
