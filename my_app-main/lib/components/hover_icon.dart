import 'package:flutter/material.dart';
import '../theme_provider.dart';

class HoverIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const HoverIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<HoverIcon> createState() => _HoverIconState();
}

class _HoverIconState extends State<HoverIcon> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = hovering
        ? context.accent
        : context.textPrimary;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: hovering
                ? context.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(widget.icon, color: iconColor, size: 22),
            onPressed: widget.onTap,
          ),
        ),
      ),
    );
  }
}
