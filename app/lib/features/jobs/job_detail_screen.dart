import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_runner.dart';
import '../../sync/sync_scheduler.dart';
import '../../core/format.dart';
import '../../domain/models/item.dart';
import '../../domain/models/job.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/timeline_item.dart';
import '../../domain/models/timeline_query.dart';
import 'bulk_tag_sheet.dart';
import 'timeline_day_content.dart';
import 'widgets/job_status_pill.dart';
import 'widgets/sticky_action_fab.dart';
import 'widgets/summary_kind_chips.dart';
import 'widgets/timeline_filter_sheet.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _deleting = false;
  final _searchCtrl = TextEditingController();
  TimelineQuery _query = TimelineQuery.empty;
  List<TimelineItem>? _timelineItems;
  Timer? _searchDebounce;
  final _searchFocusNode = FocusNode();
  bool _watchingJob = false;
  SyncScheduler? _syncScheduler;

  String get jobId => widget.jobId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(captureContextProvider).isWorkspace) {
        _syncScheduler = ref.read(syncSchedulerProvider);
        _syncScheduler!.beginWatchingJob();
        _watchingJob = true;
      }
    });
  }

  @override
  void dispose() {
    if (_watchingJob) _syncScheduler?.endWatchingJob();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _setQuery(TimelineQuery query) {
    if (_query == query) return;
    setState(() => _query = query);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final trimmed = value.trim();
      _setQuery(_query.copyWith(search: trimmed.isEmpty ? null : value, clearSearch: trimmed.isEmpty));
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _setQuery(_query.copyWith(clearSearch: true));
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _searchFocusNode.unfocus();
    setState(() => _query = TimelineQuery.empty);
  }

  void _selectKind(ItemKind? kind) {
    if (kind == null) {
      _setQuery(_query.copyWith(clearKinds: true));
    } else if (_query.activeKind == kind) {
      _setQuery(_query.copyWith(clearKinds: true));
    } else {
      _setQuery(_query.copyWith(kinds: {kind}));
    }
  }

  Future<void> _openFilterSheet(Set<String> tagsInJob) async {
    final result = await showTimelineFilterSheet(
      context: context,
      query: _query,
      tagsInJob: tagsInJob,
    );
    if (result == null || !mounted) return;
    _setQuery(result);
  }

  Future<void> _changeStatus(JobStatus next) async {
    final repo = ref.read(jobsRepositoryProvider);
    final job = await repo.byId(jobId);
    if (job != null && job.status != next) {
      await repo.update(job.copyWith(status: next));
      bumpDataRevision(ref);
      ref.invalidate(jobProvider(jobId));
    }
  }

  void _showStatusSheet(JobStatus current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in JobStatus.values)
              ListTile(
                leading: current == status ? const Icon(Icons.check, color: AppColors.accent) : const SizedBox(width: 24),
                title: Text(status.label),
                onTap: () {
                  Navigator.pop(context);
                  _changeStatus(status);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _enterSelection({String? initialItemId}) {
    setState(() {
      _selecting = true;
      _selected.clear();
      if (initialItemId != null) _selected.add(initialItemId);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String itemId) {
    setState(() {
      if (_selected.contains(itemId)) {
        _selected.remove(itemId);
      } else {
        _selected.add(itemId);
      }
    });
  }

  void _selectAll(Iterable<String> ids) {
    setState(() => _selected.addAll(ids));
  }

  void _openTagSheet() {
    if (_selected.isEmpty || _deleting) return;
    showBulkTagSheet(
      context: context,
      jobId: jobId,
      selectedItemIds: Set.unmodifiable(_selected),
    );
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    if (n == 0 || _deleting) return;
    final synced = ref.read(captureContextProvider).isWorkspace;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $n item${n == 1 ? '' : 's'}?'),
        content: Text(
          synced
              ? 'This removes the selected items from this job on all your devices. This cannot be undone.'
              : 'This permanently removes the selected items from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    final repo = ref.read(itemsRepositoryProvider);
    final ids = _selected.toList();
    try {
      for (final id in ids) {
        await repo.delete(id);
      }
      bumpDataRevision(ref);
      if (!mounted) return;
      _exitSelection();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $n item${n == 1 ? '' : 's'}')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobProvider(jobId));
    final summary = ref.watch(jobSummariesProvider).valueOrNull?[jobId];
    final allItemsAsync = ref.watch(jobTimelineProvider((jobId: jobId, query: TimelineQuery.empty)));
    final timelineKey = (jobId: jobId, query: _query);
    ref.listen(jobTimelineProvider(timelineKey), (_, next) {
      next.whenData((data) {
        if (!mounted || identical(_timelineItems, data)) return;
        setState(() => _timelineItems = data);
      });
    });
    final timelineAsync = ref.watch(jobTimelineProvider(timelineKey));
    final storage = ref.watch(mediaStorageProvider);
    final tagsInJob = allItemsAsync.maybeWhen(
      data: (items) => {
        for (final t in items) for (final tag in t.tags) tag.id,
      },
      orElse: () => const <String>{},
    );
    final items = timelineAsync.valueOrNull ?? _timelineItems ?? const <TimelineItem>[];
    final timelineLoading = items.isEmpty && timelineAsync.isLoading;
    final timelineRefreshing = items.isNotEmpty && timelineAsync.isLoading;
    final itemIds = items.map((t) => t.item.id);

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_selecting || _deleting) return;
        _exitSelection();
      },
      child: Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: _deleting ? null : _exitSelection,
              ),
              title: Text(
                _selected.isEmpty
                    ? 'Select items'
                    : '${_selected.length} selected',
              ),
              actions: [
                TextButton(
                  onPressed: _deleting ? null : () => _selectAll(itemIds),
                  child: const Text('All'),
                ),
              ],
            )
          : AppBar(
              title: jobAsync.maybeWhen(
                data: (j) => Text(j?.name ?? 'Job', maxLines: 1, overflow: TextOverflow.ellipsis),
                orElse: () => const Text('Job'),
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) => _onMenu(context, ref, v),
                  itemBuilder: (context) {
                    final currentStatus = jobAsync.valueOrNull?.status;
                    return [
                      const PopupMenuItem(value: 'edit', child: Text('Edit job')),
                      const PopupMenuItem(value: 'select', child: Text('Select items…')),
                      const PopupMenuItem(value: 'export', child: Text('Export…')),
                      const PopupMenuDivider(),
                      if (currentStatus != JobStatus.completed)
                        const PopupMenuItem(value: 'status:completed', child: Text('Mark completed')),
                      if (currentStatus == JobStatus.completed)
                        const PopupMenuItem(value: 'status:in_progress', child: Text('Reopen job')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Job', style: TextStyle(color: Colors.red)),
                      ),
                    ];
                  },
                ),
              ],
            ),
      body: jobAsync.when(
        data: (job) {
          if (job == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && context.canPop()) context.pop();
            });
            return const SizedBox.shrink();
          }
          if (timelineAsync.hasError && items.isEmpty) {
            return Center(child: Text('Error: ${timelineAsync.error}'));
          }
          if (timelineLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              _Body(
                job: job,
                items: items,
                summary: summary,
                storage: storage.absolutePath,
                selecting: _selecting,
                selected: _selected,
                query: _query,
                searchCtrl: _searchCtrl,
                searchFocusNode: _searchFocusNode,
                tagsInJob: tagsInJob,
                timelineRefreshing: timelineRefreshing,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
                onSelectKind: _selectKind,
                onOpenFilterSheet: () => _openFilterSheet(tagsInJob),
                onClearFilters: _clearFilters,
                onStatusTap: () => _showStatusSheet(job.status),
                onToggle: _toggleSelected,
                onLongPress: (id) => _enterSelection(initialItemId: id),
                onRefresh: () async {
                  final ctx = ref.read(captureContextProvider);
                  if (ctx.isWorkspace) {
                    final status = await runManualSync(ref);
                    if (context.mounted) showSyncSnackBar(context, status);
                  }
                  ref.invalidate(jobProvider(jobId));
                  ref.invalidate(jobTimelineProvider((jobId: jobId, query: _query)));
                  ref.invalidate(jobSummariesProvider);
                },
              ),
              if (!_selecting && items.isNotEmpty)
                StickyActionFab(
                  label: 'Add to job',
                  onPressed: () => _addItemSheet(context),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: _selecting
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_selected.isEmpty || _deleting) ? null : _openTagSheet,
                        icon: const Icon(Icons.label_outline),
                        label: Text('Tag${_selected.isEmpty ? '' : ' (${_selected.length})'}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_selected.isEmpty || _deleting) ? null : _deleteSelected,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          disabledForegroundColor: Colors.red.withValues(alpha: 0.38),
                          disabledBackgroundColor: Colors.transparent,
                        ),
                        icon: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text(_deleting ? 'Deleting…' : 'Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      ),
    );
  }

  void _addItemSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Photos'),
              subtitle: const Text('Rapid batch capture'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-photo', pathParameters: {'id': jobId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Voice note'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-voice', pathParameters: {'id': jobId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('Text note'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-note', pathParameters: {'id': jobId});
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('File / PDF'),
              subtitle: const Text('Receipts, permits, quotes'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-file', pathParameters: {'id': jobId});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String v) async {
    switch (v) {
      case 'edit':
        context.pushNamed('job-edit', pathParameters: {'id': jobId});
      case 'select':
        _enterSelection();
      case 'export':
        context.pushNamed('job-export', pathParameters: {'id': jobId});
      case final v when v.startsWith('status:'):
        final nextStatus = JobStatus.fromDb(v.substring('status:'.length));
        final repo = ref.read(jobsRepositoryProvider);
        final job = await repo.byId(jobId);
        if (job != null && job.status != nextStatus) {
          await repo.update(job.copyWith(status: nextStatus));
          bumpDataRevision(ref);
          ref.invalidate(jobProvider(jobId));
        }
      case 'delete':
        final synced = ref.read(captureContextProvider).isWorkspace;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete job?'),
            content: Text(
              synced
                  ? 'This removes the job and all its items from all your devices. This cannot be undone.'
                  : 'This permanently removes the job and all of its items from this device.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(jobsRepositoryProvider).delete(jobId);
          if (!context.mounted) return;
          context.pop();
          bumpDataRevision(ref);
        }
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.job,
    required this.items,
    required this.summary,
    required this.storage,
    required this.selecting,
    required this.selected,
    required this.query,
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.tagsInJob,
    required this.timelineRefreshing,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectKind,
    required this.onOpenFilterSheet,
    required this.onClearFilters,
    required this.onStatusTap,
    required this.onToggle,
    required this.onLongPress,
    required this.onRefresh,
  });
  final Job job;
  final List<TimelineItem> items;
  final JobSummary? summary;
  final String Function(String) storage;
  final bool selecting;
  final Set<String> selected;
  final TimelineQuery query;
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final Set<String> tagsInJob;
  final bool timelineRefreshing;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<ItemKind?> onSelectKind;
  final VoidCallback onOpenFilterSheet;
  final VoidCallback onClearFilters;
  final VoidCallback onStatusTap;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onLongPress;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final counts = _countsFromSummary(summary) ?? _counts(items);
    final byDay = groupBy<TimelineItem, DateTime>(items, (t) {
      final d = t.item.capturedAt.toLocal();
      return DateTime(d.year, d.month, d.day);
    });
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final bottomPad = selecting ? 88.0 : 120.0;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(job: job, onStatusTap: onStatusTap),
        const SizedBox(height: 12),
        if (!selecting)
          SummaryKindChips(
            totalItems: counts.items,
            photos: counts.photos,
            notes: counts.notes,
            voice: counts.voiceNotes,
            files: counts.files,
            activeKind: query.activeKind,
            onSelect: onSelectKind,
          ),
        if (!selecting) ...[
          const SizedBox(height: 12),
          _TimelineToolbar(
            query: query,
            searchCtrl: searchCtrl,
            searchFocusNode: searchFocusNode,
            onSearchChanged: onSearchChanged,
            onClearSearch: onClearSearch,
            onOpenFilterSheet: onOpenFilterSheet,
          ),
          if (query.hasAdvancedFilters) ...[
            const SizedBox(height: 8),
            _ActiveFilterSummary(
              query: query,
              onTap: onOpenFilterSheet,
              onClear: onClearFilters,
            ),
          ],
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Timeline',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink),
              ),
            ),
            if (query.hasFilters && summary != null)
              Text(
                timelineRefreshing ? 'Searching…' : '${items.length} of ${summary!.items}',
                style: const TextStyle(color: AppColors.subtle, fontSize: 12),
              )
            else if (selecting && items.isNotEmpty)
              Text(
                '${selected.length} of ${items.length}',
                style: const TextStyle(color: AppColors.subtle, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty && query.hasFilters)
          _FilteredEmpty(onClear: onClearFilters)
        else if (items.isEmpty)
          const _EmptyTimeline(),
        for (final d in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              formatDay(d),
              style: const TextStyle(color: AppColors.subtle, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TimelineDayContent(
            dayItems: byDay[d]!,
            storage: storage,
            selecting: selecting,
            selected: selected,
            onToggle: onToggle,
            onLongPress: onLongPress,
            rowBuilder: (t) => _ItemRow(
              timeline: t,
              storage: storage,
              selecting: selecting,
              selected: selected.contains(t.item.id),
              onToggle: () => onToggle(t.item.id),
              onLongPress: () => onLongPress(t.item.id),
            ),
          ),
        ],
      ],
    ),
    );
  }

  _CountsData? _countsFromSummary(JobSummary? summary) {
    if (summary == null) return null;
    return _CountsData(
      items: summary.items,
      photos: summary.photos,
      voiceNotes: summary.voiceNotes,
      notes: summary.notes,
      files: summary.files,
      issues: summary.issues,
    );
  }

  _CountsData _counts(List<TimelineItem> items) {
    var photos = 0, voices = 0, notes = 0, files = 0, issues = 0;
    for (final t in items) {
      switch (t.item.kind) {
        case ItemKind.photo:
          photos++;
        case ItemKind.voice:
          voices++;
        case ItemKind.note:
          notes++;
        case ItemKind.file:
          files++;
      }
      if (t.tags.any((tag) => tag.name.toLowerCase() == 'issue')) issues++;
    }
    return _CountsData(
      items: items.length,
      photos: photos,
      voiceNotes: voices,
      notes: notes,
      files: files,
      issues: issues,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.job, required this.onStatusTap});
  final Job job;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    final address = job.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((address ?? '').isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.subtle),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address!,
                  style: const TextStyle(color: AppColors.subtle, fontSize: 14),
                ),
              ),
            ],
          ),
        if ((job.clientName ?? '').isNotEmpty && (address ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(job.clientName!, style: const TextStyle(color: AppColors.subtle, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        JobStatusPill(status: job.status, showCheck: true, onTap: onStatusTap),
      ],
    );
  }
}

