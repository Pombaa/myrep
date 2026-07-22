import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider para gerenciar quais exercícios estão usando o substituto
/// Key: "dayIndex_exerciseIndex", Value: true se está usando substituto
final exerciseSelectionProvider =
    StateNotifierProvider<ExerciseSelectionController, Map<String, bool>>((ref) {
  return ExerciseSelectionController();
});

class ExerciseSelectionController extends StateNotifier<Map<String, bool>> {
  ExerciseSelectionController() : super({});

  /// Alterna entre exercício original e substituto
  void toggleExercise(int dayIndex, int exerciseIndex) {
    final key = '${dayIndex}_$exerciseIndex';
    state = {
      ...state,
      key: !(state[key] ?? false),
    };
  }

  /// Verifica se está usando o substituto
  bool isUsingSubstitute(int dayIndex, int exerciseIndex) {
    final key = '${dayIndex}_$exerciseIndex';
    return state[key] ?? false;
  }

  /// Limpa todas as seleções (volta tudo para exercício original)
  void reset() {
    state = {};
  }
}
