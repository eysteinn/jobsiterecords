import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/job.dart';
import '../../domain/models/timeline_item.dart';

class JobsListScreen extends ConsumerStatefulWidget {
  const JobsListScreen({super.key});

  @override
  ConsumerState<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends ConsumerState<JobsListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider(_query.isEmpty ? null : _query));
    final summariesAsync = ref.watch(jobSummariesProvider);
    final storage = ref.watch(mediaStorageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 32),
            onPressed: () => context.pushNamed('job-new'),
            tooltip: 'New job',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search jobs',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: jobsAsync.when(
              data: (jobs) {
                if (jobs.isEmpty) return _EmptyState(query: _query);
                final summaries = summariesAsync.valueOrNull ?? const {};
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(jobsListProvider);
                    ref.invalidate(jobSummariesProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final j = jobs[i];
                      final s = summaries[j.id];
                      return _JobCard(
                        job: j,
                        summary: s,
                        coverPath: s?.coverPhotoRelativePath == null
                            ? null
                            : storage.absolutePath(s!.coverPhotoRelativePath!),
                        onTap: () => context.pushNamed('job-detail', pathParameters: {'id': j.id}),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          const _LocalOnlyFooter(),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.summary, required this.coverPath, required this.onTap});
  final Job job;
  final JobSummary? summary;
  final String? coverPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final updated = summary?.lastUpdated ?? job.updatedAt;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: coverPath != null && File(coverPath!).existsSync()
                      ? Image.file(File(coverPath!), fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.image_outlined, color: AppColors.subtle),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if ((job.address ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          job.address!,
                          style: const TextStyle(color: AppColors.subtle, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusPill(status: job.status),
                        const SizedBox(width: 8),
                        Text(
                          '${summary?.items ?? 0} items',
                          style: const TextStyle(color: AppColors.subtle, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRelative(updated),
                    style: const TextStyle(color: AppColors.subtle, fontSize: 11),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      JobStatus.planning => (const Color(0xFFE5E7EB), const Color(0xFF374151)),
      JobStatus.inProgress => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      JobStatus.completed => (const Color(0xFFD1FAE5), const Color(0xFF065F46)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      return const Center(
        child: Text('No jobs match your search.', style: TextStyle(color: AppColors.subtle)),
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
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.pushNamed('job-new'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Job'),
          ),
        ],
      ),
    );
  }
}

class _LocalOnlyFooter extends StatelessWidget {
  const _LocalOnlyFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
            SizedBox(width: 6),
            Text(
              'Data is stored on your device only.',
              style: TextStyle(fontSize: 11, color: AppColors.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
