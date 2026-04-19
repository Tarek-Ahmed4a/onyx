import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

class EliteHeader extends StatelessWidget {
  final String title;
  final bool showGreeting;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const EliteHeader({
    super.key,
    required this.title,
    this.showGreeting = true,
    this.showBackButton = false,
    this.onBack,
    this.actions,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  String _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '⛅';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Onyx User';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onBack ?? () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (!showGreeting && actions != null) 
                  Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (showGreeting) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreetingIcon()} ${_getGreeting()}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (actions != null) ...actions!,
              ],
            ),
            const SizedBox(height: 1),
            Shimmer.fromColors(
              baseColor: Colors.white,
              highlightColor: Colors.white.withValues(alpha: 0.5),
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
              if (!showGreeting && !showBackButton && actions != null) 
                Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ],
          ),
        ],
      ),
    );
  }
}
