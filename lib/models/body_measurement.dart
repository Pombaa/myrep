class BodyMeasurement {
  const BodyMeasurement({
    this.id,
    required this.userId,
    required this.recordedAt,
    required this.weight,
    required this.bodyFatPercent,
    required this.leanMass,
    required this.fatMass,
    required this.bmi,
    this.arm,
    this.chest,
    this.waist,
    this.abdomen,
    this.hip,
    this.thigh,
    this.calf,
    this.notes,
  });

  final int? id;
  final int userId;
  final DateTime recordedAt;
  final double weight;
  final double bodyFatPercent;
  final double leanMass;
  final double fatMass;
  final double bmi;
  final double? arm;
  final double? chest;
  final double? waist;
  final double? abdomen;
  final double? hip;
  final double? thigh;
  final double? calf;
  final String? notes;

  BodyMeasurement copyWith({
    int? id,
    int? userId,
    DateTime? recordedAt,
    double? weight,
    double? bodyFatPercent,
    double? leanMass,
    double? fatMass,
    double? bmi,
    double? arm,
    double? chest,
    double? waist,
    double? abdomen,
    double? hip,
    double? thigh,
    double? calf,
    String? notes,
  }) {
    return BodyMeasurement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recordedAt: recordedAt ?? this.recordedAt,
      weight: weight ?? this.weight,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      leanMass: leanMass ?? this.leanMass,
      fatMass: fatMass ?? this.fatMass,
      bmi: bmi ?? this.bmi,
      arm: arm ?? this.arm,
      chest: chest ?? this.chest,
      waist: waist ?? this.waist,
      abdomen: abdomen ?? this.abdomen,
      hip: hip ?? this.hip,
      thigh: thigh ?? this.thigh,
      calf: calf ?? this.calf,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'recorded_at': recordedAt.toIso8601String(),
      'weight': weight,
      'body_fat_percent': bodyFatPercent,
      'lean_mass': leanMass,
      'fat_mass': fatMass,
      'bmi': bmi,
      'arm': arm,
      'chest': chest,
      'waist': waist,
      'abdomen': abdomen,
      'hip': hip,
      'thigh': thigh,
      'calf': calf,
      'notes': notes,
    };
  }

  factory BodyMeasurement.fromMap(Map<String, Object?> map) {
    return BodyMeasurement(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      weight: (map['weight'] as num).toDouble(),
      bodyFatPercent: (map['body_fat_percent'] as num).toDouble(),
      leanMass: (map['lean_mass'] as num).toDouble(),
      fatMass: (map['fat_mass'] as num).toDouble(),
      bmi: (map['bmi'] as num).toDouble(),
      arm: (map['arm'] as num?)?.toDouble(),
      chest: (map['chest'] as num?)?.toDouble(),
      waist: (map['waist'] as num?)?.toDouble(),
      abdomen: (map['abdomen'] as num?)?.toDouble(),
      hip: (map['hip'] as num?)?.toDouble(),
      thigh: (map['thigh'] as num?)?.toDouble(),
      calf: (map['calf'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }
}
