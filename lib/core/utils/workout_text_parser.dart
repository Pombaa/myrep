import '../../models/workout_plan.dart';
import 'muscle_summary.dart';

/// Parses free-form Portuguese workout plans (markdown / WhatsApp / lists)
/// into [WorkoutDay]s without calling an LLM.
///
/// Handles patterns like:
/// `#### Segunda-feira: Push A (Peito…)`
/// `1. **Supino Reto:** 3 séries de 6 a 8 repetições (RIR 2) | *2 min*`
List<WorkoutDay>? tryParseWorkoutText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final lines = trimmed.split('\n');
  final days = <_DayDraft>[];
  _DayDraft? current;
  var sawExercise = false;

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty || line == '---') continue;

    final dayHeader = _matchDayHeader(line);
    if (dayHeader != null) {
      current = _DayDraft(
        label: dayHeader.label,
        focusHint: dayHeader.focusHint,
      );
      days.add(current);
      continue;
    }

    if (current == null) continue;
    if (_isNonWorkoutSection(line)) {
      current = null;
      continue;
    }

    final exercise = _matchExerciseLine(line);
    if (exercise != null) {
      current.exercises.add(exercise);
      sawExercise = true;
    }
  }

  if (!sawExercise || days.isEmpty) return null;

  final result = days
      .where((d) => d.exercises.isNotEmpty || !_looksLikeRestDay(d.label))
      .where((d) => d.exercises.isNotEmpty)
      .map((d) {
        final draft = WorkoutDay(
          dayLabel: d.label,
          muscleGroup: 'Misto',
          exercises: d.exercises,
        );
        final inferred = d.exercises.isEmpty
            ? (_muscleFromHint(d.focusHint) ?? 'Misto')
            : muscleSummaryForDay(draft);
        return WorkoutDay(
          dayLabel: d.label,
          muscleGroup: inferred == 'Misto'
              ? (_muscleFromHint(d.focusHint) ?? inferred)
              : inferred,
          exercises: d.exercises,
        );
      })
      .toList();

  return result.isEmpty ? null : result;
}

class _DayDraft {
  _DayDraft({required this.label, this.focusHint});
  final String label;
  final String? focusHint;
  final List<WorkoutExercise> exercises = [];
}

class _DayHeader {
  const _DayHeader({required this.label, this.focusHint});
  final String label;
  final String? focusHint;
}

bool _looksLikeRestDay(String label) {
  final lower = label.toLowerCase();
  return lower.contains('descanso') || lower.contains('rest');
}

bool _isNonWorkoutSection(String line) {
  final lower = line.toLowerCase();
  if (RegExp(r'^#{1,3}\s+\d+\s+regras').hasMatch(lower)) return true;
  if (lower.startsWith('### ') &&
      !lower.contains('treino') &&
      !lower.contains('plano')) {
    return true;
  }
  return false;
}

_DayHeader? _matchDayHeader(String line) {
  // #### Segunda-feira: Push A (Peitoral…)
  // ### Terça — Pull A
  // Dia 1 → Peito
  // Treino A – Peito e Ombro
  final md = RegExp(
    r'^#{2,4}\s+(.+)$',
  ).firstMatch(line);
  if (md != null) {
    final body = md.group(1)!.trim();
    final lower = body.toLowerCase();
    if (lower.startsWith('o teu plano') ||
        lower.startsWith('plano de treino') ||
        RegExp(r'^\d+\s+regras').hasMatch(lower)) {
      return null;
    }

    final paren = RegExp(r'^(.*?)\s*\((.+)\)\s*$').firstMatch(body);
    final label = (paren?.group(1) ?? body).trim();
    final focus = paren?.group(2)?.trim();
    if (_looksLikeRestDay(label) && (focus == null || focus.isEmpty)) {
      return _DayHeader(label: label, focusHint: focus);
    }
    // Prefer weekday / Push|Pull|Legs / Treino X style headers
    if (_looksLikeDayLabel(label)) {
      return _DayHeader(label: label, focusHint: focus);
    }
    return null;
  }

  final arrow = RegExp(
    r'^(?:dia\s*\d+\s*[→\-:–]|treino\s*[a-z0-9]+)\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (arrow != null) {
    return _DayHeader(label: line.trim());
  }

  final weekday = RegExp(
    r'^(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)'
    r'(?:-feira)?\s*[:\-–]\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (weekday != null) {
    return _DayHeader(label: line.trim());
  }

  return null;
}

