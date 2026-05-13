import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/item.dart';
import '../../domain/models/job.dart';
import '../../domain/models/timeline_item.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobProvider(jobId));
    final timelineAsync = ref.watch(jobTimelineProvider(jobId));
    final storage = ref.watch(mediaStorageProvider);

    return Scaffold(
      appBar: AppBar(
        title: jobAsync.maybeWhen(
          data: (j) => Text(j?.name ?? 'Job', maxLines: 1, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('Job'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.pushNamed('job-edit', pathParameters: {'id': jobId}),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, ref, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export…')),
              PopupMenuItem(value: 'complete', child: Text('Mark Completed')),
              PopupMenuItem(value: 'delete', child: Text('Delete Job', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: jobAsync.when(
        data: (job) {
          if (job == null) return const Center(child: Text('Job not found'));
          return timelineAsync.when(
            data: (items) => _Body(job: job, items: items, storage: storage.absolutePath),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItemSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Photo or Note'),
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
              title: const Text('Photo'),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String v) async {
    switch (v) {
      case 'export':
        context.pushNamed('job-export', pathParameters: {'id': jobId});
      case 'complete':
        final repo = ref.read(jobsRepositoryProvider);
        final job = await repo.byId(jobId);
        if (job != null) {
          await repo.update(job.copyWith(status: JobStatus.completed));
          bumpDataRevision(ref);
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete job?'),
            content: const Text('This permanently removes the job and all of its items.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (ok == true) {
          await ref.read(jobsRepositoryProvider).delete(jobId);
          bumpDataRevision(ref);
          if (context.mounted) context.go('/jobs');
        }
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.job, required this.items, required this.storage});
  final Job job;
  final List<TimelineItem> items;
  final String Function(String) storage;

  @override
  Widget build(BuildContext context) {
    final counts = _counts(items);
    final byDay = groupBy<TimelineItem, DateTime>(items, (t) {
      final d = t.item.capturedAt.toLocal();
      return DateTime(d.year, d.month, d.day);
    });
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _Header(job: job),
        const SizedBox(height: 12),
        _Counts(counts: counts),
        const SizedBox(height: 18),
        const Text('Timeline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
        const SizedBox(height: 8),
        if (items.isEmpty) const _EmptyTimeline(),
        for (final d in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(formatDay(d), style: const TextStyle(color: AppColors.subtle, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          for (final t in byDay[d]!) _ItemRow(timeline: t, storage: storage),
        ],
      ],
    );
  }

  _CountsData _counts(List<TimelineItem> items) {
    var photos = 0, voices = 0, notes = 0, issues = 0;
    for (final t in items) {
      switch (t.item.kind) {
        case ItemKind.photo:
          photos++;
        case ItemKind.voice:
          voices++;
        case ItemKind.note:
          notes++;
      }
      if (t.tags.any((tag) => tag.name.toLowerCase() == 'issue')) issues++;
    }
    return _CountsData(items: items.length, photos: photos, voiceNotes: voices, notes: notes, issues: issues);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) {
    final addr = [job.clientName, job.address].where((s) => (s ?? '').isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(job.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.ink)),
        if (addr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(addr, style: const TextStyle(color: AppColors.subtle)),
          ),
      ],
    );
  }
}

class _CountsData {
  final int items, photos, voiceNotes, notes, issues;
  _CountsData({required this.items, required this.photos, required this.voiceNotes, required this.notes, required this.issues});
}

class _Counts extends StatelessWidget {
  const _Counts({required this.counts});
  final _CountsData counts;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          _stat('${counts.items}', 'Items'),
          _stat('${counts.photos}', 'Photos'),
          _stat('${counts.voiceNotes}', 'Voice'),
          _stat('${counts.notes}', 'Notes'),
          _stat('${counts.issues}', 'Issues'),
        ],
      ),
    );
  }

  Widget _stat(String n, String l) => Expanded(
        child: Column(
          children: [
            Text(n, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
            Text(l, style: const TextStyle(color: AppColors.subtle, fontSize: 11)),
          ],
        ),
      );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.timeline, required this.storage});
  final TimelineItem timeline;
  final String Function(String) storage;
  @override
  Widget build(BuildContext context) {
    final t = timeline;
    final hasPhoto = t.primaryPhoto != null;
    final caption = (t.item.caption ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.pushNamed('item-detail', pathParameters: {'id': t.item.id}),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: hasPhoto && File(storage(t.primaryPhoto!.relativePath)).existsSync()
                        ? Image.file(File(storage(t.primaryPhoto!.relativePath)), fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFFF3F4F6),
                            child: Icon(
                              switch (t.item.kind) {
                                ItemKind.photo => Icons.image_outlined,
                                ItemKind.voice => Icons.mic_none,
                                ItemKind.note => Icons.sticky_note_2_outlined,
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
                        caption.isEmpty
                            ? (t.item.body?.trim().isNotEmpty == true ? t.item.body! : '(no caption)')
                            : caption,
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
          Text('Tap "Add Photo or Note" to start capturing.',
              style: TextStyle(color: AppColors.subtle, fontSize: 12)),
        ],
      ),
    );
  }
}
