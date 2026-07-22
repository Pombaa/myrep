import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/settings_repository.dart';
import '../services/notification_service.dart';
import 'repository_providers.dart';
import 'services_providers.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  final database = ref.read(databaseServiceProvider);
  await database.init();

  final settings = ref.read(settingsRepositoryProvider);
  await settings.ensureInitialized();

  final notificationService = ref.read(notificationServiceProvider);
  await notificationService.initialize();
  await notificationService.requestPermissions();

  await _scheduleEvaluationReminder(ref, settings, notificationService);
});

Future<void> _scheduleEvaluationReminder(
  Ref ref,
  SettingsRepository settings,
  NotificationService notificationService,
) async {
  final lastMeasurement = await ref.read(bodyMeasurementRepositoryProvider).latest();
  if (lastMeasurement != null) {
    await notificationService.scheduleEvaluationReminder(lastMeasurement.recordedAt);
    await settings.saveLastAssessmentDate(lastMeasurement.recordedAt);
  } else {
    final storedDate = await settings.loadLastAssessmentDate();
    if (storedDate != null) {
      await notificationService.scheduleEvaluationReminder(storedDate);
    }
  }
}
