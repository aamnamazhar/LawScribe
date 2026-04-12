import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  final bool asDrawer;
  const SettingsScreen({Key? key, this.asDrawer = false}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  User? currentUser;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // If inside a drawer, close it first, then navigate from the root.
    if (widget.asDrawer) {
      Navigator.pop(context); // close drawer
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  void toggleTheme() {
    final newMode = themeNotifier.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    themeNotifier.value = newMode;
    saveTheme(newMode);
  }

  /// Placeholder for chat search. Real cross-conversation search needs message
  /// persistence (Firestore-backed history), which we don't have yet — so for
  /// now we just nudge the user toward the chat screen.
  void _openSearchChats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Search Chats',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          "Cross-chat search isn't ready yet — your conversations live only "
          "in the current session. Open a chat and ask me anything about "
          "your contract directly.",
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Close',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/chat');
            },
            child: const Text(
              'Open Chat',
              style: TextStyle(
                color: Color(0xFFD4AF6A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder privacy policy dialog. Replace the body text with the real
  /// policy when you have one — the layout stays the same.
  void _openPrivacyPolicy() {
    const policyText =
        'LawScribe processes the documents you upload solely to provide '
        'AI-powered summaries, clause detection, and Q&A.\n\n'
        '• Documents are sent to our backend for analysis and stored '
        'temporarily so the AI can answer follow-up questions about them.\n\n'
        '• Your account information (name, email) is managed by Firebase '
        'Authentication and is never shared with third parties.\n\n'
        '• Document content is processed by third-party AI providers '
        '(Groq) to generate responses. No personally identifying '
        'information is attached to those requests.\n\n'
        '• You can delete your account at any time, which removes all '
        'associated data from our systems.\n\n'
        'For questions about your data, contact the LawScribe team.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.security_outlined,
              color: Color(0xFFD4AF6A),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Privacy Policy',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Text(
              policyText,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFFD4AF6A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U';

    final body = Stack(
      children: [
        // Ambient glow — top left
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7B5EA7).withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Ambient glow — bottom right
        Positioned(
          bottom: -40,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFC9A84C).withOpacity(0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= USER CARD =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar with gold ring
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF6A), Color(0xFFF5D98B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFD4AF6A,
                                ).withOpacity(0.30),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: context.popupColor,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD4AF6A),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Logged in as',
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentUser?.email ?? 'User',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Online badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF82).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF4CAF82).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Color(0xFF4CAF82),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ================= CHATS =================
                  _sectionTitle('Chats'),
                  _settingsTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Your Chats',
                    subtitle: 'View all conversations',
                    onTap: () {
                      if (widget.asDrawer) {
                        Navigator.pop(
                          context,
                        ); // close drawer, chat is behind it
                      } else {
                        Navigator.pushNamed(context, '/chat');
                      }
                    },
                  ),
                  _settingsTile(
                    icon: Icons.search_rounded,
                    title: 'Search Chats',
                    subtitle: 'Find messages quickly',
                    onTap: _openSearchChats,
                  ),

                  const SizedBox(height: 28),

                  // ================= APPEARANCE =================
                  _sectionTitle('Appearance'),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (_, mode, __) {
                      return _settingsTile(
                        icon: mode == ThemeMode.light
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        title: mode == ThemeMode.light
                            ? 'Light Mode'
                            : 'Dark Mode',
                        subtitle: 'Switch app theme',
                        onTap: toggleTheme,
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ================= ABOUT =================
                  _sectionTitle('About'),
                  _settingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'App Version',
                    subtitle: 'v1.0.0',
                    onTap: () {},
                  ),
                  _settingsTile(
                    icon: Icons.security_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'Read our privacy policy',
                    onTap: _openPrivacyPolicy,
                  ),

                  const SizedBox(height: 28),

                  // ================= ACCOUNT =================
                  _sectionTitle('Account'),
                  _settingsTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Sign out from your account',
                    onTap: logout,
                    isDanger: true,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    // When used inside a Drawer, skip the Scaffold/AppBar wrapper.
    if (widget.asDrawer) {
      return Container(
        color: context.bgColor,
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: context.appBarColor,
              border: Border(
                bottom: BorderSide(color: context.borderColor, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B5EA7).withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: context.textSecondary,
              size: 18,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF6A), Color(0xFFF5D98B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDanger
              ? Colors.redAccent.withOpacity(0.15)
              : context.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: isDanger
              ? Colors.redAccent.withOpacity(0.08)
              : const Color(0xFFD4AF6A).withOpacity(0.06),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDanger
                        ? Colors.redAccent.withOpacity(0.10)
                        : const Color(0xFF7B5EA7).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: isDanger
                        ? Colors.redAccent.withOpacity(0.85)
                        : const Color(0xFFD4AF6A).withOpacity(0.85),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDanger
                              ? Colors.redAccent.withOpacity(0.85)
                              : context.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
