import 'dart:math';

class BodyMetricsResult {
  const BodyMetricsResult({
    required this.bmi,
    required this.bodyFatPercent,
    required this.leanMass,
    required this.fatMass,
  });

  final double bmi;
  final double bodyFatPercent;
  final double leanMass;
  final double fatMass;
}

class BodyMetricsCalculator {
  static BodyMetricsResult calculate({
    required double weightKg,
    required double heightMeters,
    required int age,
    required String sex,
  }) {
    final bmi = weightKg / pow(heightMeters, 2);
    final sexFlag = sex.toLowerCase().startsWith('m') ? 1 : 0;
    final bodyFat = (1.2 * bmi) + (0.23 * age) - (10.8 * sexFlag) - 5.4;
    final normalizedBodyFat = bodyFat.clamp(4, 75);
    final leanMass = weightKg * (1 - normalizedBodyFat / 100);
    final fatMass = weightKg - leanMass;

    return BodyMetricsResult(
      bmi: double.parse(bmi.toStringAsFixed(2)),
      bodyFatPercent: double.parse(normalizedBodyFat.toStringAsFixed(2)),
      leanMass: double.parse(leanMass.toStringAsFixed(2)),
      fatMass: double.parse(fatMass.toStringAsFixed(2)),
    );
  }
}
