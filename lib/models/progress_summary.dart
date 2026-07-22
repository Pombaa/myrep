class ProgressSummary {
  const ProgressSummary({
    required this.weightDelta,
    required this.bodyFatDelta,
    required this.leanMassDelta,
    required this.averageLoadDelta,
    this.measurementsCount = 0,
    this.sessionsCount = 0,
  });

  final double weightDelta;
  final double bodyFatDelta;
  final double leanMassDelta;
  final double averageLoadDelta;
  final int measurementsCount;
  final int sessionsCount;

  bool get hasProgressData => measurementsCount > 1;
}
