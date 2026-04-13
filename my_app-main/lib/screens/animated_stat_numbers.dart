import 'package:flutter/material.dart';

class AnimatedStatNumber extends StatefulWidget {
  final double value;
  final TextStyle? style;
  final Duration duration;
  final String suffix;

  const AnimatedStatNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.suffix = '',
  });

  @override
  State<AnimatedStatNumber> createState() => _AnimatedStatNumberState();
}

class _AnimatedStatNumberState extends State<AnimatedStatNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) {
        return Text(
          '${_formatNumber(_animation.value)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}
