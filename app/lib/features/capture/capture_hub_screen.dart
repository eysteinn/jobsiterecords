import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/job.dart';

class CaptureHubScreen extends ConsumerWidget {
  const CaptureHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsListProvider(null));

    return Scaffold(
      appBar: AppBar(title: const Text('Capture')),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.work_outline, size: 56, color: AppColors.subtle),
                    const SizedBox(height: 12),
                    const Text('No jobs yet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    const Text(
                      'Create a job to capture photos and notes against it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.subtle, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.pushNamed('job-new'),
                      icon: const Icon(Icons.add),
                      label: const Text('New Job'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Pick a job to capture into', style: TextStyle(color: AppColors.subtle)),
              ),
              for (final j in jobs)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(j.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(j.address ?? j.clientName ?? ' '),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _quickPick(context, j),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _quickPick(BuildContext context, Job job) {
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
                context.pushNamed('capture-photo', pathParameters: {'id': job.id});
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Voice note'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-voice', pathParameters: {'id': job.id});
              },
            ),
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('Text note'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-note', pathParameters: {'id': job.id});
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('File / PDF'),
              subtitle: const Text('Receipts, permits, quotes'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed('capture-file', pathParameters: {'id': job.id});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
