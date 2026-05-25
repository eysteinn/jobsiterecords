import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../sync/sync_providers.dart';

class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(captureContextProvider);
    final session = ref.watch(authSessionProvider).valueOrNull;
    final workspaces = session?.workspaces ?? const [];

    return PopupMenuButton<String>(
      tooltip: 'Workspace',
      onSelected: (value) async {
        if (value == 'local') {
          await ref.read(captureContextProvider.notifier).selectLocal();
        } else {
          final ws = workspaces.firstWhere((w) => w['id'] == value);
          await ref.read(captureContextProvider.notifier).selectWorkspace(
                id: ws['id'] as String,
                name: (ws['name'] as String?) ?? 'Workspace',
              );
        }
      },
      itemBuilder: (context) {
        return [
          CheckedPopupMenuItem(
            value: 'local',
            checked: ctx.isLocal,
            child: const Text('Local'),
          ),
          if (session == null)
            const PopupMenuItem(
              enabled: false,
              child: Text('Sign in for workspaces'),
            )
          else if (workspaces.isEmpty)
            const PopupMenuItem(
              enabled: false,
              child: Text('No workspaces'),
            )
          else
            ...workspaces.map((ws) {
              final id = ws['id'] as String;
              return CheckedPopupMenuItem(
                value: id,
                checked: ctx.isWorkspace && ctx.workspaceId == id,
                child: Text((ws['name'] as String?) ?? 'Workspace'),
              );
            }),
          const PopupMenuDivider(),
          PopupMenuItem(
            enabled: false,
            child: Text(
              session == null ? 'Not signed in' : session.user['email']?.toString() ?? 'Signed in',
              style: const TextStyle(fontSize: 12, color: AppColors.subtle),
            ),
          ),
          if (session == null)
            PopupMenuItem(
              child: const Text('Sign in…'),
              onTap: () => context.pushNamed('sign-in'),
            ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ctx.isLocal ? Icons.phone_android : Icons.cloud_outlined, size: 18, color: AppColors.subtle),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                ctx.workspaceName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
