import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'sync_providers.dart';
Future<SyncStatus> runForegroundSync(WidgetRef ref) async {
  final ctx = ref.read(captureContextProvider);
  if (ctx.isLocal) {
    return const SyncStatus();
  }

  final session = ref.read(authSessionProvider).valueOrNull;
  if (session == null) {
    return const SyncStatus(error: 'Sign in to sync');
  }

  final engine = ref.read(syncEngineProvider);
  final result = await engine.sync(
    session: session,
    workspaceId: ctx.workspaceId!,
  );

  final pending = await engine.countPending(ctx.workspaceId!);
  final err = result.error ?? result.pushError;
  final status = SyncStatus(
    lastSyncedAt: err == null ? DateTime.now() : ref.read(syncStatusProvider).lastSyncedAt,
    pending: pending,
    error: err,
    pushedJobs: result.pushedJobs,
    pushedItems: result.pushedItems,
  );
  ref.read(syncStatusProvider.notifier).state = status;
  if (result.error == null) {
    bumpDataRevision(ref);
  }
  return status;
}

Future<int> refreshPendingCount(WidgetRef ref) async {
  final ctx = ref.read(captureContextProvider);
  if (ctx.isLocal || ctx.workspaceId == null) return 0;
  final pending = await ref.read(syncEngineProvider).countPending(ctx.workspaceId!);
  ref.read(syncStatusProvider.notifier).state = ref.read(syncStatusProvider).copyWith(pending: pending);
  return pending;
}
