import '../models/workout_reminder.dart';
import '../services/database_service.dart';

class ReminderRepository {
  ReminderRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<List<WorkoutReminder>> fetchActiveReminders(int userId) async {
    final results = await _databaseService.query(
      'workout_reminders',
      where: 'user_id = ? AND is_active = ?',
      whereArgs: [userId, 1],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => WorkoutReminder.fromMap(map)).toList();
  }

  Future<List<WorkoutReminder>> fetchAllReminders(int userId) async {
    final results = await _databaseService.query(
      'workout_reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return results.map((map) => WorkoutReminder.fromMap(map)).toList();
  }

  Future<WorkoutReminder> saveReminder(WorkoutReminder reminder) async {
    final id = await _databaseService.insert(
      'workout_reminders',
      reminder.toMap(),
    );
    return reminder.copyWith(id: id);
  }

  Future<void> updateReminder(WorkoutReminder reminder) async {
    if (reminder.id == null) {
      throw Exception('Cannot update reminder without ID');
    }
    await _databaseService.update(
      'workout_reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> deleteReminder(int id) async {
    await _databaseService.delete(
      'workout_reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleReminderActive(int id, bool isActive) async {
    await _databaseService.update(
      'workout_reminders',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
