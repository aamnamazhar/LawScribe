import 'package:flutter/material.dart';
import '../theme_provider.dart';

class ChatBubble extends StatelessWidget {
  final bool isUser;
  final String label;
  final String? message;
  final String? fileName;
  final String? fileSize;
  final String time;
  final bool delivered;
  final bool isTyping;

  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDislike;
  final VoidCallback? onShare;

  const ChatBubble({
    super.key,
    required this.isUser,
    required this.label,
    this.message,
    this.fileName,
    this.fileSize,
    required this.time,
    this.delivered = false,
    this.isTyping = false,
    this.onCopy,
    this.onEdit,
    this.onDislike,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser) ...[
            _Avatar(label: label, isUser: false),
            const SizedBox(width: 10),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Bubble ───────────────────────────────────────────────
                Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    // User: purple tint. AI: warm cream/dark card.
                    gradient: isUser
                        ? LinearGradient(
                            colors: context.isDark
                                ? [
                                    const Color(0xFF1E1530),
                                    const Color(0xFF1A1228),
                                  ]
                                : [
                                    const Color(0xFFF0EBF7),
                                    const Color(0xFFE8E0F4),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: context.isDark
                                ? [
                                    const Color(0xFF12122A),
                                    const Color(0xFF0F0F22),
                                  ]
                                : [
                                    const Color(0xFFFFFDF8),
                                    const Color(0xFFFAF7F0),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isUser
                          ? (context.isDark
                              ? const Color(0xFF7B5EA7).withValues(alpha: 0.30)
                              : const Color(0xFF7B5EA7).withValues(alpha: 0.15))
                          : (context.isDark
                              ? context.accent.withValues(alpha: 0.10)
                              : context.accent.withValues(alpha: 0.12)),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF7B5EA7).withValues(alpha: context.isDark ? 0.15 : 0.08)
                            : Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                      if (!context.isDark && !isUser)
                        BoxShadow(
                          color: context.accent.withValues(alpha: 0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI label inside bubble
                      if (!isUser && !isTyping)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.accent,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LawScribe AI',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.accent
                                      .withValues(alpha: 0.7),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Typing indicator
                      if (isTyping)
                        _TypingIndicator()
                      // File bubble
                      else if (fileName != null)
                        _FileBubble(
                          fileName: fileName!,
                          fileSize: fileSize ?? '0',
                        )
                      // Text message
                      else if (message != null)
                        Text(
                          message!,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),

                      const SizedBox(height: 6),

                      // Time + delivered
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                          if (isUser && delivered)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 13,
                                color: context.accent
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // ── Action buttons ───────────────────────────────────────
                Row(
                  mainAxisAlignment:
                      isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: isUser
                      ? [
                          if (onCopy != null)
                            _ActionIcon(
                              icon: Icons.copy_outlined,
                              tooltip: 'Copy',
                              onTap: onCopy!,
                            ),
                          if (onEdit != null)
                            _ActionIcon(
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit',
                              onTap: onEdit!,
                            ),
                        ]
                      : [
                          if (onDislike != null)
                            _ActionIcon(
                              icon: Icons.thumb_down_alt_outlined,
                              tooltip: 'Dislike',
                              onTap: onDislike!,
                            ),
                          if (onCopy != null)
                            _ActionIcon(
                              icon: Icons.copy_outlined,
                              tooltip: 'Copy',
                              onTap: onCopy!,
                            ),
                          if (onShare != null)
                            _ActionIcon(
                              icon: Icons.share_outlined,
                              tooltip: 'Share',
                              onTap: onShare!,
                            ),
                        ],
                ),
              ],
            ),
          ),

          // User avatar
          if (isUser) ...[
            const SizedBox(width: 10),
            _Avatar(label: label, isUser: true),
          ],
        ],
      ),
    );
  }
}

// ── AVATAR ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String label;
  final bool isUser;

  const _Avatar({required this.label, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isUser
              ? [const Color(0xFF7B5EA7), const Color(0xFF9B7EC7)]
              : [context.accent, context.accentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isUser ? const Color(0xFF7B5EA7) : context.accent)
                    .withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0A0A14),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── FILE BUBBLE ───────────────────────────────────────────────────────────────

class _FileBubble extends StatelessWidget {
  final String fileName;
  final String fileSize;

  const _FileBubble({required this.fileName, required this.fileSize});

  @override
  Widget build(BuildContext context) {
    final isPdf = fileName.toLowerCase().endsWith('.pdf');
    final accentColor =
        isPdf ? context.accent : const Color(0xFF4A90D9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: context.isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.20),
                  accentColor.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined,
              size: 18,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$fileSize KB',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── TYPING INDICATOR ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Smooth, staggered 0→1→0 pulse for each dot (smoothstep-eased).
  double _pulse(int i, double t) {
    var phase = (t - i * 0.18) % 1.0;
    if (phase < 0) phase += 1.0;
    final tri = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
    return tri * tri * (3 - 2 * tri); // smoothstep
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            final p = _pulse(i, _controller.value);
            return Transform.translate(
              offset: Offset(0, -3 * p),
              child: Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.accent.withValues(alpha: 0.35 + 0.65 * p),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── ACTION ICON ───────────────────────────────────────────────────────────────

class _ActionIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: _hover ? context.borderColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hover ? context.accent : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
