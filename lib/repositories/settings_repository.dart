import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _themeKey = 'theme_mode';
  static const _openAiKey = 'openai_api_key';
  static const _nvidiaKey = 'nvidia_api_key';
  static const _selectedProviderKey = 'selected_ai_provider';
  static const _lastAssessmentKey = 'last_assessment_date';

  SharedPreferences? _prefs;

  Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<ThemeMode> loadThemeMode() async {
    await ensureInitialized();
    final value = _prefs!.getString(_themeKey);
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await ensureInitialized();
    await _prefs!.setString(_themeKey, mode.name);
  }

  Future<String?> loadOpenAiKey() async {
    await ensureInitialized();
    return _prefs!.getString(_openAiKey);
  }

  Future<void> saveOpenAiKey(String apiKey) async {
    await ensureInitialized();
    await _prefs!.setString(_openAiKey, apiKey);
  }

  Future<String?> loadNvidiaKey() async {
    await ensureInitialized();
    return _prefs!.getString(_nvidiaKey);
  }

  Future<void> saveNvidiaKey(String apiKey) async {
    await ensureInitialized();
    await _prefs!.setString(_nvidiaKey, apiKey);
  }

  Future<String> loadSelectedProvider() async {
    await ensureInitialized();
    return _prefs!.getString(_selectedProviderKey) ?? 'openai';
  }

  Future<void> saveSelectedProvider(String provider) async {
    await ensureInitialized();
    await _prefs!.setString(_selectedProviderKey, provider);
  }

  Future<DateTime?> loadLastAssessmentDate() async {
    await ensureInitialized();
    final value = _prefs!.getString(_lastAssessmentKey);
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<void> saveLastAssessmentDate(DateTime date) async {
    await ensureInitialized();
    await _prefs!.setString(_lastAssessmentKey, date.toIso8601String());
  }
}
