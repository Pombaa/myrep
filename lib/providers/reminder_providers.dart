import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/workout_reminder.dart';
import 'repository_providers.dart';
import 'user_providers.dart';

final workoutRemindersProvider = FutureProvider<List<WorkoutReminder>>((
  ref,
) async {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return [];

  final repository = ref.watch(reminderRepositoryProvider);
  return repository.fetchActiveReminders(profile.id ?? 1);
});

final allWorkoutRemindersProvider = FutureProvider<List<WorkoutReminder>>((
  ref,
) async {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null) return [];

  final repository = ref.watch(reminderRepositoryProvider);
  return repository.fetchAllReminders(profile.id ?? 1);
});

final reminderManagerProvider = Provider<ReminderManager>((ref) {
  return ReminderManager(ref);
});

class ReminderManager {
  ReminderManager(this._ref);

  final Ref _ref;

  Future<void> saveReminder(String content, String category) async {
    final profile = _ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      throw Exception('Perfil não encontrado');
    }

    final reminder = WorkoutReminder(
      userId: profile.id ?? 1,
      createdAt: DateTime.now(),
      content: content,
      category: category,
    );

    final repository = _ref.read(reminderRepositoryProvider);
    await repository.saveReminder(reminder);
    _ref.invalidate(workoutRemindersProvider);
    _ref.invalidate(allWorkoutRemindersProvider);
  }

  Future<void> toggleReminder(int id, bool isActive) async {
    final repository = _ref.read(reminderRepositoryProvider);
    await repository.toggleReminderActive(id, isActive);
    _ref.invalidate(workoutRemindersProvider);
    _ref.invalidate(allWorkoutRemindersProvider);
  }

  Future<void> deleteReminder(int id) async {
    final repository = _ref.read(reminderRepositoryProvider);
    await repository.deleteReminder(id);
    _ref.invalidate(workoutRemindersProvider);
    _ref.invalidate(allWorkoutRemindersProvider);
  }
}
