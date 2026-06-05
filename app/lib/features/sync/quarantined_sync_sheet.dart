import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_nudge_reason.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_runner.dart';
import '../../sync/sync_scheduler.dart';

Future<void> showQuarantinedRetrySheet(BuildContext context, WidgetRef ref) async {
  final quarantined = ref.read(syncStatusProvider).quarantined;
  if (quarantined == 0) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                quarantined == 1 ? '1 item couldn\'t sync' : '$quarantined items couldn\'t sync',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'These items stay on this device. Retry sends them again, or contact support if the problem persists.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final workspaceId = ref.read(captureContextProvider).workspaceId;
                  if (workspaceId == null) return;
                  await ref.read(syncEngineProvider).retryQuarantined(workspaceId);
                  await ref.read(syncExecutorProvider).refreshCounts();
                  ref.read(syncSchedulerProvider).nudge(SyncNudgeReason.manual);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Retry now'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
