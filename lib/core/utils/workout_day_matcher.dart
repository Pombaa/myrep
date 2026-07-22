import '../../models/workout_plan.dart';

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
