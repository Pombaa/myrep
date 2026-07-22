import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import 'repository_providers.dart';

final userProfileProvider = StateNotifierProvider<UserProfileController, AsyncValue<UserProfile?>>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UserProfileController(repository);
});

class UserProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileController(this._repository) : super(const AsyncValue.loading()) {
    _load();
  }

  final UserRepository _repository;

  Future<void> _load() async {
    try {
      final profile = await _repository.fetchProfile();
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    try {
      final saved = await _repository.saveProfile(profile);
      state = AsyncValue.data(saved);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
