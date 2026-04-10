import 'package:flutter/material.dart';

class AppBarHoverIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const AppBarHoverIcon({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  State<AppBarHoverIcon> createState() => _AppBarHoverIconState();
}

class _AppBarHoverIconState extends State<AppBarHoverIcon> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).iconTheme.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _hovering
              ? Theme.of(context).dividerColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(widget.icon, color: color),
          onPressed: widget.onTap,
          splashRadius: 22,
        ),
      ),
    );
  }
}
