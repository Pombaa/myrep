import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/user_providers.dart';
import '../onboarding/profile_setup_screen.dart';
import 'app_startup_error.dart';
import 'app_startup_loading.dart';
import 'home_shell.dart';

class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProfileProvider);

    return userState.when(
      data: (profile) {
        if (profile == null) {
          return const ProfileSetupScreen();
        }
        return const HomeShell();
      },
      loading: () => const AppStartupLoading(),
      error: (error, stackTrace) => AppStartupError(error: error, stackTrace: stackTrace),
    );
  }
}
