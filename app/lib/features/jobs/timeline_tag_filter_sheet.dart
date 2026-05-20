import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../capture/widgets/tag_chips.dart';

Future<Set<String>?> showTimelineTagFilterSheet({
  required BuildContext context,
  required Set<String> selectedTagIds,
  Set<String> tagsInJob = const {},
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TimelineTagFilterSheet(
      initialSelected: selectedTagIds,
      tagsInJob: tagsInJob,
    ),
  );
}

class _TimelineTagFilterSheet extends ConsumerStatefulWidget {
  const _TimelineTagFilterSheet({
    required this.initialSelected,
    required this.tagsInJob,
  });

  final Set<String> initialSelected;
  final Set<String> tagsInJob;

  @override
  ConsumerState<_TimelineTagFilterSheet> createState() => _TimelineTagFilterSheetState();
}

class _TimelineTagFilterSheetState extends ConsumerState<_TimelineTagFilterSheet> {
  late Set<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.initialSelected);
  }

  void _toggle(String tagId) {
    setState(() {
      if (!_selected.add(tagId)) _selected.remove(tagId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Text(
              'Filter by tag',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Show items that have any of the selected tags.',
              style: TextStyle(color: AppColors.subtle, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search tags',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: tagsAsync.when(
                  data: (allTags) {
                    final filtered = allTags.where((t) {
                      if (_search.isEmpty) return true;
                      return t.name.toLowerCase().contains(_search);
                    }).toList();

                    final inJob = filtered.where((t) => widget.tagsInJob.contains(t.id)).toList();
                    final other = filtered.where((t) => !widget.tagsInJob.contains(t.id)).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No tags match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.subtle),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (inJob.isNotEmpty) ...[
                          const Text(
                            'In this job',
                            style: TextStyle(
                              color: AppColors.subtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TagChips(
                            allTags: inJob,
                            selectedIds: _selected,
                            onToggle: _toggle,
                          ),
                          if (other.isNotEmpty) const SizedBox(height: 16),
                        ],
                        if (other.isNotEmpty) ...[
                          if (inJob.isNotEmpty)
                            const Text(
                              'All tags',
                              style: TextStyle(
                                color: AppColors.subtle,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (inJob.isNotEmpty) const SizedBox(height: 8),
                          TagChips(
                            allTags: other,
                            selectedIds: _selected,
                            onToggle: _toggle,
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Clear'),
                  )
                else
                  const Spacer(),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(_selected.isEmpty ? 'Done' : 'Done (${_selected.length})'),
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
