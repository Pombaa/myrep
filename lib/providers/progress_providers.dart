import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/progress_summary.dart';
import '../models/workout_session.dart';
import 'measurement_providers.dart';
import 'repository_providers.dart';

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final measurementsAsync = ref.watch(bodyMeasurementsProvider);
  final measurements = measurementsAsync.valueOrNull;
  final workoutRepository = ref.watch(workoutRepositoryProvider);
  final sessions = await workoutRepository.fetchSessions(limit: 30);
  final loadDelta = await workoutRepository.averageLoadDelta();

  if (measurements == null || measurements.isEmpty) {
    return ProgressSummary(
      weightDelta: 0,
      bodyFatDelta: 0,
      leanMassDelta: 0,
      averageLoadDelta: loadDelta,
      measurementsCount: 0,
      sessionsCount: sessions.length,
    );
  }

  final latest = measurements.first;
  final baseline = measurements.length > 1 ? measurements.last : measurements.first;

  return ProgressSummary(
    weightDelta: double.parse((latest.weight - baseline.weight).toStringAsFixed(1)),
    bodyFatDelta: double.parse((latest.bodyFatPercent - baseline.bodyFatPercent).toStringAsFixed(1)),
    leanMassDelta: double.parse((latest.leanMass - baseline.leanMass).toStringAsFixed(1)),
    averageLoadDelta: loadDelta,
    measurementsCount: measurements.length,
    sessionsCount: sessions.length,
  );
});

final workoutSessionsProvider = FutureProvider<List<WorkoutSession>>((ref) async {
  final repository = ref.watch(workoutRepositoryProvider);
  return repository.fetchSessions(limit: 30);
});
