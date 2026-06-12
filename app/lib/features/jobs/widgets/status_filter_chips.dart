import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/models/job.dart';

/// Horizontal status filter chips with count badges (web mobile parity).
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({
    super.key,
    required this.jobs,
    required this.activeStatus,
    required this.onSelect,
  });

  final List<Job> jobs;
  final JobStatus? activeStatus;
  final ValueChanged<JobStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = {
      JobStatus.planning: jobs.where((j) => j.status == JobStatus.planning).length,
      JobStatus.inProgress: jobs.where((j) => j.status == JobStatus.inProgress).length,
      JobStatus.completed: jobs.where((j) => j.status == JobStatus.completed).length,
    };

    final chips = <({String label, JobStatus? status, int count})>[
      (label: 'All', status: null, count: jobs.length),
      (label: 'In Progress', status: JobStatus.inProgress, count: counts[JobStatus.inProgress]!),
      (label: 'Completed', status: JobStatus.completed, count: counts[JobStatus.completed]!),
      (label: 'Planning', status: JobStatus.planning, count: counts[JobStatus.planning]!),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final chip in chips) ...[
            _Chip(
              label: chip.label,
              count: chip.count,
              active: activeStatus == chip.status,
              onTap: () => onSelect(chip.status),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accentSoft : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? AppColors.accent : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.ink : AppColors.subtle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
