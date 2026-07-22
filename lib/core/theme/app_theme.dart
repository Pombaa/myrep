import 'package:flutter/material.dart';

class AppTheme {
  // Paleta de cores
  static const Color _primaryBase = Color(0xFF8A5EFF);
  static const Color _primaryDark = Color(0xFF5B38C6);
  static const Color _primaryLight = Color(0xFFCDBBFF);

  // Light mode colors
  static const Color _lightBackground = Color(0xFFFAF8FF);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightBorder = Color(0xFFE6DFFF);
  static const Color _lightTextPrimary = Color(0xFF2A2353);
  static const Color _lightTextSecondary = Color(0xFF6E6791);
  static const Color _lightSuccess = Color(0xFF7FD1B9);
  static const Color _lightWarning = Color(0xFFFFC285);

  // Dark mode colors
  static const Color _darkBackground = Color(0xFF0F0C18);
  static const Color _darkSurface = Color(0xFF191528);
  static const Color _darkBorder = Color(0xFF2C2644);
  static const Color _darkTextPrimary = Color(0xFFF1ECFF);
  static const Color _darkTextSecondary = Color(0xFFA9A0D0);
  static const Color _darkSuccess = Color(0xFF5FBFA6);
  static const Color _darkWarning = Color(0xFFE8A86B);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _primaryBase,
        onPrimary: Colors.white,
        primaryContainer: _primaryLight,
        onPrimaryContainer: _lightTextPrimary,
        secondary: _lightSuccess,
        onSecondary: Colors.white,
        secondaryContainer: _lightSuccess.withOpacity(0.2),
        onSecondaryContainer: _lightTextPrimary,
        tertiary: _lightWarning,
        onTertiary: Colors.white,
        tertiaryContainer: _lightWarning.withOpacity(0.2),
        onTertiaryContainer: _lightTextPrimary,
        error: Colors.red.shade400,
        onError: Colors.white,
        surface: _lightSurface,
        onSurface: _lightTextPrimary,
        onSurfaceVariant: _lightTextSecondary,
        outline: _lightBorder,
        outlineVariant: _lightBorder.withOpacity(0.5),
        surfaceContainerHighest: _lightBackground,
        background: _lightBackground,
        onBackground: _lightTextPrimary,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: _lightSurface,
        foregroundColor: _lightTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: _lightBorder, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryBase,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryBase,
          side: BorderSide(color: _primaryBase, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryBase, width: 2),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _primaryLight,
        onPrimary: _darkBackground,
        primaryContainer: _primaryDark,
        onPrimaryContainer: _darkTextPrimary,
        secondary: _darkSuccess,
        onSecondary: _darkBackground,
        secondaryContainer: _darkSuccess.withOpacity(0.2),
        onSecondaryContainer: _darkTextPrimary,
        tertiary: _darkWarning,
        onTertiary: _darkBackground,
        tertiaryContainer: _darkWarning.withOpacity(0.2),
        onTertiaryContainer: _darkTextPrimary,
        error: Colors.red.shade300,
        onError: _darkBackground,
        surface: _darkSurface,
        onSurface: _darkTextPrimary,
        onSurfaceVariant: _darkTextSecondary,
        outline: _darkBorder,
        outlineVariant: _darkBorder.withOpacity(0.5),
        surfaceContainerHighest: _darkBackground,
        background: _darkBackground,
        onBackground: _darkTextPrimary,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: _darkBorder, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primaryLight,
          foregroundColor: _darkBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryLight,
          side: BorderSide(color: _primaryLight, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryLight, width: 2),
        ),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _darkSurface,
        contentTextStyle: TextStyle(color: _darkTextPrimary),
      ),
    );
  }
}
