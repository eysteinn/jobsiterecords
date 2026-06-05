import 'package:flutter/material.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_runner.dart';

/// Subtle sync status line shown at the bottom of workspace-aware screens.
class SyncStatusFooter extends StatelessWidget {
  const SyncStatusFooter({super.key, required this.captureContext, required this.syncStatus});

  final CaptureContext captureContext;
  final SyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
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

    final err = syncStatus.error;
    final label = syncStatusFooterLabel(syncStatus);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
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
                err != null ? Icons.error_outline : Icons.cloud_done_outlined,
                color: err != null ? Colors.red : const Color(0xFF10B981),
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
        ),
      ),
    );
  }
}
