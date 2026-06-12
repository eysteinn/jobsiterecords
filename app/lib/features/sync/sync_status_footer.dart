import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_runner.dart';
import '../../sync/workspace_access.dart';
import 'quarantined_sync_sheet.dart';

/// Subtle sync status line shown at the bottom of workspace-aware screens.
class SyncStatusFooter extends ConsumerWidget {
  const SyncStatusFooter({super.key, required this.captureContext, required this.syncStatus});

  final CaptureContext captureContext;
  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (captureContext.isLocal) {
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
                'Local — data stays on this device.',
                style: TextStyle(fontSize: 11, color: AppColors.subtle),
              ),
            ],
          ),
        ),
      );
    }

    final session = ref.watch(authSessionProvider).valueOrNull;
    final workspace = captureContext.workspaceId != null && session != null
        ? findWorkspace(session.workspaces, captureContext.workspaceId!)
        : null;
    final err = syncStatus.error;
    final label = syncStatusFooterLabel(syncStatus, workspace: workspace);
    final showPausedBanner = workspaceAccessMode(workspace) == 'read_only';

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (syncStatus.isSyncing)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.subtle),
          )
        else
          Icon(
            err != null || syncStatus.quarantined > 0
                ? Icons.error_outline
                : syncStatus.isOffline
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
            color: err != null || syncStatus.quarantined > 0
                ? Colors.red
                : syncStatus.isOffline
                    ? AppColors.subtle
                    : const Color(0xFF10B981),
            size: 14,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${captureContext.workspaceName} · $label',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.subtle),
          ),
        ),
      ],
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPausedBanner)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  subscriptionSyncPausedBanner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: AppColors.subtle, height: 1.35),
                ),
              ),
            syncStatus.quarantined > 0
                ? InkWell(
                    onTap: () => showQuarantinedRetrySheet(context, ref),
                    borderRadius: BorderRadius.circular(8),
                    child: content,
                  )
                : content,
          ],
        ),
      ),
    );
  }
}
