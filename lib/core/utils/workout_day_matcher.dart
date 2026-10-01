import '../../models/workout_plan.dart';

/// Plan order with the weekday that matches [date] moved to the front.
/// The remaining days keep their original order.
List<WorkoutDay> planDaysWithTodayFirst(WorkoutPlan plan, [DateTime? date]) {
  final today = findPlanDayForDate(plan, date);
  if (today == null) return plan.days;
  return [
    today,
    ...plan.days.where((day) => day.dayLabel != today.dayLabel),
  ];
}

/// Maps [DateTime.weekday] (Mon=1 … Sun=7) to Portuguese day aliases.
const _weekdayAliases = <int, List<String>>{
  DateTime.monday: ['segunda', 'seg'],
  DateTime.tuesday: ['terça', 'terca', 'ter'],
  DateTime.wednesday: ['quarta', 'qua'],
  DateTime.thursday: ['quinta', 'qui'],
  DateTime.friday: ['sexta', 'sex'],
  DateTime.saturday: ['sábado', 'sabado', 'sáb', 'sab'],
  DateTime.sunday: ['domingo', 'dom'],
};

String weekdayLabelPt([DateTime? date]) {
  const labels = {
    DateTime.monday: 'Segunda',
    DateTime.tuesday: 'Terça',
    DateTime.wednesday: 'Quarta',
    DateTime.thursday: 'Quinta',
    DateTime.friday: 'Sexta',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };
  return labels[(date ?? DateTime.now()).weekday]!;
}

/// Short token for a day avatar. Never returns the full label, so a name like
/// "Segunda-feira: Push A (Peito e Tríceps)" stays "Seg" instead of overflowing
/// the circle.
String dayBadgeLabel(String dayLabel) {
  final normalized = dayLabel.trim().toLowerCase();
  const weekdays = <(String, String)>[
    ('segunda', 'Seg'),
    ('terça', 'Ter'),
    ('terca', 'Ter'),
    ('quarta', 'Qua'),
    ('quinta', 'Qui'),
    ('sexta', 'Sex'),
    ('sábado', 'Sáb'),
    ('sabado', 'Sáb'),
    ('domingo', 'Dom'),
  ];
  for (final (prefix, abbr) in weekdays) {
    if (normalized.startsWith(prefix)) return abbr;
  }

  final split = RegExp(
    r'\b(push|pull|legs)\s*([a-z])?',
    caseSensitive: false,
  ).firstMatch(dayLabel);
  if (split != null) {
    final kind = split.group(1)![0].toUpperCase();
    final letter = split.group(2)?.toUpperCase();
    return letter == null ? kind : '$kind$letter';
  }

  final named = RegExp(
    r'(?:treino|dia)\s*([a-z0-9]+)',
    caseSensitive: false,
  ).firstMatch(dayLabel);
  if (named != null) {
    final token = named.group(1)!;
    return token.length <= 3 ? token.toUpperCase() : token.substring(0, 3).toUpperCase();
  }

  const skip = {'e', 'de', 'do', 'da', 'dos', 'das', 'em', 'com', 'a', 'o'};
  final words = dayLabel
      .split(RegExp(r'[\s\-–:—/]+'))
      .where((word) => word.isNotEmpty && !skip.contains(word.toLowerCase()))
      .take(2)
      .toList();
  if (words.isEmpty) return '•';
  if (words.length == 1) {
    final word = words.first;
    return word.length <= 3 ? word : word.substring(0, 3);
  }
  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

/// Finds the plan day that matches [date]'s weekday (by label).
WorkoutDay? findPlanDayForDate(WorkoutPlan plan, [DateTime? date]) {
  final aliases = _weekdayAliases[(date ?? DateTime.now()).weekday]!;
  for (final day in plan.days) {
    final label = day.dayLabel.toLowerCase().trim();
    if (aliases.any((a) => label == a || label.startsWith(a))) {
      return day;
    }
  }
  return null;
}
