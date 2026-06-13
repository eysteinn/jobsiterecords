import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../sync/sync_providers.dart';

class WorkspaceContextBanner extends ConsumerWidget {
  const WorkspaceContextBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(captureContextProvider);
    if (ctx.isLocal) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.accentSoft,
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saving to ${ctx.workspaceName}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
