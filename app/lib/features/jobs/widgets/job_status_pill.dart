import 'package:flutter/material.dart';

import '../../../domain/models/job.dart';

/// Color-coded status pill matching web dashboard semantics.
class JobStatusPill extends StatelessWidget {
  const JobStatusPill({
    super.key,
    required this.status,
    this.showCheck = false,
    this.compact = false,
    this.onTap,
  });

  final JobStatus status;
  final bool showCheck;
  final bool compact;
  final VoidCallback? onTap;

  static (Color bg, Color fg) colorsFor(JobStatus status) => switch (status) {
        JobStatus.planning => (const Color(0xFFE5E7EB), const Color(0xFF374151)),
        JobStatus.inProgress => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
        JobStatus.completed => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colorsFor(status);
    final label = showCheck && status == JobStatus.completed ? '✓ ${status.label}' : status.label;
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      ),
    );
  }
}
