import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/tag.dart';
import '../../../domain/models/timeline_query.dart';

/// Bottom sheet for advanced timeline filters (type, tags, date range, sort).
Future<TimelineQuery?> showTimelineFilterSheet({
  required BuildContext context,
  required TimelineQuery query,
  required Set<String> tagsInJob,
}) {
  return showModalBottomSheet<TimelineQuery>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TimelineFilterSheet(
      initialQuery: query,
      tagsInJob: tagsInJob,
    ),
  );
}

class _TimelineFilterSheet extends ConsumerStatefulWidget {
  const _TimelineFilterSheet({
    required this.initialQuery,
    required this.tagsInJob,
  });

  final TimelineQuery initialQuery;
  final Set<String> tagsInJob;

  @override
  ConsumerState<_TimelineFilterSheet> createState() => _TimelineFilterSheetState();
}

class _TimelineFilterSheetState extends ConsumerState<_TimelineFilterSheet> {
  late TimelineQuery _query;
  final _tagSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  void dispose() {
    _tagSearchCtrl.dispose();
    super.dispose();
  }

  void _toggleKind(ItemKind kind) {
    final kinds = Set<ItemKind>.of(_query.kinds);
    if (!kinds.add(kind)) kinds.remove(kind);
    setState(() => _query = _query.copyWith(kinds: kinds));
  }

  void _toggleTag(String tagId) {
    final tagIds = Set<String>.of(_query.tagIds);
    if (!tagIds.add(tagId)) tagIds.remove(tagId);
    setState(() => _query = _query.copyWith(tagIds: tagIds));
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _query.fromDate : _query.toDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _query = isFrom
          ? _query.copyWith(fromDate: picked)
          : _query.copyWith(toDate: picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final allTags = tagsAsync.valueOrNull ?? const <Tag>[];
    final tagFilter = _tagSearchCtrl.text.trim().toLowerCase();
    final jobTags = allTags
        .where((t) => widget.tagsInJob.contains(t.id))
        .where((t) => tagFilter.isEmpty || t.name.toLowerCase().contains(tagFilter))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter timeline',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.subtle)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ItemKind.values)
                    FilterChip(
                      label: Text(_kindLabel(kind)),
                      selected: _query.kinds.contains(kind),
                      onSelected: (_) => _toggleKind(kind),
                      showCheckmark: false,
                      selectedColor: AppColors.accentSoft,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.subtle)),
              const SizedBox(height: 8),
              TextField(
                controller: _tagSearchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search tags',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
              if (jobTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in jobTags)
                      FilterChip(
                        label: Text(tag.name),
                        selected: _query.tagIds.contains(tag.id),
                        onSelected: (_) => _toggleTag(tag.id),
                        showCheckmark: false,
                        selectedColor: AppColors.accentSoft,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text('Date range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.subtle)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isFrom: true),
                      child: Text(
                        _query.fromDate == null
                            ? 'From'
                            : _formatShortDate(_query.fromDate!),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(isFrom: false),
                      child: Text(
                        _query.toDate == null ? 'To' : _formatShortDate(_query.toDate!),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Sort', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.subtle)),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Newest')),
                  ButtonSegment(value: true, label: Text('Oldest')),
                ],
                selected: {_query.sortOldest},
                onSelectionChanged: (s) => setState(() => _query = _query.copyWith(sortOldest: s.first)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, TimelineQuery.empty),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _query),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _kindLabel(ItemKind kind) => switch (kind) {
      ItemKind.photo => 'Photos',
      ItemKind.voice => 'Voice',
      ItemKind.note => 'Notes',
      ItemKind.file => 'Files',
    };

String _formatShortDate(DateTime d) {
  return '${d.month}/${d.day}/${d.year}';
}
