import 'package:flutter/material.dart';
import 'elite_card.dart';

class EliteDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget>? actions;
  final Color? glowColor;

  const EliteDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.glowColor,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    Color? glowColor,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: EliteDialog(
            title: title,
            content: content,
            actions: actions,
            glowColor: glowColor,
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: EliteCard(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        glowColor: glowColor ?? Theme.of(context).colorScheme.primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: content)),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions!.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: a,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
