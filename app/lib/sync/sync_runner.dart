import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/providers.dart';
import '../core/format.dart';
import 'sync_providers.dart';

const _lastSyncedAtKey = 'sync_last_synced_at';
const _lastSyncedWorkspaceKey = 'sync_last_workspace_id';

Future<void> _persistLastSynced(String workspaceId, DateTime at) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastSyncedAtKey, at.toUtc().toIso8601String());
  await prefs.setString(_lastSyncedWorkspaceKey, workspaceId);
}

Future<DateTime?> _loadPersistedLastSynced(String workspaceId) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_lastSyncedWorkspaceKey) != workspaceId) return null;
  final raw = prefs.getString(_lastSyncedAtKey);
  if (raw == null) return null;
  return DateTime.parse(raw);
}

/// Restores persisted last-sync time for the active workspace and refreshes pending count.
Future<void> restoreSyncStatus(WidgetRef ref) async {
  final ctx = ref.read(captureContextProvider);
  if (ctx.isLocal || ctx.workspaceId == null) return;

  final lastSyncedAt = await _loadPersistedLastSynced(ctx.workspaceId!);
  ref.read(syncStatusProvider.notifier).state = ref.read(syncStatusProvider).copyWith(
        lastSyncedAt: lastSyncedAt,
        error: null,
        isSyncing: false,
      );
  await refreshPendingCount(ref);
}

Future<SyncStatus> runForegroundSync(WidgetRef ref) async {
  final ctx = ref.read(captureContextProvider);
  if (ctx.isLocal) {
    return const SyncStatus();
  }

  final session = ref.read(authSessionProvider).valueOrNull;
  if (session == null) {
    final status = const SyncStatus(error: 'Sign in to sync');
    ref.read(syncStatusProvider.notifier).state = status;
    return status;
  }

  ref.read(syncStatusProvider.notifier).state =
      ref.read(syncStatusProvider).copyWith(isSyncing: true, error: null);

  try {
    final engine = ref.read(syncEngineProvider);
    final wifiOnly = ref.read(syncWifiOnlyProvider);
    final result = await engine.sync(
      session: session,
      workspaceId: ctx.workspaceId!,
      wifiOnly: wifiOnly,
    );

    final pending = await engine.countPending(ctx.workspaceId!);
    final err = result.error ?? result.pushError;
    final previous = ref.read(syncStatusProvider);
    final lastSyncedAt = err == null ? DateTime.now() : previous.lastSyncedAt;
    final status = SyncStatus(
      lastSyncedAt: lastSyncedAt,
      pending: pending,
      error: err,
      changesSynced: result.totalChanges,
    );
    ref.read(syncStatusProvider.notifier).state = status;
    if (err == null && lastSyncedAt != null) {
      await _persistLastSynced(ctx.workspaceId!, lastSyncedAt);
    }
    if (result.error == null) {
      bumpDataRevision(ref);
    }
    return status;
  } finally {
    ref.read(syncStatusProvider.notifier).state =
        ref.read(syncStatusProvider).copyWith(isSyncing: false);
  }
}

Future<int> refreshPendingCount(WidgetRef ref) async {
  final ctx = ref.read(captureContextProvider);
  if (ctx.isLocal || ctx.workspaceId == null) return 0;
  final pending = await ref.read(syncEngineProvider).countPending(ctx.workspaceId!);
  ref.read(syncStatusProvider.notifier).state = ref.read(syncStatusProvider).copyWith(pending: pending);
  return pending;
}

/// Short label for the jobs-list footer — subtle, not intrusive.
String syncStatusFooterLabel(SyncStatus status) {
  if (status.isSyncing) return 'Syncing…';
  if (status.error != null) return 'Sync failed · pull to retry';
  if (status.pending > 0) return '${status.pending} pending · pull to sync';
  if (status.lastSyncedAt != null) return 'Synced ${formatRelative(status.lastSyncedAt!)}';
  return 'Pull to sync';
}

/// User-facing message after a manual sync (pull-to-refresh or Settings).
String syncFeedbackMessage(SyncStatus status) {
  if (status.error != null) return status.error!;
  if (status.pending > 0) {
    return status.changesSynced > 0
        ? 'Synced · ${status.pending} still pending'
        : '${status.pending} changes still pending';
  }
  if (status.changesSynced == 0) return 'Everything is up to date';
  return 'Synced successfully';
}

void showSyncSnackBar(BuildContext context, SyncStatus status) {
  final isError = status.error != null;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(syncFeedbackMessage(status)),
      backgroundColor: isError ? Colors.red.shade800 : null,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 5 : 3),
    ),
  );
}
