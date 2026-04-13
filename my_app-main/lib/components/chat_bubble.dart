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
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          if (!isUser) ...[
            _Avatar(label: label, isUser: false),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? (context.isDark
                            ? const Color(0xFF1E1530)
                            : const Color(0xFFEDE7F6))
                        : context.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isUser
                          ? const Color(0xFF7B5EA7).withValues(alpha: 0.35)
                          : context.borderColor,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF7B5EA7).withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            height: 1.5,
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
                                color: const Color(0xFFD4AF6A).withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Action buttons
                Row(
                  mainAxisAlignment: isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
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
            const SizedBox(width: 8),
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
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isUser
              ? [const Color(0xFF7B5EA7), const Color(0xFF9B7EC7)]
              : [const Color(0xFFD4AF6A), const Color(0xFFF5D98B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUser ? const Color(0xFF7B5EA7) : const Color(0xFFD4AF6A))
                .withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPdf
                  ? const Color(0xFFD4AF6A).withValues(alpha: 0.12)
                  : const Color(0xFF4A90D9).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined,
              size: 16,
              color: isPdf ? const Color(0xFFD4AF6A) : const Color(0xFF4A90D9),
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
                    fontWeight: FontWeight.w500,
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
    // Single controller looping every 1.2s. Dots are phase-offset within the
    // build method so all three pulse continuously, staggered, without any
    // delayed forward() races.
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

  /// Triangle wave opacity for dot [i] given controller progress [t] in [0, 1).
  /// Each dot is offset by 1/3 of the cycle, so they pulse in sequence.
  double _dotOpacity(int i, double t) {
    final phase = (t + i / 3.0) % 1.0;
    final tri = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
    return 0.25 + tri * 0.75; // floor at 0.25 so dots never fully vanish
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (i) {
            final opacity = _dotOpacity(i, _controller.value);
            return Container(
              width: 9,
              height: 9,
              margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF6A).withValues(alpha: opacity),
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
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hover
                  ? const Color(0xFFD4AF6A)
                  : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
