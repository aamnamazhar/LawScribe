import 'package:flutter/material.dart';

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
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: hovering ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(widget.icon, color: Colors.white),
            onPressed: widget.onTap,
          ),
        ),
      ),
    );
  }
}
