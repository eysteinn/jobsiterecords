import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_runner.dart';
import '../capture/widgets/tag_chips.dart';
import '../sync/quarantined_sync_sheet.dart';

String _syncSubtitle(SyncStatus syncStatus) {
  if (syncStatus.isSyncing) return 'Syncing…';
  if (syncStatus.isOffline && syncStatus.pending > 0) return 'Offline · will sync when online';
  if (syncStatus.error != null) return syncStatus.error!;
  if (syncStatus.quarantined > 0) {
    return '${syncStatus.quarantined} couldn\'t sync · tap below to retry';
  }
  if (syncStatus.pending > 0) return '${syncStatus.pending} pending changes';
  if (syncStatus.lastSyncedAt == null) return 'Not synced yet';
  return 'Last synced ${formatRelative(syncStatus.lastSyncedAt!)}';
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSize();
    WidgetsBinding.instance.addPostFrameCallback((_) => restoreSyncStatus(ref));
  }

  Future<void> _loadSize() async {
    final s = ref.read(mediaStorageProvider);
    final b = await s.totalSizeBytes();
    if (mounted) {
      setState(() {
        _bytes = b;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authSessionProvider);
    final ctx = ref.watch(captureContextProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final wifiOnly = ref.watch(syncWifiOnlyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account & Sync'),
          authAsync.when(
            loading: () => const ListTile(title: Text('Checking sign-in…')),
            error: (e, _) => ListTile(title: Text('Auth error: $e')),
            data: (session) {
              if (session == null) {
                return ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Sign in'),
                  subtitle: const Text('Sync jobs and notes with your workspace.'),
                  onTap: () => context.pushNamed('sign-in'),
                );
              }
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(session.user['email']?.toString() ?? 'Signed in'),
                    subtitle: Text('Context: ${ctx.workspaceName}'),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.wifi),
                    title: const Text('Sync on Wi‑Fi only'),
                    subtitle: const Text('When enabled, sync waits for Wi‑Fi (best effort).'),
                    value: wifiOnly,
                    onChanged: (v) => ref.read(syncWifiOnlyProvider.notifier).setEnabled(v),
                  ),
                  ListTile(
                    leading: syncStatus.isSyncing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    title: const Text('Sync now'),
                    subtitle: Text(_syncSubtitle(syncStatus)),
                    enabled: ctx.isWorkspace && !syncStatus.isSyncing,
                    onTap: ctx.isWorkspace
                        ? () async {
                            final status = await runManualSync(ref);
                            if (context.mounted) showSyncSnackBar(context, status);
                          }
                        : null,
                  ),
                  if (syncStatus.quarantined > 0)
                    ListTile(
                      leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                      title: Text(
                        syncStatus.quarantined == 1
                            ? '1 item couldn\'t sync'
                            : '${syncStatus.quarantined} items couldn\'t sync',
                      ),
                      subtitle: const Text('Tap to retry or review'),
                      onTap: () => showQuarantinedRetrySheet(context, ref),
                    ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    subtitle: const Text('Keeps local data on this device.'),
                    onTap: () async {
                      await ref.read(authSessionProvider.notifier).logout();
                      await ref.read(captureContextProvider.notifier).selectLocal();
                    },
                  ),
                  if (ctx.isWorkspace && ctx.workspaceId != null)
                    ListTile(
                      leading: const Icon(Icons.exit_to_app),
                      title: const Text('Leave workspace'),
                      subtitle: Text('Leave ${ctx.workspaceName} on this device.'),
                      onTap: () => _confirmLeaveWorkspace(context, ref, ctx.workspaceId!, ctx.workspaceName),
                    ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
                    title: const Text('Delete account', style: TextStyle(color: Colors.red)),
                    subtitle: const Text('Permanently deletes your account. Workspace records you captured stay with each company.'),
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ],
              );
            },
          ),
          const _SectionHeader('Data & Storage'),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('Storage used'),
            subtitle: Text(_loading ? '…' : formatBytes(_bytes ?? 0)),
            trailing: TextButton(onPressed: _loadSize, child: const Text('Refresh')),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Clear all data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently deletes every job, photo, voice note, and note on this device.'),
            onTap: _confirmClearAll,
          ),
          const _SectionHeader('Tags'),
          _TagsManager(),
          const _SectionHeader('What\'s next'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('PDF reports, web dashboard, cloud sync'),
            subtitle: const Text('Coming soon. Tap to get notified when it launches.'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _launchUrl('https://jobsiterecords.com/'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Send feedback'),
            subtitle: const Text('Tell us what works and what is missing.'),
            onTap: () => _launchUrl(
              'mailto:feedback@jobsiterecords.com?subject=${Uri.encodeComponent('Job Site Records feedback')}',
            ),
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Job Site Records'),
            subtitle: Text('jobsiterecords.com · Version 0.1.0\nLocal capture with optional workspace sync.'),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy policy'),
            onTap: () => _launchUrl('https://jobsiterecords.com/privacy'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmLeaveWorkspace(
    BuildContext context,
    WidgetRef ref,
    String workspaceId,
    String workspaceName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave workspace?'),
        content: Text(
          'You will lose access to $workspaceName on this device. '
          'Your local jobs are not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authSessionProvider.notifier).leaveWorkspace(workspaceId);
      await ref.read(jobsRepositoryProvider).purgeWorkspaceJobs(workspaceId);
      await ref.read(captureContextProvider.notifier).selectLocal();
      bumpDataRevision(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Left $workspaceName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and signs you out everywhere. '
          'Records you captured in workspaces stay with those companies. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authSessionProvider.notifier).deleteAccount();
      await ref.read(captureContextProvider.notifier).selectLocal();
      bumpDataRevision(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This deletes every job, every photo, every voice note, and every text note from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final jobsRepo = ref.read(jobsRepositoryProvider);
    final jobs = await jobsRepo.all();
    for (final j in jobs) {
      await jobsRepo.delete(j.id);
    }
    bumpDataRevision(ref);
    await _loadSize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data cleared.')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.subtle,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TagsManager extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: tagsAsync.when(
        data: (tags) => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in tags)
              InputChip(
                label: Text(t.name),
                onDeleted: t.isDefault
                    ? null
                    : () async {
                        await ref.read(tagsRepositoryProvider).delete(t.id);
                        bumpDataRevision(ref);
                      },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 14),
              label: const Text('Add Tag'),
              onPressed: () async {
                final name = await showAddTagDialog(context);
                if (name == null || name.isEmpty) return;
                await ref.read(tagsRepositoryProvider).create(name);
                bumpDataRevision(ref);
              },
            ),
          ],
        ),
        loading: () => const SizedBox(height: 32),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }
}
