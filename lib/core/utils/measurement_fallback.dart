import '../../models/body_measurement.dart';
import '../../models/user_profile.dart';
import 'body_metrics_calculator.dart';

class ResolvedMeasurement {
  const ResolvedMeasurement({required this.measurement, required this.estimated});

  final BodyMeasurement measurement;
  final bool estimated;
}

/// Uses the saved assessment when it exists. Otherwise estimates fat and lean
/// mass from the profile so a plan can still be generated.
ResolvedMeasurement resolveMeasurement(UserProfile profile, BodyMeasurement? latest) {
  if (latest != null) {
    return ResolvedMeasurement(measurement: latest, estimated: false);
  }
  final metrics = BodyMetricsCalculator.calculate(
    weightKg: profile.weight,
    heightMeters: profile.height,
    age: profile.age,
    sex: profile.sex,
  );
  return ResolvedMeasurement(
    estimated: true,
    measurement: BodyMeasurement(
      userId: profile.id ?? 1,
      recordedAt: profile.updatedAt,
      weight: profile.weight,
      bodyFatPercent: metrics.bodyFatPercent,
      leanMass: metrics.leanMass,
      fatMass: metrics.fatMass,
      bmi: metrics.bmi,
    ),
  );
}