class _CountsData {
  final int items, photos, voiceNotes, notes, files, issues;
  _CountsData({
    required this.items,
    required this.photos,
    required this.voiceNotes,
    required this.notes,
    required this.files,
    required this.issues,
  });
}

class _TimelineToolbar extends StatefulWidget {
  const _TimelineToolbar({
    required this.query,
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onOpenFilterSheet,
  });

  final TimelineQuery query;
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilterSheet;

  @override
  State<_TimelineToolbar> createState() => _TimelineToolbarState();
}

class _TimelineToolbarState extends State<_TimelineToolbar> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.searchCtrl,
            focusNode: widget.searchFocusNode,
            onChanged: (v) {
              setState(() {});
              widget.onSearchChanged(v);
            },
            decoration: InputDecoration(
              hintText: 'Search timeline',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: widget.searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        widget.onClearSearch();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            OutlinedButton(
              onPressed: widget.onOpenFilterSheet,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Icon(Icons.tune_rounded, size: 20),
            ),
            if (widget.query.hasAdvancedFilters)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.timeline,
    required this.storage,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
  });
  final TimelineItem timeline;
  final String Function(String) storage;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = timeline;
    final hasPhoto = t.primaryPhoto != null;
    final isImageFile = t.hasFile &&
        (t.attachedFile!.mimeType.startsWith('image/') ||
            t.attachedFile!.displayName.toLowerCase().endsWith('.heic'));
    final fileThumbPath = isImageFile ? storage(t.attachedFile!.relativePath) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: selecting
              ? onToggle
              : () => context.pushNamed('item-detail', pathParameters: {'id': t.item.id}),
          onLongPress: selecting ? null : onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting) ...[
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    activeColor: AppColors.accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: hasPhoto &&
                            t.displayPhotoRelativePath != null &&
                            File(storage(t.displayPhotoRelativePath!)).existsSync()
                        ? Image.file(
                            File(storage(t.displayPhotoRelativePath!)),
                            key: ValueKey(
                              '${t.item.updatedAt.millisecondsSinceEpoch}-${t.annotatedRender?.sizeBytes ?? 0}',
                            ),
                            fit: BoxFit.cover,
                          )
                        : fileThumbPath != null && File(fileThumbPath).existsSync()
                            ? Image.file(File(fileThumbPath), fit: BoxFit.cover)
                            : Container(
                            color: const Color(0xFFF3F4F6),
                            child: Icon(
                              switch (t.item.kind) {
                                ItemKind.photo => Icons.image_outlined,
                                ItemKind.voice => Icons.mic_none,
                                ItemKind.note => Icons.sticky_note_2_outlined,
                                ItemKind.file => t.attachedFile?.mimeType == 'application/pdf'
                                    ? Icons.picture_as_pdf
                                    : Icons.insert_drive_file_outlined,
                              },
                              color: AppColors.subtle,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(formatTime(t.item.capturedAt),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.ink)),
                          const SizedBox(width: 8),
                          Text(t.item.kind.label,
                              style: const TextStyle(color: AppColors.subtle, fontSize: 11)),
                          if (t.hasVoice) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.mic, size: 12, color: AppColors.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.previewText,
                        style: const TextStyle(color: AppColors.ink, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (t.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final tag in t.tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(tag.name,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF92400E))),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _kindFilterLabel(ItemKind kind) => switch (kind) {
      ItemKind.photo => 'Photos',
      ItemKind.voice => 'Voice',
      ItemKind.note => 'Notes',
      ItemKind.file => 'Files',
    };

List<String> _activeFilterLabels(TimelineQuery query, List<Tag> allTags) {
  final parts = <String>[];
  for (final kind in ItemKind.values) {
    if (query.kinds.contains(kind)) parts.add(_kindFilterLabel(kind));
  }
  for (final tag in allTags) {
    if (query.tagIds.contains(tag.id)) parts.add(tag.name);
  }
  if (query.fromDate != null) parts.add('From ${formatJobDate(query.fromDate!)}');
  if (query.toDate != null) parts.add('To ${formatJobDate(query.toDate!)}');
  if (query.sortOldest) parts.add('Oldest first');
  return parts;
}

class _ActiveFilterSummary extends ConsumerWidget {
  const _ActiveFilterSummary({
    required this.query,
    required this.onTap,
    required this.onClear,
  });

  final TimelineQuery query;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final labels = tagsAsync.maybeWhen(
      data: (tags) => _activeFilterLabels(query, tags),
      orElse: () => _activeFilterLabels(query, const []),
    );
    final summary = labels.join(' · ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear filters',
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.filter_list_off, size: 40, color: AppColors.subtle),
          const SizedBox(height: 8),
          const Text('No items match your filters', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text(
            'Try a different search term or clear filters to see everything.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtle, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.photo_camera_outlined, size: 40, color: AppColors.subtle),
          SizedBox(height: 8),
          Text('No items yet', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
          SizedBox(height: 4),
          Text('Tap + to start capturing, or open Photos for rapid batch capture.',
              style: TextStyle(color: AppColors.subtle, fontSize: 12)),
        ],
      ),
    );
  }
}
