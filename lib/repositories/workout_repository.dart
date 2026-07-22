import 'dart:convert';

import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';

class WorkoutRepository {
  WorkoutRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<WorkoutPlan?> latestPlan() async {
    final rows = await _databaseService.query(
      'workout_plans',
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WorkoutPlan.fromMap(rows.first);
  }

  Future<WorkoutPlan> savePlan(WorkoutPlan plan) async {
    final id = await _databaseService.insert('workout_plans', plan.toMap());
    return plan.copyWith(id: id);
  }

  Future<List<WorkoutPlan>> fetchPlans({int limit = 10}) async {
    final rows = await _databaseService.query(
      'workout_plans',
      orderBy: 'generated_at DESC',
      limit: limit,
    );
    return rows.map(WorkoutPlan.fromMap).toList();
  }

  Future<WorkoutSession> logSession(WorkoutSession session) async {
    final id = await _databaseService.insert('workout_sessions', session.toMap());
    return session.copyWith(id: id);
  }

  Future<List<WorkoutSession>> fetchSessions({int limit = 20}) async {
    final rows = await _databaseService.query(
      'workout_sessions',
      orderBy: 'executed_at DESC',
      limit: limit,
    );
    return rows.map(WorkoutSession.fromMap).toList();
  }

  Future<WorkoutSession?> lastSession() async {
    final rows = await _databaseService.query(
      'workout_sessions',
      orderBy: 'executed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WorkoutSession.fromMap(rows.first);
  }

  Future<void> deleteAllPlans() async {
    await _databaseService.delete('workout_plans');
  }

  Future<double> averageLoadDelta() async {
    final rows = await _databaseService.query(
      'workout_sessions',
      columns: ['session_json'],
      orderBy: 'executed_at DESC',
      limit: 6,
    );
    if (rows.length < 2) {
      return 0;
    }
    double average(List<Map<String, Object?>> list) {
      final loads = <double>[];
      for (final row in list) {
        final json = row['session_json'] as String;
        final parsed = jsonDecode(json) as List<dynamic>;
        for (final item in parsed) {
          final map = (item as Map).cast<String, Object?>();
          final load = (map['carga_sugerida'] as num?)?.toDouble();
          if (load != null) {
            loads.add(load);
          }
        }
      }
      if (loads.isEmpty) {
        return 0;
      }
      return loads.reduce((a, b) => a + b) / loads.length;
    }

    final recentAverage = average(rows.take(3).toList());
    final previousAverage = average(rows.skip(3).take(3).toList());
    return double.parse((recentAverage - previousAverage).toStringAsFixed(1));
  }
}
