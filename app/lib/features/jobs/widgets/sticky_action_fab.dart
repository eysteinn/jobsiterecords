import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Centered pill FAB above the bottom navigation bar, matching web mobile UX.
class StickyActionFab extends StatelessWidget {
  const StickyActionFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.bottomOffset = 80,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomOffset + MediaQuery.paddingOf(context).bottom,
      child: Center(
        child: Material(
          elevation: 4,
          shadowColor: AppColors.accent.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
          color: AppColors.accent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.ink, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
