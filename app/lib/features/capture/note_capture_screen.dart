import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import 'widgets/tag_chips.dart';

class NoteCaptureScreen extends ConsumerStatefulWidget {
  const NoteCaptureScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<NoteCaptureScreen> createState() => _NoteCaptureScreenState();
}

class _NoteCaptureScreenState extends ConsumerState<NoteCaptureScreen> {
  final _bodyCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  final Set<String> _tagIds = {};
  bool _saving = false;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_bodyCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemsRepositoryProvider).createNote(
            jobId: widget.jobId,
            body: _bodyCtrl.text,
            caption: _captionCtrl.text,
            tagIds: _tagIds.toList(),
          );
      bumpDataRevision(ref);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Note'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _captionCtrl,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Title / caption (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              minLines: 6,
              maxLines: 14,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'What do you want to remember?',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            tagsAsync.when(
              data: (tags) => TagChips(
                allTags: tags,
                selectedIds: _tagIds,
                onToggle: (id) => setState(() {
                  if (!_tagIds.add(id)) _tagIds.remove(id);
                }),
                onAddTag: () async {
                  final name = await showAddTagDialog(context);
                  if (name == null || name.isEmpty) return;
                  final tag = await ref.read(tagsRepositoryProvider).create(name);
                  bumpDataRevision(ref);
                  setState(() => _tagIds.add(tag.id));
                },
              ),
              loading: () => const SizedBox(height: 40),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
