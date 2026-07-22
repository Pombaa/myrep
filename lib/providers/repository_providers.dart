import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/ai_repository.dart';
import '../repositories/body_measurement_repository.dart';
import '../repositories/exercise_history_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/workout_repository.dart';
import 'services_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return UserRepository(db);
});

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return BodyMeasurementRepository(db);
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return WorkoutRepository(db);
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return AiRepository(db);
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return ReminderRepository(db);
});

final exerciseHistoryRepositoryProvider = Provider<ExerciseHistoryRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return ExerciseHistoryRepository(db);
});
