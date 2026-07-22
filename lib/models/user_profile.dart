class UserProfile {
  const UserProfile({
    this.id,
    required this.name,
    required this.age,
    required this.sex,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.objective,
    this.restrictions,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final int age;
  final String sex;
  final double height;
  final double weight;
  final String activityLevel;
  final String objective;
  final String? restrictions;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    int? id,
    String? name,
    int? age,
    String? sex,
    double? height,
    double? weight,
    String? activityLevel,
    String? objective,
    String? restrictions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      activityLevel: activityLevel ?? this.activityLevel,
      objective: objective ?? this.objective,
      restrictions: restrictions ?? this.restrictions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'sex': sex,
      'height': height,
      'weight': weight,
      'activity_level': activityLevel,
      'objective': objective,
      'restrictions': restrictions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      age: map['age'] as int,
      sex: map['sex'] as String,
      height: (map['height'] as num).toDouble(),
      weight: (map['weight'] as num).toDouble(),
      activityLevel: map['activity_level'] as String,
      objective: map['objective'] as String,
      restrictions: map['restrictions'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
