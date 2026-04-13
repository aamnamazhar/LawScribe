import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Global theme notifier ─────────────────────────────────────────────────────

ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

Future<void> saveTheme(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
}

// ── Themes ────────────────────────────────────────────────────────────────────

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF7B5EA7),
  scaffoldBackgroundColor: const Color(0xFFF4F4F8),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF0D0D1A),
    elevation: 0,
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF7B5EA7),
    secondary: Color(0xFF4A90D9),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF7B5EA7),
  scaffoldBackgroundColor: const Color(0xFF0A0A14),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0F0F22),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF7B5EA7),
    secondary: Color(0xFF4A90D9),
  ),
);

// ── BuildContext color helpers ────────────────────────────────────────────────

extension AppTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Page/scaffold background
  Color get bgColor =>
      isDark ? const Color(0xFF0A0A14) : const Color(0xFFF4F4F8);

  /// Card / list item background
  Color get cardColor => isDark ? const Color(0xFF0F0F22) : Colors.white;

  /// AppBar background
  Color get appBarColor => isDark ? const Color(0xFF0F0F22) : Colors.white;

  /// Popup / dropdown background
  Color get popupColor =>
      isDark ? const Color(0xFF13132A) : const Color(0xFFF8F8FC);

  /// Subtle border
  Color get borderColor =>
      isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.08);

  /// Thin divider line
  Color get dividerColor =>
      isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06);

  /// Primary text
  Color get textPrimary =>
      isDark ? Colors.white : const Color(0xFF0D0D1A);

  /// Secondary / muted text
  Color get textSecondary =>
      isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.45);

  /// Hint / placeholder text
  Color get textHint =>
      isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.28);

  /// Progress bar / spinner track background
  Color get progressBg =>
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
}
