import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../capture/widgets/tag_chips.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
            subtitle: Text('jobsiterecords.com · Version 0.1.0 — local-only MVP.\nData stays on your device.'),
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
