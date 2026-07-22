import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/openai_service.dart';
import '../services/workout_notification_service.dart';
import '../services/workout_foreground_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(service.close);
  return service;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final workoutNotificationServiceProvider = Provider<WorkoutNotificationService>((ref) {
  final service = WorkoutNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

final workoutForegroundServiceProvider = Provider<WorkoutForegroundService>((ref) {
  return WorkoutForegroundService();
});

final openAiServiceProvider = Provider<OpenAiService>((ref) {
  return OpenAiService();
});
