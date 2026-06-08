import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Global theme notifier ─────────────────────────────────────────────────────

// Defaults to System so the app follows the device's light/dark setting until
// the user explicitly picks a theme in Settings.
ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  switch (prefs.getString('themeMode')) {
    case 'light':
      themeNotifier.value = ThemeMode.light;
    case 'dark':
      themeNotifier.value = ThemeMode.dark;
    default:
      themeNotifier.value = ThemeMode.system; // follow the device theme
  }
}

Future<void> saveTheme(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  final value = switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
  await prefs.setString('themeMode', value);
}

// ── Themes ────────────────────────────────────────────────────────────────────

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: const Color(0xFF5B3FA6),
  scaffoldBackgroundColor: const Color(0xFFEFF1F6),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF0D0D1A),
    elevation: 0,
    // Dark status-bar icons so the clock/notifications stay visible on the
    // light app bar (without this they render white-on-white and disappear).
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
    ),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF5B3FA6),
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
    // Light status-bar icons for the dark app bar.
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
    ),
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
      isDark ? const Color(0xFF0A0A14) : const Color(0xFFEFF1F6);

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

  // ── Accent ────────────────────────────────────────────────────────────────
  // Gold reads well on the dark theme but washes out on white, so light mode
  // switches the accent to the brand purple for far better contrast.

  /// Primary accent — gold in dark mode, deep royal purple in light mode.
  Color get accent =>
      isDark ? const Color(0xFFD4AF6A) : const Color(0xFF5B3FA6);

  /// Lighter accent shade, used as the second stop in accent gradients.
  Color get accentSecondary =>
      isDark ? const Color(0xFFF5D98B) : const Color(0xFF7C5FC4);

  /// Stronger/darker accent for text and icons sitting directly on white.
  Color get accentStrong =>
      isDark ? const Color(0xFFD4AF6A) : const Color(0xFF45307E);

  // ── Elevation ───────────────────────────────────────────────────────────
  // Two levels only, for a calm, premium feel. `softShadow` lifts cards and
  // tiles a touch; `heroShadow` is the accent-tinted glow reserved for hero
  // elements (logo badge, primary buttons).

  /// Subtle neutral elevation for cards, tiles, and chips. Light mode uses a
  /// layered contact + ambient shadow for a softer, more premium lift.
  List<BoxShadow> get softShadow => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];

  /// Prominent accent-tinted elevation for hero elements only.
  List<BoxShadow> get heroShadow => [
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.30 : 0.22),
          blurRadius: 28,
          offset: const Offset(0, 8),
        ),
      ];
}

// ── Corner-radius scale ───────────────────────────────────────────────────
// One tight scale keeps the UI cohesive. Use these instead of arbitrary values:
//   sm 8  — badges, small status pills
//   md 12 — buttons, inputs, chips, icon tiles (the default for interactive UI)
//   lg 16 — cards, dialogs, panels
//   xl 20 — prominent containers, drawers, auth cards
// (Decorative thin accent bars and asymmetric chat bubbles are exceptions.)
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}