bool _looksLikeDayLabel(String label) {
  final lower = label.toLowerCase();
  if (RegExp(
    r'^(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo)',
  ).hasMatch(lower)) {
    return true;
  }
  if (RegExp(r'\b(push|pull|legs|treino\s*[a-z0-9]|dia\s*\d+)\b')
      .hasMatch(lower)) {
    return true;
  }
  return false;
}

String? _muscleFromHint(String? hint) {
  if (hint == null || hint.isEmpty) return null;
  final lower = hint.toLowerCase();
  if (lower.contains('peitoral') || lower.contains('peito')) return 'Peito';
  if (lower.contains('dorsal') ||
      lower.contains('costas') ||
      lower.contains('bíceps') ||
      lower.contains('biceps')) {
    return 'Costas';
  }
  if (lower.contains('perna') ||
      lower.contains('legs') ||
      lower.contains('posterior') ||
      lower.contains('quadriceps') ||
      lower.contains('quadríceps')) {
    return 'Pernas';
  }
  if (lower.contains('ombro') || lower.contains('deltoide')) return 'Ombro';
  return null;
}

WorkoutExercise? _matchExerciseLine(String line) {
  // Strip leading list markers: "1. ", "- ", "* "
  var cleaned = line
      .replaceFirst(RegExp(r'^(\d+[\).\]]\s*|[-*•]\s+)'), '')
      .trim();
  if (cleaned.isEmpty) return null;

  // **Name:** rest…  or  **Name** — rest…
  final bold = RegExp(
    r'^\*\*(.+?)\*\*\s*[:：]?\s*(.*)$',
  ).firstMatch(cleaned);
  String name;
  String rest;
  if (bold != null) {
    name = bold.group(1)!.trim();
    rest = bold.group(2)!.trim();
  } else {
    // Plain: Name: 3 séries…  OR  Name 3x10
    final colon = RegExp(r'^([^:：]{2,80})[:：]\s*(.+)$').firstMatch(cleaned);
    if (colon != null &&
        RegExp(r's[ée]ries|repeti|x\d|\d+\s*[x×]', caseSensitive: false)
            .hasMatch(colon.group(2)!)) {
      name = colon.group(1)!.trim();
      rest = colon.group(2)!.trim();
    } else {
      final simple = RegExp(
        r'^(.+?)\s+(\d+)\s*[x×]\s*(\d+)(?:\s*[-–]\s*(\d+))?\s*(?:[—\-–|]\s*(.+))?$',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (simple == null) return null;
      name = simple.group(1)!.trim();
      final series = int.parse(simple.group(2)!);
      final repsLow = int.parse(simple.group(3)!);
      final repsHigh =
          simple.group(4) != null ? int.parse(simple.group(4)!) : null;
      final note = simple.group(5)?.trim();
      final notes = <String>[];
      if (repsHigh != null) notes.add('Faixa $repsLow–$repsHigh');
      if (note != null && note.isNotEmpty) notes.add(_stripMd(note));
      return WorkoutExercise(
        name: _cleanName(name),
        series: series,
        repetitions: repsLow,
        notes: notes.isEmpty ? null : notes.join(' · '),
      );
    }
  }

  name = _cleanName(name);
  if (name.length < 2) return null;

  // "2 a 3 séries de 10 a 12 repetições …" or "3 séries de 8 a 10 …"
  final seriesReps = RegExp(
    r'(\d+)\s*(?:a|à|até|-|–)\s*(\d+)\s*s[ée]ries\s+de\s+(\d+)\s*(?:a|à|até|-|–)\s*(\d+)\s*repeti',
    caseSensitive: false,
  ).firstMatch(rest);
  final seriesRepsSingle = RegExp(
    r'(\d+)\s*s[ée]ries\s+de\s+(\d+)\s*(?:a|à|até|-|–)\s*(\d+)\s*repeti',
    caseSensitive: false,
  ).firstMatch(rest);
  final seriesRepsFixed = RegExp(
    r'(\d+)\s*s[ée]ries\s+de\s+(\d+)\s*repeti',
    caseSensitive: false,
  ).firstMatch(rest);
  final compact = RegExp(
    r'(\d+)\s*[x×]\s*(\d+)(?:\s*[-–]\s*(\d+))?',
    caseSensitive: false,
  ).firstMatch(rest);

  int series;
  int reps;
  String? rangeNote;

  if (seriesReps != null) {
    series = int.parse(seriesReps.group(1)!);
    // keep lower bound of series range; note the range
    final seriesHigh = int.parse(seriesReps.group(2)!);
    reps = int.parse(seriesReps.group(3)!);
    final repsHigh = int.parse(seriesReps.group(4)!);
    rangeNote = 'Séries $series–$seriesHigh · Faixa $reps–$repsHigh';
  } else if (seriesRepsSingle != null) {
    series = int.parse(seriesRepsSingle.group(1)!);
    reps = int.parse(seriesRepsSingle.group(2)!);
    final repsHigh = int.parse(seriesRepsSingle.group(3)!);
    rangeNote = 'Faixa $reps–$repsHigh';
  } else if (seriesRepsFixed != null) {
    series = int.parse(seriesRepsFixed.group(1)!);
    reps = int.parse(seriesRepsFixed.group(2)!);
  } else if (compact != null) {
    series = int.parse(compact.group(1)!);
    reps = int.parse(compact.group(2)!);
    if (compact.group(3) != null) {
      rangeNote = 'Faixa $reps–${compact.group(3)}';
    }
  } else {
    // Header-like bold without sets — skip
    return null;
  }

  final notes = <String>[];
  if (rangeNote != null) notes.add(rangeNote);

  final rir = RegExp(r'RIR\s*([\d]+(?:\s*[-–]\s*[\d]+)?)', caseSensitive: false)
      .firstMatch(rest);
  if (rir != null) notes.add('RIR ${rir.group(1)!.replaceAll(' ', '')}');

  final parenNotes = RegExp(r'\(([^)]+)\)').allMatches(rest);
  for (final m in parenNotes) {
    final inner = _stripMd(m.group(1)!);
    if (inner.toLowerCase().startsWith('rir')) continue;
    if (inner.isNotEmpty && inner.length < 80) notes.add(inner);
  }

  // Match rest intervals; never treat the "s" in "séries" as seconds.
  final restTime = RegExp(
    r'(\d+\s*(?:a|à|até|-|–)\s*\d+\s*(?:min(?:utos?)?|seg(?:undos?)?)|'
    r'\d+\s*(?:min(?:utos?)?|seg(?:undos?)?)|'
    r'\d+\s*s(?=[\s|*.,)]|$))'
    r'(?:\s+de\s+descanso)?',
    caseSensitive: false,
  ).firstMatch(rest);
  if (restTime != null) {
    notes.add('Descanso ${_stripMd(restTime.group(1)!)}');
  }

  return WorkoutExercise(
    name: name,
    series: series,
    repetitions: reps,
    notes: notes.isEmpty ? null : notes.join(' · '),
  );
}

String _cleanName(String name) {
  return _stripMd(name)
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'[:：]+\s*$'), '')
      .trim();
}

