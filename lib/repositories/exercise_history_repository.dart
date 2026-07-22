import '../models/exercise_progression_suggestion.dart';
import '../services/database_service.dart';

class ExerciseHistoryRepository {
  const ExerciseHistoryRepository(this._db);

  final DatabaseService _db;

  static const _table = 'exercise_history';

  Future<ExerciseHistoryEntry> save(ExerciseHistoryEntry entry) async {
    final map = Map<String, Object?>.from(entry.toMap())..remove('id');
    final id = await _db.insert(_table, map);
    return entry.copyWith(id: id);
  }

  Future<void> updateProgressionDecision(int id, String decisionLabel) async {
    final escaped = decisionLabel.replaceAll('"', '\\"');
    await _db.update(
      _table,
      {'progression_decision': '{"label":"$escaped"}'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ExerciseHistoryEntry>> getRecentByExercise(
    String exerciseName,
    int userId, {
    int limit = 4,
  }) async {
    final rows = await _db.query(
      _table,
      where: 'exercise_name = ? AND user_id = ?',
      whereArgs: [exerciseName, userId],
      orderBy: 'session_date DESC',
      limit: limit,
    );
    return rows.map(ExerciseHistoryEntry.fromMap).toList();
  }

  Future<List<ExerciseHistoryEntry>> getSessionEntries(
    int userId,
    DateTime sessionDate,
  ) async {
    final dateStr = sessionDate.toIso8601String().substring(0, 10);
    final rows = await _db.query(
      _table,
      where: 'user_id = ? AND session_date LIKE ?',
      whereArgs: [userId, '$dateStr%'],
      orderBy: 'id ASC',
    );
    return rows.map(ExerciseHistoryEntry.fromMap).toList();
  }

  Future<Map<String, List<ExerciseHistoryEntry>>> getProgressionSummary(
    int userId, {
    int limit = 4,
  }) async {
    final rows = await _db.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'session_date DESC',
      limit: limit * 20,
    );
    final entries = rows.map(ExerciseHistoryEntry.fromMap).toList();
    final grouped = <String, List<ExerciseHistoryEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.exerciseName, () => []);
      if (grouped[e.exerciseName]!.length < limit) {
        grouped[e.exerciseName]!.add(e);
      }
    }
    return grouped;
  }

  Future<ExerciseHistoryEntry?> getLastEntryForExercise(
    String exerciseName,
    int userId,
  ) async {
    final rows = await _db.query(
      _table,
      where: 'exercise_name = ? AND user_id = ?',
      whereArgs: [exerciseName, userId],
      orderBy: 'session_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExerciseHistoryEntry.fromMap(rows.first);
  }

  /// Returns the most recent entry for [exerciseName] with [sessionDate] strictly before [before].
  Future<ExerciseHistoryEntry?> getLastEntryBeforeSession(
    String exerciseName,
    int userId,
    DateTime before,
  ) async {
    final dateStr = before.toIso8601String();
    final rows = await _db.query(
      _table,
      where: 'exercise_name = ? AND user_id = ? AND session_date < ?',
      whereArgs: [exerciseName, userId, dateStr],
      orderBy: 'session_date DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ExerciseHistoryEntry.fromMap(rows.first);
  }
}
