import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../sync/sync_providers.dart';
import '../sync/workspace_access.dart';

/// Ensures the opened job belongs to the active capture context (local vs workspace).
class JobContextGuard extends ConsumerWidget {
  const JobContextGuard({super.key, required this.jobId, required this.child});

  final String jobId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobProvider(jobId));
    final ctx = ref.watch(captureContextProvider);

    return jobAsync.when(
      data: (job) {
        if (job == null) return child;
        final matches = jobMatchesCaptureContext(
          jobWorkspaceId: job.workspaceId,
          captureIsLocal: ctx.isLocal,
          captureWorkspaceId: ctx.workspaceId,
        );
        if (matches) return child;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This job is not in your current workspace context.'),
            ),
          );
          context.go('/jobs');
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => child,
    );
  }
}
