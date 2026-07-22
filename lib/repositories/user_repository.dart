import '../models/user_profile.dart';
import '../services/database_service.dart';

class UserRepository {
  UserRepository(this._databaseService);

  final DatabaseService _databaseService;

  Future<UserProfile?> fetchProfile() async {
    final rows = await _databaseService.query(
      'user_profile',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return UserProfile.fromMap(rows.first);
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    final now = DateTime.now();
    if (profile.id == null) {
      final draft = profile.copyWith(createdAt: now, updatedAt: now);
      final id = await _databaseService.insert('user_profile', draft.toMap());
      return draft.copyWith(id: id);
    }

    final updatedProfile = profile.copyWith(updatedAt: now);
    await _databaseService.update(
      'user_profile',
      updatedProfile.toMap(),
      where: 'id = ? ',
      whereArgs: [profile.id],
    );
    return updatedProfile;
  }
}
