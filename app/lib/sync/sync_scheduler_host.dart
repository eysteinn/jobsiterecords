import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../sync/auth_service.dart';
import '../sync/sync_providers.dart';
import '../sync/workspace_access.dart';
import 'sync_nudge_reason.dart';
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
  DateTime? _lastMeRefresh;

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
      _maybeRefreshMe();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      scheduler.onBackground();
    }
  }

  Future<void> _maybeRefreshMe() async {
    final now = DateTime.now();
    if (_lastMeRefresh != null && now.difference(_lastMeRefresh!) < const Duration(minutes: 10)) {
      return;
    }
    _lastMeRefresh = now;
    final ctx = ref.read(captureContextProvider);
    final workspaceId = ctx.workspaceId;
    final workspaceName = ctx.workspaceName;
    await ref.read(authSessionProvider.notifier).refreshMe();
    final session = ref.read(authSessionProvider).valueOrNull;
    if (!ctx.isWorkspace || workspaceId == null || session == null) return;
    if (workspaceInSession(session.workspaces, workspaceId)) return;

    await ref.read(jobsRepositoryProvider).purgeWorkspaceJobs(workspaceId);
    await ref.read(captureContextProvider.notifier).selectLocal();
    bumpDataRevision(ref);
    ref.read(workspaceRemovalMessageProvider.notifier).state =
        workspaceRemovedMessage.replaceFirst('{workspace}', workspaceName);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(workspaceRemovalMessageProvider, (previous, next) {
      if (next == null || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Workspace access ended'),
            content: Text(next),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
            ],
          ),
        );
        ref.read(workspaceRemovalMessageProvider.notifier).state = null;
      });
    });

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
