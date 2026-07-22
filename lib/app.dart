import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_startup_provider.dart';
import 'providers/settings_providers.dart';
import 'screens/shell/app_startup_gate.dart';
import 'screens/shell/app_startup_loading.dart';
import 'screens/shell/app_startup_error.dart';

class FitAiApp extends ConsumerWidget {
  const FitAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'FitAI Trainer',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: startup.when(
        data: (_) => const AppStartupGate(),
        loading: () => const AppStartupLoading(),
        error: (error, stack) => AppStartupError(error: error, stackTrace: stack),
      ),
    );
  }
}
