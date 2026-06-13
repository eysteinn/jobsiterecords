import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../sync/sync_nudge_reason.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_scheduler.dart';

class InviteAcceptScreen extends ConsumerStatefulWidget {
  const InviteAcceptScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends ConsumerState<InviteAcceptScreen> {
  Map<String, dynamic>? _preview;
  String? _error;
  bool _loading = true;
  bool _accepting = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await ref.read(authServiceProvider).previewInvite(widget.token);
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    final session = ref.read(authSessionProvider).valueOrNull;
    if (session == null) {
      if (!mounted) return;
      context.pushNamed('sign-in', queryParameters: {'invite_token': widget.token});
      return;
    }
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      final result = await ref.read(authSessionProvider.notifier).acceptInvite(widget.token);
      await ref.read(authSessionProvider.notifier).refreshMe();
      final workspace = Map<String, dynamic>.from(result['workspace'] as Map);
      final wsId = workspace['id'] as String;
      final wsName = (workspace['name'] as String?) ?? 'Workspace';
      await ref.read(captureContextProvider.notifier).selectWorkspace(id: wsId, name: wsName);
      ref.read(syncSchedulerProvider).nudge(SyncNudgeReason.workspaceSwitch);
      bumpDataRevision(ref);
      if (!mounted) return;
      setState(() => _accepted = true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) context.go('/jobs');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final signedInEmail = session?.user['email']?.toString();
    final previewEmail = _preview?['email']?.toString();
    final emailMismatch = signedInEmail != null &&
        previewEmail != null &&
        signedInEmail.toLowerCase() != previewEmail.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Workspace invite')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_error != null && _preview == null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_preview != null) ...[
            Text(
              'You\'ve been invited to ${_preview!['workspace_name'] ?? 'a workspace'}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              'Join as ${_preview!['role'] ?? 'member'} · ${_preview!['email'] ?? ''}',
              style: const TextStyle(color: AppColors.subtle),
            ),
            if (emailMismatch) ...[
              const SizedBox(height: 16),
              Text(
                'Signed in as $signedInEmail, but this invite is for $previewEmail.',
                style: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authSessionProvider.notifier).logout();
                  if (mounted) context.pushNamed('sign-in', queryParameters: {'invite_token': widget.token});
                },
                child: const Text('Sign in with invited email'),
              ),
            ],
            const SizedBox(height: 24),
            if (_accepted)
              const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Joined! Opening your workspace…'),
              )
            else if (session == null) ...[
              const Text('Sign in or create an account to accept this invite.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pushNamed('sign-in', queryParameters: {'invite_token': widget.token}),
                  child: const Text('Sign in to accept'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_accepting || emailMismatch) ? null : _accept,
                  child: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Accept invite'),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ],
      ),
    );
  }
}
