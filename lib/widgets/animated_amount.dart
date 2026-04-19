import 'package:flutter/material.dart';

class AnimatedAmount extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final int precision;

  const AnimatedAmount({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.precision = 2,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutExpo,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(precision)}$suffix',
          style: style,
        );
      },
    );
  }
}
