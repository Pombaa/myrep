import '../../data/exercise_library.dart';
import '../../models/workout_plan.dart';

const _rank = [
  'Peito',
  'Ombro',
  'Tríceps',
  'Costas',
  'Bíceps',
  'Pernas',
  'Glúteo',
  'Panturrilha',
  'Abdômen',
  'Cardio',
  'Funcional',
];

const _keywords = <(String, String)>[
  ('invertid', 'Ombro'),
  ('posterior', 'Ombro'),
  ('triceps', 'Tríceps'),
  ('biceps', 'Bíceps'),
  ('panturrilha', 'Panturrilha'),
  ('gemeo', 'Panturrilha'),
  ('desenvolvimento', 'Ombro'),
  ('elevac', 'Ombro'),
  ('deltoide', 'Ombro'),
  ('crucifixo', 'Peito'),
  ('supino', 'Peito'),
  ('peitoral', 'Peito'),
  ('puxad', 'Costas'),
  ('remada', 'Costas'),
  ('dorsal', 'Costas'),
  ('barra fixa', 'Costas'),
  ('encolhimento', 'Costas'),
  ('trapezio', 'Costas'),
  ('agachamento', 'Pernas'),
  ('leg press', 'Pernas'),
  ('extensora', 'Pernas'),
  ('flexora', 'Pernas'),
  ('stiff', 'Pernas'),
  ('abdutora', 'Pernas'),
  ('adutora', 'Pernas'),
  ('avanco', 'Pernas'),
  ('gluteo', 'Glúteo'),
  ('abdominal', 'Abdômen'),
  ('prancha', 'Abdômen'),
];

String foldPt(String input) {
  const fold = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ï': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(fold[char] ?? char);
  }
  return buffer.toString();
}

/// Best-effort muscle for a free-text exercise name.
///
/// Library names match by token containment (so "Supino Reto na Máquina"
/// hits "Supino Reto"). Keywords cover names the library does not list.
String? muscleForExerciseName(String exerciseName) {
  final folded = foldPt(exerciseName);
  if (folded.contains('invertid') || folded.contains('posterior')) {
    return 'Ombro';
  }

  String? bestMuscle;
  var bestScore = 0;
  for (final entry in kExerciseLibrary) {
    final tokens = foldPt(entry['name']!)
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length > 2)
        .toList();
    if (tokens.isEmpty || !tokens.every(folded.contains)) continue;
    final score = tokens.fold<int>(0, (sum, token) => sum + token.length);
    if (score > bestScore) {
      bestScore = score;
      bestMuscle = entry['muscle'];
    }
  }
  if (bestMuscle != null) return bestMuscle;

  for (final (needle, muscle) in _keywords) {
    if (folded.contains(needle)) return muscle;
  }
  return null;
}

/// Label for a day, built from every exercise. Falls back to the stored
/// group when nothing can be inferred.
String muscleSummaryForDay(WorkoutDay day) {
  final found = <String>{};
  for (final exercise in day.exercises) {
    final muscle = muscleForExerciseName(exercise.name);
    if (muscle != null) found.add(muscle);
  }
  if (found.isEmpty) {
    final stored = day.muscleGroup.trim();
    return stored.isEmpty ? 'Misto' : stored;
  }

  final ordered = [...found]..sort((a, b) {
      final ai = _rank.indexOf(a);
      final bi = _rank.indexOf(b);
      return (ai < 0 ? _rank.length : ai).compareTo(bi < 0 ? _rank.length : bi);
    });
  final visible = ordered.take(4).toList();
  if (visible.length == 1) return visible.first;
  if (visible.length == 2) return '${visible[0]} e ${visible[1]}';
  return '${visible.sublist(0, visible.length - 1).join(', ')} e ${visible.last}';
}
