import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/settings_repository.dart';
import 'repository_providers.dart';

enum AiProvider { openai, nvidia }

extension AiProviderX on AiProvider {
  String get label => this == AiProvider.openai ? 'OpenAI' : 'NVIDIA';
  String get settingsLabel =>
      this == AiProvider.openai ? 'OpenAI' : 'NVIDIA (gratuito)';
  String get baseUrl => this == AiProvider.openai
      ? 'https://api.openai.com/v1/chat/completions'
      : 'https://integrate.api.nvidia.com/v1/chat/completions';
  String get defaultModel => this == AiProvider.openai
      ? 'gpt-4o-mini'
      : 'meta/llama-3.3-70b-instruct';
  bool get useStructuredOutput => this == AiProvider.openai;
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return ThemeModeController(settings);
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._settings) : super(ThemeMode.system) {
    _load();
  }

  final SettingsRepository _settings;

  Future<void> _load() async {
    final mode = await _settings.loadThemeMode();
    state = mode;
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = mode;
    await _settings.saveThemeMode(mode);
  }
}

final openAiKeyProvider = StateNotifierProvider<OpenAiKeyController, AsyncValue<String?>>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return OpenAiKeyController(settings);
});

final selectedAiProviderProvider =
    StateNotifierProvider<SelectedAiProviderController, AiProvider>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return SelectedAiProviderController(settings);
});

class SelectedAiProviderController extends StateNotifier<AiProvider> {
  SelectedAiProviderController(this._settings) : super(AiProvider.openai) {
    _load();
  }

  final SettingsRepository _settings;

  Future<void> _load() async {
    final value = await _settings.loadSelectedProvider();
    state = value == 'nvidia' ? AiProvider.nvidia : AiProvider.openai;
  }

  Future<void> select(AiProvider provider) async {
    state = provider;
    await _settings.saveSelectedProvider(provider.name);
  }
}

final nvidiaKeyProvider =
    StateNotifierProvider<NvidiaKeyController, AsyncValue<String?>>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return NvidiaKeyController(settings);
});

class NvidiaKeyController extends StateNotifier<AsyncValue<String?>> {
  NvidiaKeyController(this._settings) : super(const AsyncValue.loading()) {
    _load();
  }

  final SettingsRepository _settings;

  Future<void> _load() async {
    try {
      final key = await _settings.loadNvidiaKey();
      state = AsyncValue.data(key);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> save(String apiKey) async {
    state = AsyncValue.data(apiKey);
    await _settings.saveNvidiaKey(apiKey);
  }
}

class OpenAiKeyController extends StateNotifier<AsyncValue<String?>> {
  OpenAiKeyController(this._settings) : super(const AsyncValue.loading()) {
    _load();
  }

  final SettingsRepository _settings;

  Future<void> _load() async {
    try {
      final key = await _settings.loadOpenAiKey();
      state = AsyncValue.data(key);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> save(String apiKey) async {
    state = AsyncValue.data(apiKey);
    await _settings.saveOpenAiKey(apiKey);
  }
}
