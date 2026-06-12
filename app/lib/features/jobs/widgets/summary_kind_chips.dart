import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/models/item.dart';

/// Tappable kind summary chips for job detail timeline filtering.
class SummaryKindChips extends StatelessWidget {
  const SummaryKindChips({
    super.key,
    required this.totalItems,
    required this.photos,
    required this.notes,
    required this.voice,
    required this.files,
    required this.activeKind,
    required this.onSelect,
  });

  final int totalItems;
  final int photos;
  final int notes;
  final int voice;
  final int files;
  final ItemKind? activeKind;
  final ValueChanged<ItemKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    final chips = <({String label, ItemKind? kind, int count, IconData icon})>[
      (label: 'All', kind: null, count: totalItems, icon: Icons.menu_rounded),
      (label: 'Photos', kind: ItemKind.photo, count: photos, icon: Icons.photo_outlined),
      (label: 'Notes', kind: ItemKind.note, count: notes, icon: Icons.sticky_note_2_outlined),
      if (voice > 0)
        (label: 'Voice', kind: ItemKind.voice, count: voice, icon: Icons.mic_none),
      if (files > 0)
        (label: 'Files', kind: ItemKind.file, count: files, icon: Icons.insert_drive_file_outlined),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[
            _KindChip(
              label: chip.label,
              count: chip.count,
              icon: chip.icon,
              active: activeKind == chip.kind,
              onTap: () => onSelect(chip.kind),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Icon(icon, size: 16, color: active ? AppColors.ink : AppColors.subtle),
              const SizedBox(width: 6),
              Text(
                '$label $count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
