import 'dart:ui';
import 'package:flutter/material.dart';

class EliteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;
  final double? blur;

  const EliteCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.glowColor,
    this.blur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.3),
              blurRadius: 25,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur ?? 10, sigmaY: blur ?? 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: glowColor != null 
                  ? glowColor!.withValues(alpha: 0.15) 
                  : const Color(0xFF1E1E1E).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: glowColor != null 
                    ? glowColor!.withValues(alpha: 0.3) 
                    : Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
