import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/data_revision.dart';
import '../core/format.dart';
import 'sync_nudge_reason.dart';
import 'sync_providers.dart';

const _lastSyncedAtKey = 'sync_last_synced_at';
const _lastSyncedWorkspaceKey = 'sync_last_workspace_id';

final syncExecutorProvider = Provider<SyncExecutor>((ref) => SyncExecutor(ref));

class SyncExecutor {
  SyncExecutor(this._ref);

  final Ref _ref;

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

  Future<void> restoreStatus() async {
    final ctx = _ref.read(captureContextProvider);
    if (ctx.isLocal || ctx.workspaceId == null) return;

    final lastSyncedAt = await _loadPersistedLastSynced(ctx.workspaceId!);
    _ref.read(syncStatusProvider.notifier).state = _ref.read(syncStatusProvider).copyWith(
          lastSyncedAt: lastSyncedAt,
          error: null,
          isSyncing: false,
        );
    await refreshCounts();
  }

  Future<SyncStatus> run({required SyncNudgeReason reason}) async {
    final ctx = _ref.read(captureContextProvider);
    if (ctx.isLocal) {
      return const SyncStatus();
    }

    final session = _ref.read(authSessionProvider).valueOrNull;
    if (session == null) {
      final status = const SyncStatus(error: 'Sign in to sync');
      _ref.read(syncStatusProvider.notifier).state = status;
      return status;
    }

    _ref.read(syncStatusProvider.notifier).state =
        _ref.read(syncStatusProvider).copyWith(isSyncing: true, error: null);

    try {
      final engine = _ref.read(syncEngineProvider);
      final wifiOnly = _ref.read(syncWifiOnlyProvider);
      final result = await engine.sync(
        session: session,
        workspaceId: ctx.workspaceId!,
        wifiOnly: wifiOnly,
      );

      final pending = await engine.countPending(ctx.workspaceId!);
      final quarantined = await engine.countQuarantined(ctx.workspaceId!);
      final err = result.error ?? result.pushError;
      final previous = _ref.read(syncStatusProvider);
      final lastSyncedAt = err == null ? DateTime.now() : previous.lastSyncedAt;
      final status = SyncStatus(
        lastSyncedAt: lastSyncedAt,
        pending: pending,
        quarantined: quarantined,
        error: err,
        changesSynced: result.totalChanges,
        isOffline: previous.isOffline,
      );
      _ref.read(syncStatusProvider.notifier).state = status;
      if (err == null && lastSyncedAt != null) {
        await _persistLastSynced(ctx.workspaceId!, lastSyncedAt);
      }
      if (result.error == null) {
        bumpDataRevisionCounter(_ref);
      }
      return status;
    } finally {
      _ref.read(syncStatusProvider.notifier).state =
          _ref.read(syncStatusProvider).copyWith(isSyncing: false);
    }
  }

  Future<int> refreshCounts() async {
    final ctx = _ref.read(captureContextProvider);
    if (ctx.isLocal || ctx.workspaceId == null) return 0;
    final engine = _ref.read(syncEngineProvider);
    final pending = await engine.countPending(ctx.workspaceId!);
    final quarantined = await engine.countQuarantined(ctx.workspaceId!);
    _ref.read(syncStatusProvider.notifier).state = _ref.read(syncStatusProvider).copyWith(
          pending: pending,
          quarantined: quarantined,
        );
    return pending;
  }
}

/// Restores persisted last-sync time for the active workspace and refreshes counts.
Future<void> restoreSyncStatus(WidgetRef ref) {
  return ref.read(syncExecutorProvider).restoreStatus();
}

Future<SyncStatus> runManualSync(WidgetRef ref) {
  return ref.read(syncExecutorProvider).run(reason: SyncNudgeReason.manual);
}

Future<int> refreshPendingCount(WidgetRef ref) {
  return ref.read(syncExecutorProvider).refreshCounts();
}

Future<int> refreshSyncCounts(Ref ref) {
  return ref.read(syncExecutorProvider).refreshCounts();
}

/// Short label for the jobs-list footer — subtle, not intrusive.
String syncStatusFooterLabel(SyncStatus status) {
  if (status.isSyncing) return 'Syncing…';
  if (status.isOffline && status.pending > 0) return 'Offline · will sync when online';
  if (status.quarantined > 0) {
    final noun = status.quarantined == 1 ? 'item' : 'items';
    return '$noun couldn\'t sync · tap to retry';
  }
  if (status.error != null) return 'Sync failed · retrying';
  if (status.pending > 0) return '${status.pending} pending';
  if (status.lastSyncedAt != null) return 'Synced ${formatRelative(status.lastSyncedAt!)}';
  return 'Ready to sync';
}

/// User-facing message after a manual sync (pull-to-refresh or Settings).
String syncFeedbackMessage(SyncStatus status) {
  if (status.error != null) return status.error!;
  if (status.quarantined > 0) {
    return status.changesSynced > 0
        ? 'Synced · ${status.quarantined} couldn\'t sync'
        : '${status.quarantined} item(s) couldn\'t sync';
  }
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
