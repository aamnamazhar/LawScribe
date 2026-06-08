import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/scribe_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // One-shot entrance timeline, and a looping controller for the ambient
  // ripple + shimmer effects.
  late final AnimationController _intro;
  late final AnimationController _loop;

  late final Animation<double> _badgeScale;
  late final Animation<double> _badgeRotate;
  late final Animation<double> _badgeFade;
  late final Animation<double> _wordmark;
  late final Animation<double> _tagline;
  late final Animation<double> _progress;

  static const _gold = Color(0xFFD4AF6A);
  static const _goldLight = Color(0xFFF5D98B);
  static const _ink = Color(0xFF0A0A14);
  static const _badgeSize = 84.0;

  @override
  void initState() {
    super.initState();

    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // Badge springs in with an elastic bounce + a small unwind rotation.
    _badgeScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
    _badgeRotate = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _badgeFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    // Wordmark, then tagline, reveal in sequence after the badge.
    _wordmark = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
    );
    _tagline = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.65, 0.9, curve: Curves.easeOut),
    );
    _progress = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
    );

    _intro.forward();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      // Keep the user signed in across app restarts. Route by auth + verified
      // state: verified → app, signed-in-but-unverified → verify gate, else login.
      final user = FirebaseAuth.instance.currentUser;
      final String route;
      if (user == null) {
        route = '/login';
      } else if (user.emailVerified) {
        route = '/chat';
      } else {
        route = '/verify-email';
      }
      Navigator.pushReplacementNamed(context, route);
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          // Dark base gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0A14), Color(0xFF0F0F22), Color(0xFF080810)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Ambient glow — top left (purple)
          _glow(top: -100, left: -80, size: 360, color: const Color(0xFF7B5EA7), alpha: 0.30),
          // Ambient glow — bottom right (gold)
          _glow(bottom: -80, right: -60, size: 300, color: const Color(0xFFC9A84C), alpha: 0.20),

          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge + sonar ripples
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _ripples(),
                      AnimatedBuilder(
                        animation: _intro,
                        builder: (_, child) => Opacity(
                          opacity: _badgeFade.value.clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: _badgeRotate.value,
                            child: Transform.scale(
                              scale: _badgeScale.value,
                              child: child,
                            ),
                          ),
                        ),
                        child: _badge(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Wordmark — slides up + fades in
                AnimatedBuilder(
                  animation: _wordmark,
                  builder: (_, child) => Opacity(
                    opacity: _wordmark.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - _wordmark.value) * 16),
                      child: child,
                    ),
                  ),
                  child: const ScribeLogo(height: 38, forcedTextColor: Colors.white),
                ),

                const SizedBox(height: 12),

                // Tagline
                FadeTransition(
                  opacity: _tagline,
                  child: Text(
                    'Your AI Legal Assistant',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.40),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Progress bar
                FadeTransition(
                  opacity: _tagline,
                  child: SizedBox(
                    width: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (_, _) => LinearProgressIndicator(
                          value: _progress.value,
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(_gold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Version tag
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _tagline,
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.18),
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pieces ────────────────────────────────────────────────────────────────

  /// Concentric gold rings that pulse outward and fade — a soft "sonar" feel.
  Widget _ripples() {
    return AnimatedBuilder(
      animation: _loop,
      builder: (_, _) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (i) {
            final t = (_loop.value + i / 3) % 1.0;
            final size = _badgeSize + t * 150;
            final opacity = (1 - t) * 0.35;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: opacity),
                  width: 1.5,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// The gold badge with a looping diagonal shimmer sweep across it.
  Widget _badge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: _badgeSize,
        height: _badgeSize,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_gold, _goldLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.40),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.15),
                    blurRadius: 60,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: ScribeMark(size: 40, color: _ink),
              ),
            ),

            // Shimmer highlight — a soft diagonal band that glides across.
            AnimatedBuilder(
              animation: _loop,
              builder: (_, _) {
                final dx = -1.3 + 2.6 * _loop.value;
                return Transform.translate(
                  offset: Offset(_badgeSize * dx, 0),
                  child: Transform.rotate(
                    angle: 0.5,
                    child: Container(
                      width: _badgeSize * 0.42,
                      height: _badgeSize * 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
    required double alpha,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