String _stripMd(String value) {
  return value
      .replaceAll('**', '')
      .replaceAll('*', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Builds [WorkoutDay] from AI / loose JSON maps with tolerant field casting.
WorkoutDay workoutDayFromLooseMap(Map<String, dynamic> map) {
  final exercisesRaw = map['exercicios'] as List<dynamic>? ?? [];
  final exercises = exercisesRaw.map((e) {
    final em = Map<String, dynamic>.from(e as Map);
    final name = (em['nome'] ?? em['name'] ?? 'Exercício').toString().trim();

    final series = _asInt(em['series'], fallback: 3);
    final repsRaw = em['repeticoes'] ?? em['reps'];
    final repsParsed = _parseReps(repsRaw);
    final obs = (em['observacao'] ?? em['observacoes'] ?? em['notes'])
        ?.toString()
        .trim();

    final notes = <String>[];
    if (repsParsed.rangeNote != null) notes.add(repsParsed.rangeNote!);
    if (obs != null && obs.isNotEmpty) notes.add(obs);

    return WorkoutExercise(
      name: name.isEmpty ? 'Exercício' : name,
      series: series,
      repetitions: repsParsed.reps,
      notes: notes.isEmpty ? null : notes.join(' · '),
    );
  }).toList();

  final label = (map['nome'] ?? map['dia'] ?? map['dayLabel'] ?? 'Treino')
      .toString()
      .trim();
  final muscle = (map['grupo_muscular'] as String?)?.trim();
  final draft = WorkoutDay(
    dayLabel: label.isEmpty ? 'Treino' : label,
    muscleGroup: 'Misto',
    exercises: exercises,
  );
  final muscleGroup = (muscle != null && muscle.isNotEmpty)
      ? muscle
      : muscleSummaryForDay(draft);

  return WorkoutDay(
    dayLabel: label.isEmpty ? 'Treino' : label,
    muscleGroup: muscleGroup,
    exercises: exercises,
  );
}

int _asInt(Object? value, {required int fallback}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  final match = RegExp(r'\d+').firstMatch(value.toString());
  if (match == null) return fallback;
  return int.parse(match.group(0)!);
}

({int reps, String? rangeNote}) _parseReps(Object? repsRaw) {
  if (repsRaw == null) return (reps: 10, rangeNote: null);
  if (repsRaw is num) return (reps: repsRaw.toInt(), rangeNote: null);
  final str = repsRaw.toString().trim();
  final range = RegExp(r'(\d+)\s*[-–aà]\s*(\d+)').firstMatch(str);
  if (range != null) {
    final low = int.parse(range.group(1)!);
    final high = int.parse(range.group(2)!);
    return (reps: low, rangeNote: 'Faixa $low–$high');
  }
  final single = RegExp(r'\d+').firstMatch(str);
  if (single != null) {
    return (reps: int.parse(single.group(0)!), rangeNote: null);
  }
  return (reps: 10, rangeNote: str.isEmpty ? null : str);
}

/// Pulls the first JSON object/array out of a model reply that may include
/// prose or truncated fences.
String? extractJsonPayload(String content) {
  var text = content.trim();
  final fence = RegExp(
    r'```(?:json)?\s*([\s\S]*?)\s*```',
    caseSensitive: false,
  );
  final fenceMatch = fence.firstMatch(text);
  if (fenceMatch != null) {
    text = fenceMatch.group(1)!.trim();
  }

  if (text.startsWith('{') || text.startsWith('[')) {
    return text;
  }

  final objStart = text.indexOf('{');
  final arrStart = text.indexOf('[');
  int start;
  if (objStart < 0 && arrStart < 0) return null;
  if (objStart < 0) {
    start = arrStart;
  } else if (arrStart < 0) {
    start = objStart;
  } else {
    start = objStart < arrStart ? objStart : arrStart;
  }

  final open = text[start];
  final close = open == '{' ? '}' : ']';
  final end = text.lastIndexOf(close);
  if (end <= start) return null;
  return text.substring(start, end + 1);
}
