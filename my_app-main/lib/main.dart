import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'theme_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/blockchain_verify_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb
        ? DefaultFirebaseOptions.web
        : DefaultFirebaseOptions.android,
  );

  await loadSavedTheme();
  runApp(const LawScribeApp());
}

class LawScribeApp extends StatelessWidget {
  const LawScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: currentMode,

          initialRoute: '/',

          routes: {
            '/': (_) => const SplashScreen(),

            // Auth
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),

            // Main App — wrapped with inactivity timeout
            '/dashboard': (_) => const _InactivityWrapper(child: DashboardScreen()),
            '/chat': (_) => const _InactivityWrapper(child: ChatScreen()),
            '/settings': (_) => const _InactivityWrapper(child: SettingsScreen()),
            '/verify': (_) => const _InactivityWrapper(child: BlockchainVerifyScreen()),  // for settings nav; chat uses push() with args
          },
        );
      },
    );
  }
}

/// Wraps a screen with an inactivity timer. After [timeout] of no taps,
/// the user is signed out and sent to the login screen.
class _InactivityWrapper extends StatefulWidget {
  final Widget child;
  static const timeout = Duration(minutes: 15);

  const _InactivityWrapper({required this.child});

  @override
  State<_InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<_InactivityWrapper> {
  Timer? _timer;

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(_InactivityWrapper.timeout, _onTimeout);
  }

  void _onTimeout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetTimer,
      onPanDown: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
