import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme_provider.dart';

/// Shown after signup (and on login for unverified accounts). Blocks app access
/// until the user clicks the verification link sent to their email. Polls every
/// few seconds so it continues automatically once the email is verified.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _checking = false;

  String get _email =>
      FirebaseAuth.instance.currentUser?.email ?? 'your email';

  @override
  void initState() {
    super.initState();
    // Send the verification link on arrival (covers both the signup path and the
    // login-with-an-unverified-account path), then poll so the screen continues
    // automatically once the user clicks the link.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitial());
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkVerified(silent: true),
    );
  }

  Future<void> _sendInitial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) return;
    await _resend();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({bool silent = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!silent) setState(() => _checking = true);
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        _pollTimer?.cancel();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/chat');
        return;
      }
      if (!silent && mounted) {
        _snack('Not verified yet — please click the link in your email.');
      }
    } catch (_) {
      // Ignore transient reload errors (e.g. briefly offline).
    } finally {
      if (!silent && mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _resendCooldown > 0) return;
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      _snack('Verification email sent. Check your inbox (and spam).');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'too-many-requests') {
        _snack('Too many requests. Please wait a moment before retrying.');
        _startCooldown();
      } else {
        _snack('Could not send the email. Please try again.');
      }
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  Future<void> _useDifferentEmail() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: context.textPrimary)),
        backgroundColor: context.popupColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // Base gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.isDark
                    ? const [
                        Color(0xFF0A0A14),
                        Color(0xFF0F0F22),
                        Color(0xFF080810),
                      ]
                    : const [
                        Color(0xFFEFF1F6),
                        Color(0xFFEAEBF2),
                        Color(0xFFEFF1F6),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Ambient glows
          Positioned(
            top: -80,
            left: -60,
            child: _glow(context.accent.withValues(alpha: 0.22), 280),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: _glow(context.accent.withValues(alpha: 0.16), 220),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 36,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.borderColor,
                            width: 1.2,
                          ),
                          boxShadow: context.softShadow,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    context.accent,
                                    context.accentSecondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: context.heroShadow,
                              ),
                              child: Icon(
                                Icons.mark_email_unread_outlined,
                                color: context.isDark
                                    ? const Color(0xFF0A0A14)
                                    : Colors.white,
                                size: 24,
                              ),
                            ),

                            const SizedBox(height: 28),

                            Text(
                              'Verify your email',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.textSecondary,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'We sent a verification link to\n',
                                  ),
                                  TextSpan(
                                    text: _email,
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Open the link in that email to activate your "
                              "account. This screen continues automatically once "
                              "you're verified.",
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Primary: I've verified
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _checking
                                    ? null
                                    : () => _checkVerified(),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.accent,
                                        context.accentSecondary,
                                        context.accent,
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: context.heroShadow,
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _checking
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white54,
                                            ),
                                          )
                                        : Text(
                                            "I've verified — Continue",
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: context.isDark
                                                  ? const Color(0xFF0A0A14)
                                                  : Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Resend (with cooldown)
                            Center(
                              child: TextButton(
                                onPressed: _resendCooldown > 0 ? null : _resend,
                                child: Text(
                                  _resendCooldown > 0
                                      ? 'Resend email in ${_resendCooldown}s'
                                      : 'Resend verification email',
                                  style: TextStyle(
                                    color: _resendCooldown > 0
                                        ? context.textSecondary
                                        : context.accentStrong,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Switch account
                            Center(
                              child: TextButton(
                                onPressed: _useDifferentEmail,
                                child: Text(
                                  'Use a different email',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      );
}
