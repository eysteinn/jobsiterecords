import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_service.dart';
import 'sync_nudge_reason.dart';
import 'sync_providers.dart';
import 'sync_scheduler.dart';

/// Wires lifecycle, connectivity, and context changes into [SyncScheduler].
class SyncSchedulerHost extends ConsumerStatefulWidget {
  const SyncSchedulerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncSchedulerHost> createState() => _SyncSchedulerHostState();
}

class _SyncSchedulerHostState extends ConsumerState<SyncSchedulerHost> with WidgetsBindingObserver {
  String? _lastWorkspaceId;
  bool _hadSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncSchedulerProvider).start();
      _hadSession = ref.read(authSessionProvider).valueOrNull != null;
      _lastWorkspaceId = ref.read(captureContextProvider).workspaceId;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final scheduler = ref.read(syncSchedulerProvider);
    if (state == AppLifecycleState.resumed) {
      scheduler.onForeground();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      scheduler.onBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CaptureContext>(captureContextProvider, (previous, next) {
      if (next.isWorkspace && next.workspaceId != _lastWorkspaceId) {
        _lastWorkspaceId = next.workspaceId;
        ref.read(syncSchedulerProvider).nudge(SyncNudgeReason.workspaceSwitch);
      }
      if (next.isLocal) {
        _lastWorkspaceId = null;
      }
    });

    ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (previous, next) {
      final had = _hadSession;
      final has = next.valueOrNull != null;
      _hadSession = has;
      if (!had && has && ref.read(captureContextProvider).isWorkspace) {
        ref.read(syncSchedulerProvider).nudge(SyncNudgeReason.workspaceSwitch);
      }
    });

    return widget.child;
  }
}
