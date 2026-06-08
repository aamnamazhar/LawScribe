import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart';
import '../theme_provider.dart';

class MessageInputBar extends StatefulWidget {
  final void Function(String, PlatformFile?, String?) onSend;
  const MessageInputBar({super.key, required this.onSend});

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showEmojiPicker = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text, null, null);
    _controller.clear();
    setState(() => _hasText = false);
    _focusNode.requestFocus();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
      );
      if (result != null && result.files.isNotEmpty) {
        widget.onSend('', result.files.first, null);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Could not open file picker. Please try again.');
    }
  }

  void _toggleEmoji() {
    setState(() => _showEmojiPicker = !_showEmojiPicker);
    if (_showEmojiPicker) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onMicTap() {
    _showSnackbar('Voice recording coming soon.');
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: context.accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.textPrimary, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: context.popupColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: context.accent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
      _sendMessage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji picker
        if (_showEmojiPicker)
          SizedBox(
            height: 260,
            child: EmojiPicker(
              onEmojiSelected: (_, emoji) {
                final pos = _controller.selection.baseOffset;
                final text = _controller.text;
                final newText = pos < 0
                    ? text + emoji.emoji
                    : text.substring(0, pos) +
                          emoji.emoji +
                          text.substring(pos);
                _controller.text = newText;
                _controller.selection = TextSelection.collapsed(
                  offset: (pos < 0 ? newText.length : pos + emoji.emoji.length),
                );
              },
              config: Config(
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: context.cardColor,
                  emojiSizeMax: 28,
                ),
                categoryViewConfig: CategoryViewConfig(
                  iconColor: context.textSecondary,
                  iconColorSelected: context.accent,
                  indicatorColor: context.accent,
                ),
                skinToneConfig: SkinToneConfig(
                  dialogBackgroundColor: context.popupColor,
                  indicatorColor: context.accent,
                ),
              ),
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: context.appBarColor,
            border: Border(
              top: BorderSide(color: context.borderColor, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? context.accent.withValues(alpha: 0.4)
                      : context.borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach file button
                  _InputIconButton(
                    icon: Icons.attach_file_rounded,
                    tooltip: 'Attach document',
                    onTap: _pickFile,
                  ),

                  // Text field
                  Expanded(
                    child: Focus(
                      focusNode: _focusNode,
                      onKeyEvent: _handleKeyPress,
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Message LawScribe...',
                          hintStyle: TextStyle(
                            color: context.textHint,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Emoji button
                  _InputIconButton(
                    icon: _showEmojiPicker
                        ? Icons.keyboard_rounded
                        : Icons.emoji_emotions_outlined,
                    tooltip: 'Emoji',
                    onTap: _toggleEmoji,
                    active: _showEmojiPicker,
                  ),

                  // Mic button
                  _InputIconButton(
                    icon: Icons.mic_none_rounded,
                    tooltip: 'Voice message',
                    onTap: _onMicTap,
                  ),

                  const SizedBox(width: 4),

                  // Send button — circular, icon only
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _hasText
                          ? LinearGradient(
                              colors: [context.accent, context.accentSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: _hasText ? null : context.progressBg,
                      shape: BoxShape.circle,
                      boxShadow: _hasText ? context.heroShadow : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _hasText ? _sendMessage : null,
                        child: Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: _hasText
                                ? (context.isDark
                                    ? const Color(0xFF0A0A14)
                                    : Colors.white)
                                : context.textHint,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── INPUT ICON BUTTON ─────────────────────────────────────────────────────────

class _InputIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _InputIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_InputIconButton> createState() => _InputIconButtonState();
}

class _InputIconButtonState extends State<_InputIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = _hover || widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? context.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: isHighlighted
                  ? context.accent
                  : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
