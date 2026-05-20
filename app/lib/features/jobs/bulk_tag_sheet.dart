import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/timeline_item.dart';
import '../capture/widgets/tag_chips.dart';

/// Tag coverage across a multi-item selection.
({Set<String> all, Set<String> partial}) tagCoverageForSelection(
  List<TimelineItem> timeline,
  Set<String> selectedItemIds,
) {
  final all = <String>{};
  final partial = <String>{};
  final selected = timeline.where((t) => selectedItemIds.contains(t.item.id)).toList();
  if (selected.isEmpty) return (all: all, partial: partial);

  final tagIds = <String>{};
  for (final t in selected) {
    for (final tag in t.tags) {
      tagIds.add(tag.id);
    }
  }

  for (final tagId in tagIds) {
    var count = 0;
    for (final t in selected) {
      if (t.tags.any((tag) => tag.id == tagId)) count++;
    }
    if (count == selected.length) {
      all.add(tagId);
    } else {
      partial.add(tagId);
    }
  }
  return (all: all, partial: partial);
}

Future<void> showBulkTagSheet({
  required BuildContext context,
  required String jobId,
  required Set<String> selectedItemIds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BulkTagSheet(jobId: jobId, selectedItemIds: selectedItemIds),
  );
}

class _BulkTagSheet extends ConsumerStatefulWidget {
  const _BulkTagSheet({required this.jobId, required this.selectedItemIds});
  final String jobId;
  final Set<String> selectedItemIds;

  @override
  ConsumerState<_BulkTagSheet> createState() => _BulkTagSheetState();
}

class _BulkTagSheetState extends ConsumerState<_BulkTagSheet> {
  bool _busy = false;

  Future<void> _toggleTag(String tagId, {required bool allHaveTag}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(itemsRepositoryProvider);
    final ids = widget.selectedItemIds.toList();
    try {
      if (allHaveTag) {
        await repo.removeTagFromItems(itemIds: ids, tagId: tagId);
      } else {
        await repo.addTagToItems(itemIds: ids, tagId: tagId);
      }
      bumpDataRevision(ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addTag() async {
    final name = await showAddTagDialog(context);
    if (name == null || name.isEmpty || !mounted) return;
    final tag = await ref.read(tagsRepositoryProvider).create(name);
    bumpDataRevision(ref);
    if (!mounted) return;
    await _toggleTag(tag.id, allHaveTag: false);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.selectedItemIds.length;
    final tagsAsync = ref.watch(tagsProvider);
    final timelineAsync = ref.watch(jobTimelineProvider(widget.jobId));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tags for $n item${n == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to add or remove on all selected items.',
              style: TextStyle(color: AppColors.subtle, fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              timelineAsync.when(
                data: (timeline) {
                  final coverage = tagCoverageForSelection(timeline, widget.selectedItemIds);
                  return tagsAsync.when(
                    data: (tags) => TagChips(
                      allTags: tags,
                      selectedIds: coverage.all,
                      partialIds: coverage.partial,
                      onToggle: (id) => _toggleTag(id, allHaveTag: coverage.all.contains(id)),
                      onAddTag: _addTag,
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
