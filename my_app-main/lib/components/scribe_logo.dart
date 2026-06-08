import 'package:flutter/material.dart';

/// Just the brand mark — the dot + slanted bar from the LawScribe logo, with no
/// wordmark. Drop it into badges/avatars in place of a generic icon.
class ScribeMark extends StatelessWidget {
  final double size;
  final Color color;

  const ScribeMark({super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dot
          Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: size * 0.12),
          // Slanted bar
          Transform.rotate(
            angle: -0.4,
            child: Container(
              width: size * 0.22,
              height: size * 0.66,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size * 0.16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScribeLogo extends StatefulWidget {
  final double height;
  /// Force the wordmark color regardless of theme (e.g. splash always dark bg).
  final Color? forcedTextColor;

  const ScribeLogo({super.key, this.height = 40, this.forcedTextColor});

  @override
  State<ScribeLogo> createState() => _ScribeLogoState();
}

class _ScribeLogoState extends State<ScribeLogo> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF4C8DFF);
    // Adapt the wordmark color to the active theme so it stays visible on
    // both the dark (#0F0F22) and light (#FFFFFF) app bar backgrounds.
    final textColor = widget.forcedTextColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF0D0D1A));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedScale(
        scale: hovering ? 1.05 : 1,
        duration: const Duration(milliseconds: 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot
            Container(
              width: widget.height * 0.22,
              height: widget.height * 0.22,
              decoration: const BoxDecoration(
                color: brandBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),

            // Slanted bar
            Transform.rotate(
              angle: -0.4,
              child: Container(
                width: widget.height * 0.2,
                height: widget.height * 0.6,
                decoration: BoxDecoration(
                  color: brandBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Text — adapts to theme
            Text(
              "Scribe",
              style: TextStyle(
                color: textColor,
                fontSize: widget.height * 0.7,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
