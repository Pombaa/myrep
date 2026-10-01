import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_plan.dart';
import '../models/workout_set.dart';

class WorkoutDraft {
  const WorkoutDraft({
    required this.day,
    required this.exerciseIndex,
    required this.currentSet,
    required this.loads,
    required this.reps,
    required this.recorded,
    this.planId,
    this.restEndsAt,
    this.notes = '',
  });

  final WorkoutDay day;
  final int? planId;
  final int exerciseIndex;
  final int currentSet;
  final DateTime? restEndsAt;
  final String notes;
  final List<String> loads;
  final List<String> reps;
  final Map<int, List<WorkoutSet>> recorded;

  Map<String, Object?> toJson() => {
        'day': day.toJson(),
        'planId': planId,
        'exerciseIndex': exerciseIndex,
        'currentSet': currentSet,
        'restEndsAt': restEndsAt?.toIso8601String(),
        'notes': notes,
        'loads': loads,
        'reps': reps,
        'recorded': {
          for (final entry in recorded.entries)
            '${entry.key}': entry.value.map((set) => set.toJson()).toList(),
        },
      };

  factory WorkoutDraft.fromJson(Map<String, Object?> json) {
    final recordedRaw = (json['recorded'] as Map?)?.cast<String, Object?>() ?? {};
    final recorded = <int, List<WorkoutSet>>{};
    for (final entry in recordedRaw.entries) {
      final index = int.tryParse(entry.key);
      final sets = entry.value;
      if (index == null || sets is! List) continue;
      recorded[index] = sets
          .map((item) => WorkoutSet.fromJson((item as Map).cast<String, Object?>()))
          .toList();
    }
    return WorkoutDraft(
      day: WorkoutDay.fromJson((json['day'] as Map).cast<String, Object?>()),
      planId: (json['planId'] as num?)?.toInt(),
      exerciseIndex: (json['exerciseIndex'] as num?)?.toInt() ?? 0,
      currentSet: (json['currentSet'] as num?)?.toInt() ?? 1,
      restEndsAt: json['restEndsAt'] == null
          ? null
          : DateTime.tryParse(json['restEndsAt'] as String),
      notes: json['notes'] as String? ?? '',
      loads: (json['loads'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      reps: (json['reps'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      recorded: recorded,
    );
  }
}

class WorkoutDraftStore {
  static const _key = 'active_workout_draft';

  Future<void> save(WorkoutDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  Future<WorkoutDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return WorkoutDraft.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      await prefs.remove(_key);
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
