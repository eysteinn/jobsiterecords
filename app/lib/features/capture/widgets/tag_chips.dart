import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/models/tag.dart';

class TagChips extends StatelessWidget {
  const TagChips({
    super.key,
    required this.allTags,
    required this.selectedIds,
    required this.onToggle,
    this.partialIds = const {},
    this.onAddTag,
  });
  final List<Tag> allTags;
  final Set<String> selectedIds;
  final Set<String> partialIds;
  final ValueChanged<String> onToggle;
  final VoidCallback? onAddTag;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in allTags)
          _Chip(
            label: t.name,
            selected: selectedIds.contains(t.id),
            partial: partialIds.contains(t.id),
            onTap: () => onToggle(t.id),
          ),
        if (onAddTag != null)
          ActionChip(
            avatar: const Icon(Icons.add, size: 14),
            label: const Text('Add Tag'),
            onPressed: onAddTag,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.partial,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool partial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.accent
        : partial
            ? AppColors.accent.withValues(alpha: 0.35)
            : const Color(0xFFF3F4F6);
    final border = selected
        ? AppColors.accent
        : partial
            ? AppColors.accent
            : const Color(0xFFE5E7EB);
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: border,
          width: partial && !selected ? 1.5 : 1,
          style: partial && !selected ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (partial && !selected) ...[
                const Icon(Icons.remove, size: 12, color: AppColors.ink),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> showAddTagDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New tag'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Plumbing'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
