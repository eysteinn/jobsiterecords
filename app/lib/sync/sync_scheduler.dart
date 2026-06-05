import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network_gate.dart';
import 'sync_config.dart';
import 'sync_nudge_reason.dart';
import 'sync_providers.dart';
import 'sync_runner.dart';

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref);
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Owns automatic sync triggers, coalescing, backoff, and single-flight.
class SyncScheduler {
  SyncScheduler(this._ref);

  final Ref _ref;

  Timer? _debounceTimer;
  Timer? _backoffTimer;
  Timer? _periodicTimer;
  Timer? _watchTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  int _watchingJobs = 0;

  bool _started = false;
  bool _syncInFlight = false;
  bool _rerunWhenDone = false;
  bool _wasOffline = true;
  bool _authBlocked = false;

  DateTime? _lastAutoSyncAttempt;
  DateTime? _firstPendingSince;
  int _backoffStep = 0;

  void start() {
    if (_started) return;
    _started = true;

    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    if (SchedulerBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _startPeriodicTimer();
    }
    unawaited(_bootstrap());
  }

  void dispose() {
    _debounceTimer?.cancel();
    _backoffTimer?.cancel();
    _periodicTimer?.cancel();
    unawaited(_connectivitySub?.cancel());
    _started = false;
  }

  Future<void> _bootstrap() async {
    _wasOffline = !(await isDeviceOnline());
    _updateOfflineFlag(_wasOffline);
    nudge(SyncNudgeReason.launch);
  }

  void onForeground() {
    _startPeriodicTimer();
    nudge(SyncNudgeReason.foreground);
  }

  void onBackground() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// Call when entering job detail in a workspace — fast pull for remote edits.
  void beginWatchingJob() {
    _watchingJobs++;
    _syncWatchTimer();
    nudge(SyncNudgeReason.watching);
  }

  /// Call when leaving job detail.
  void endWatchingJob() {
    if (_watchingJobs > 0) _watchingJobs--;
    if (_watchingJobs == 0) {
      _watchTimer?.cancel();
      _watchTimer = null;
    }
  }

  void nudge(SyncNudgeReason reason) {
    if (!_started) return;

    final ctx = _ref.read(captureContextProvider);
    if (!ctx.isWorkspace && !reason.isManual) return;

    if (reason == SyncNudgeReason.connectivity) {
      _resetBackoff();
    }

    if (reason.bypassesBackoff) {
      _backoffTimer?.cancel();
      _backoffTimer = null;
    } else if (_backoffTimer != null) {
      return;
    }

    if (reason == SyncNudgeReason.write) {
      _scheduleWriteSync();
      return;
    }

    unawaited(_maybeRun(reason));
  }

  void _scheduleWriteSync() {
    final now = DateTime.now();
    _firstPendingSince ??= now;

    if (now.difference(_firstPendingSince!) >= SyncConfig.pendingHardCap) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      unawaited(_maybeRun(SyncNudgeReason.write));
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(SyncConfig.writeDebounce, () {
      _debounceTimer = null;
      unawaited(_maybeRun(SyncNudgeReason.write));
    });
  }

  Future<void> _maybeRun(SyncNudgeReason reason) async {
    if (_syncInFlight) {
      _rerunWhenDone = true;
      return;
    }

    if (!reason.bypassesRateLimit && _withinMinInterval()) return;

    if (!await _shouldAttempt(reason)) return;

    await _run(reason);
  }

  bool _withinMinInterval() {
    final last = _lastAutoSyncAttempt;
    if (last == null) return false;
    return DateTime.now().difference(last) < SyncConfig.minAutoSyncInterval;
  }

  Future<bool> _shouldAttempt(SyncNudgeReason reason) async {
    final ctx = _ref.read(captureContextProvider);
    if (ctx.isLocal) return reason.isManual;

    final session = _ref.read(authSessionProvider).valueOrNull;
    if (session == null) {
      if (!reason.isManual) return false;
      return true;
    }

    if (_authBlocked && !reason.isManual) return false;

    final online = await isDeviceOnline();
    _updateOfflineFlag(!online);
    if (!online) {
      if (!reason.isManual) return false;
    }

    if (reason == SyncNudgeReason.foreground) {
      final status = _ref.read(syncStatusProvider);
      final stale = status.lastSyncedAt == null ||
          DateTime.now().difference(status.lastSyncedAt!) > SyncConfig.resumeSyncThreshold;
      if (!stale && status.pending == 0) return false;
    }

    if (reason == SyncNudgeReason.launch) {
      final pending = await _ref.read(syncEngineProvider).countPending(ctx.workspaceId!);
      if (pending == 0) return false;
    }

    if (reason == SyncNudgeReason.connectivity) {
      final pending = await _ref.read(syncEngineProvider).countPending(ctx.workspaceId!);
      if (pending == 0 && _watchingJobs == 0) return false;
    }

    if (reason == SyncNudgeReason.watching) {
      return true;
    }

    return true;
  }

  Future<void> _run(SyncNudgeReason reason) async {
    _syncInFlight = true;
    if (!reason.isManual) {
      _lastAutoSyncAttempt = DateTime.now();
    }

    try {
      final status = await _ref.read(syncExecutorProvider).run(reason: reason);
      final authError = status.error?.contains('Sign in') == true ||
          status.error?.contains('Session expired') == true;
      _authBlocked = authError;

      if (status.error == null) {
        _resetBackoff();
        _firstPendingSince = null;
      } else if (!reason.bypassesBackoff) {
        _scheduleBackoff();
      }
    } finally {
      _syncInFlight = false;
      if (_rerunWhenDone) {
        _rerunWhenDone = false;
        unawaited(_maybeRun(SyncNudgeReason.write));
      }
    }
  }

  void _scheduleBackoff() {
    _backoffTimer?.cancel();
    final step = _backoffStep.clamp(0, SyncConfig.backoffSteps.length - 1);
    final delay = SyncConfig.backoffSteps[step];
    _backoffStep = (_backoffStep + 1).clamp(0, SyncConfig.backoffSteps.length - 1);
    _backoffTimer = Timer(delay, () {
      _backoffTimer = null;
      nudge(SyncNudgeReason.periodic);
    });
  }

  void _resetBackoff() {
    _backoffStep = 0;
    _backoffTimer?.cancel();
    _backoffTimer = null;
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(SyncConfig.periodicSyncInterval, (_) {
      nudge(SyncNudgeReason.periodic);
    });
    _syncWatchTimer();
  }

  void _syncWatchTimer() {
    _watchTimer?.cancel();
    _watchTimer = null;
    if (_watchingJobs == 0) return;
    if (SchedulerBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _watchTimer = Timer.periodic(SyncConfig.watchJobPollInterval, (_) {
      nudge(SyncNudgeReason.watching);
    });
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    _updateOfflineFlag(!online);

    if (online && _wasOffline) {
      _wasOffline = false;
      _resetBackoff();
      nudge(SyncNudgeReason.connectivity);
      return;
    }

    _wasOffline = !online;
  }

  void _updateOfflineFlag(bool offline) {
    final current = _ref.read(syncStatusProvider);
    if (current.isOffline == offline) return;
    _ref.read(syncStatusProvider.notifier).state = current.copyWith(isOffline: offline);
  }
}
