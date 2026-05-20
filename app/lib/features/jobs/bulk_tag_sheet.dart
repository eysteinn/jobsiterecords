import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/timeline_item.dart';
import '../../domain/models/timeline_query.dart';
import '../capture/widgets/tag_chips.dart';

/// Tag coverage across a multi-item selection.
({Set<String> all, Set<String> partial}) tagCoverageForSelection(
  List<TimelineItem> timeline,
  Set<String> selectedItemIds,
) {
  final itemTags = <String, Set<String>>{};
  for (final t in timeline) {
    if (selectedItemIds.contains(t.item.id)) {
      itemTags[t.item.id] = t.tags.map((e) => e.id).toSet();
    }
  }
  return tagCoverageForItemTags(itemTags, selectedItemIds);
}

({Set<String> all, Set<String> partial}) tagCoverageForItemTags(
  Map<String, Set<String>> itemTags,
  Set<String> selectedItemIds,
) {
  final all = <String>{};
  final partial = <String>{};
  final selected = selectedItemIds.toList();
  if (selected.isEmpty) return (all: all, partial: partial);

  final tagIds = <String>{};
  for (final itemId in selected) {
    tagIds.addAll(itemTags[itemId] ?? const {});
  }

  for (final tagId in tagIds) {
    var count = 0;
    for (final itemId in selected) {
      if (itemTags[itemId]?.contains(tagId) ?? false) count++;
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
  Map<String, Set<String>>? _pendingItemTags;
  Map<String, Set<String>>? _originalItemTags;
  bool _busy = false;

  void _initPending(List<TimelineItem> timeline) {
    if (_pendingItemTags != null) return;
    final original = <String, Set<String>>{};
    for (final t in timeline) {
      if (widget.selectedItemIds.contains(t.item.id)) {
        original[t.item.id] = t.tags.map((e) => e.id).toSet();
      }
    }
    _originalItemTags = {
      for (final e in original.entries) e.key: Set<String>.from(e.value),
    };
    _pendingItemTags = {
      for (final e in original.entries) e.key: Set<String>.from(e.value),
    };
  }

  void _toggleTag(String tagId) {
    if (_pendingItemTags == null) return;
    final coverage = tagCoverageForItemTags(_pendingItemTags!, widget.selectedItemIds);
    final allHaveTag = coverage.all.contains(tagId);
    setState(() {
      for (final itemId in widget.selectedItemIds) {
        final tags = _pendingItemTags![itemId]!;
        if (allHaveTag) {
          tags.remove(tagId);
        } else {
          tags.add(tagId);
        }
      }
    });
  }

  Future<void> _addTag() async {
    final name = await showAddTagDialog(context);
    if (name == null || name.isEmpty || !mounted) return;
    final tag = await ref.read(tagsRepositoryProvider).create(name);
    bumpDataRevision(ref);
    if (!mounted || _pendingItemTags == null) return;
    setState(() {
      for (final itemId in widget.selectedItemIds) {
        _pendingItemTags![itemId]!.add(tag.id);
      }
    });
  }

  Future<void> _applyAndClose() async {
    if (_busy) return;
    if (_pendingItemTags == null || _originalItemTags == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final toAdd = <String, List<String>>{};
    final toRemove = <String, List<String>>{};
    for (final itemId in widget.selectedItemIds) {
      final original = _originalItemTags![itemId] ?? const {};
      final pending = _pendingItemTags![itemId] ?? const {};
      for (final tagId in pending.difference(original)) {
        (toAdd[tagId] ??= []).add(itemId);
      }
      for (final tagId in original.difference(pending)) {
        (toRemove[tagId] ??= []).add(itemId);
      }
    }

    if (toAdd.isEmpty && toRemove.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(itemsRepositoryProvider);
    try {
      for (final entry in toAdd.entries) {
        await repo.addTagToItems(itemIds: entry.value, tagId: entry.key);
      }
      for (final entry in toRemove.entries) {
        await repo.removeTagFromItems(itemIds: entry.value, tagId: entry.key);
      }
      bumpDataRevision(ref);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.selectedItemIds.length;
    final tagsAsync = ref.watch(tagsProvider);
    final timelineAsync = ref.watch(jobTimelineProvider((jobId: widget.jobId, query: TimelineQuery.empty)));

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
              'Tap tags to choose changes. Press Done to apply.',
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
                  _initPending(timeline);
                  final coverage = tagCoverageForItemTags(_pendingItemTags!, widget.selectedItemIds);
                  return tagsAsync.when(
                    data: (tags) => TagChips(
                      allTags: tags,
                      selectedIds: coverage.all,
                      partialIds: coverage.partial,
                      onToggle: _toggleTag,
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
                onPressed: _busy ? null : _applyAndClose,
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
