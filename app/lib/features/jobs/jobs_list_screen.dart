import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/job.dart';
import '../../domain/models/timeline_item.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_runner.dart';
import '../sync/sync_status_footer.dart';
import '../sync/workspace_switcher.dart';
import 'widgets/job_status_pill.dart';
import 'widgets/status_filter_chips.dart';
import 'widgets/sticky_action_fab.dart';

class JobsListScreen extends ConsumerStatefulWidget {
  const JobsListScreen({super.key});

  @override
  ConsumerState<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends ConsumerState<JobsListScreen> {
  String _query = '';
  JobStatus? _statusFilter;
  String? _lastWorkspaceId;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => restoreSyncStatus(ref));
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final ctx = ref.read(captureContextProvider);
      if (ctx.isWorkspace) {
        final status = await runManualSync(ref);
        if (mounted) showSyncSnackBar(context, status);
      }
      ref.invalidate(jobsListProvider);
      ref.invalidate(jobSummariesProvider);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  List<Job> _filterJobs(List<Job> jobs) {
    if (_statusFilter == null) return jobs;
    return jobs.where((j) => j.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider(_query.isEmpty ? null : _query));
    final summariesAsync = ref.watch(jobSummariesProvider);
    final storage = ref.watch(mediaStorageProvider);
    final ctx = ref.watch(captureContextProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    if (ctx.workspaceId != _lastWorkspaceId) {
      _lastWorkspaceId = ctx.workspaceId;
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreSyncStatus(ref));
    }

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _JobsHeader(
                refreshing: _refreshing,
                onRefresh: _refresh,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search jobs',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _showFilterSheet(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Filters'),
                    ),
                  ],
                ),
              ),
              jobsAsync.maybeWhen(
                data: (allJobs) => StatusFilterChips(
                  jobs: allJobs,
                  activeStatus: _statusFilter,
                  onSelect: (s) => setState(() => _statusFilter = s),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: jobsAsync.when(
                  data: (jobs) {
                    final filtered = _filterJobs(jobs);
                    if (filtered.isEmpty) return _EmptyState(query: _query, hasStatusFilter: _statusFilter != null);
                    final summaries = summariesAsync.valueOrNull ?? const {};
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final j = filtered[i];
                          final s = summaries[j.id];
                          return _JobCard(
                            job: j,
                            summary: s,
                            coverPath: s?.coverPhotoRelativePath == null
                                ? null
                                : storage.absolutePath(s!.coverPhotoRelativePath!),
                            onTap: () => context.pushNamed('job-detail', pathParameters: {'id': j.id}),
                            onDelete: () => _confirmDeleteJob(context, ref, j),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
              SyncStatusFooter(captureContext: ctx, syncStatus: syncStatus),
            ],
          ),
          StickyActionFab(
            label: 'New job',
            onPressed: () => context.pushNamed('job-new'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter jobs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.subtle)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in [null, ...JobStatus.values])
                    FilterChip(
                      label: Text(status?.label ?? 'All'),
                      selected: _statusFilter == status,
                      onSelected: (_) {
                        setState(() => _statusFilter = status);
                        Navigator.pop(context);
                      },
                      showCheckmark: false,
                      selectedColor: AppColors.accentSoft,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _statusFilter = null);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteJob(BuildContext context, WidgetRef ref, Job job) async {
    final synced = ref.read(captureContextProvider).isWorkspace;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete job?'),
        content: Text(
          synced
              ? 'This removes "${job.name}" and all its items from all your devices. This cannot be undone.'
              : 'This permanently removes "${job.name}" and all of its items from this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(jobsRepositoryProvider).delete(job.id);
    bumpDataRevision(ref);
  }
}

class _JobsHeader extends StatelessWidget {
  const _JobsHeader({required this.refreshing, required this.onRefresh});

  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Jobs',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  icon: refreshing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: refreshing ? null : onRefresh,
                ),
                const WorkspaceSwitcher(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.summary,
    required this.coverPath,
    required this.onTap,
    required this.onDelete,
  });

  final Job job;
  final JobSummary? summary;
  final String? coverPath;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final updated = summary?.lastUpdated ?? job.updatedAt;
    final subtitle = job.address ?? job.clientName;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppColors.jobCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.jobCardRadius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.jobCardRadius),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: coverPath != null && File(coverPath!).existsSync()
                      ? Image.file(File(coverPath!), fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.work_outline, color: AppColors.subtle, size: 22),
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
                        Expanded(
                          child: Text(
                            job.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        JobStatusPill(status: job.status, compact: true),
                      ],
                    ),
                    if ((subtitle ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle!,
                          style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${job.status.label} · ${formatUpdatedLabel(updated)}',
                        style: const TextStyle(color: AppColors.mutedLight, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.subtle, size: 20),
                onSelected: (v) {
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.hasStatusFilter});
  final String query;
  final bool hasStatusFilter;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty || hasStatusFilter) {
      return const Center(
        child: Text('No jobs match your filters.', style: TextStyle(color: AppColors.subtle)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.work_outline, size: 56, color: AppColors.subtle),
          const SizedBox(height: 12),
          const Text(
            'No jobs yet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first job to start capturing photos, voice notes, and tags.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subtle, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
