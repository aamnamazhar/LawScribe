import 'package:flutter/material.dart';

class HeaderAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HeaderAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<HeaderAction> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isHovering ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
