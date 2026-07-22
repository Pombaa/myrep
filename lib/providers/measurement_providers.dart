import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/body_measurement.dart';
import '../repositories/body_measurement_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/notification_service.dart';
import 'repository_providers.dart';
import 'services_providers.dart';

final bodyMeasurementsProvider = StateNotifierProvider<BodyMeasurementsController, AsyncValue<List<BodyMeasurement>>>((ref) {
  return BodyMeasurementsController(ref);
});

final latestMeasurementProvider = Provider<BodyMeasurement?>((ref) {
  final measurements = ref.watch(bodyMeasurementsProvider).valueOrNull;
  return measurements?.isNotEmpty == true ? measurements!.first : null;
});

final previousMeasurementProvider = Provider<BodyMeasurement?>((ref) {
  final measurements = ref.watch(bodyMeasurementsProvider).valueOrNull;
  if (measurements == null || measurements.length < 2) {
    return null;
  }
  return measurements[1];
});

class BodyMeasurementsController extends StateNotifier<AsyncValue<List<BodyMeasurement>>> {
  BodyMeasurementsController(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;

  BodyMeasurementRepository get _repository => _ref.read(bodyMeasurementRepositoryProvider);
  SettingsRepository get _settingsRepository => _ref.read(settingsRepositoryProvider);
  NotificationService get _notificationService => _ref.read(notificationServiceProvider);

  Future<void> _load() async {
    try {
      final measurements = await _repository.fetchMeasurements();
      state = AsyncValue.data(measurements);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async => _load();

  Future<void> addMeasurement(BodyMeasurement measurement) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([measurement, ...current]);
    try {
      final saved = await _repository.addMeasurement(measurement);
      final updated = [saved, ...current];
      state = AsyncValue.data(updated);
      await _settingsRepository.saveLastAssessmentDate(saved.recordedAt);
      await _notificationService.scheduleEvaluationReminder(saved.recordedAt);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
