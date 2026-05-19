import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/item.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/timeline_item.dart';
import '../capture/widgets/tag_chips.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _editing = false;
  late TextEditingController _captionCtrl;
  late TextEditingController _bodyCtrl;
  Set<String>? _tagIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _enterEdit(TimelineItem t) {
    _captionCtrl.text = t.item.caption ?? '';
    _bodyCtrl.text = t.item.body ?? '';
    _tagIds = t.tags.map((e) => e.id).toSet();
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (_tagIds == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemsRepositoryProvider).updateMeta(
            itemId: widget.itemId,
            caption: _captionCtrl.text,
            body: _bodyCtrl.text,
            tagIds: _tagIds!.toList(),
          );
      bumpDataRevision(ref);
      setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This permanently removes the item from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(itemsRepositoryProvider).delete(widget.itemId);
    bumpDataRevision(ref);
    if (mounted) context.pop();
  }

  Future<void> _share(TimelineItem t) async {
    final storage = ref.read(mediaStorageProvider);
    final files = <XFile>[];
    if (t.primaryPhoto != null) {
      files.add(XFile(storage.absolutePath(t.primaryPhoto!.relativePath)));
    }
    if (t.voiceNote != null) {
      files.add(XFile(storage.absolutePath(t.voiceNote!.relativePath)));
    }
    final caption = (t.item.caption ?? '').trim();
    final body = (t.item.body ?? '').trim();
    final text = [caption, body].where((s) => s.isNotEmpty).join('\n\n');
    if (files.isEmpty) {
      await Share.share(text.isEmpty ? '(empty note)' : text);
    } else {
      await Share.shareXFiles(files, text: text.isEmpty ? null : text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemProvider(widget.itemId));
    final storage = ref.watch(mediaStorageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit' : 'Item'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            )
          else
            itemAsync.maybeWhen(
              data: (t) => t == null
                  ? const SizedBox.shrink()
                  : Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () => _share(t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _enterEdit(t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _delete,
                        ),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: itemAsync.when(
        data: (t) {
          if (t == null) return const Center(child: Text('Item not found'));
          return _editing ? _editView(t) : _view(t, storage.absolutePath);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _view(TimelineItem t, String Function(String) absolutePath) {
    final hasPhoto = t.primaryPhoto != null;
    final body = (t.item.body ?? '').trim();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(absolutePath(t.primaryPhoto!.relativePath)), fit: BoxFit.cover),
          ),
        if (t.voiceNote != null) ...[
          if (hasPhoto) const SizedBox(height: 14),
          _AudioPlayer(path: absolutePath(t.voiceNote!.relativePath)),
        ],
        const SizedBox(height: 14),
        Text(
          '${formatDay(t.item.capturedAt)} · ${formatTime(t.item.capturedAt)}',
          style: const TextStyle(color: AppColors.subtle, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(t.item.kind.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        if ((t.item.caption ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(t.item.caption!, style: const TextStyle(fontSize: 16, color: AppColors.ink)),
        ],
        if (body.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(body, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          ),
        ],
        if (t.tags.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TagWrap(tags: t.tags),
        ],
      ],
    );
  }

  Widget _editView(TimelineItem t) {
    final tagsAsync = ref.watch(tagsProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _captionCtrl,
          maxLength: 160,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Caption'),
        ),
        const SizedBox(height: 12),
        if (t.item.kind == ItemKind.note)
          TextField(
            controller: _bodyCtrl,
            minLines: 4,
            maxLines: 12,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        tagsAsync.when(
          data: (tags) => TagChips(
            allTags: tags,
            selectedIds: _tagIds ?? const {},
            onToggle: (id) => setState(() {
              _tagIds = {...(_tagIds ?? const {})};
              if (!_tagIds!.add(id)) _tagIds!.remove(id);
            }),
            onAddTag: () async {
              final name = await showAddTagDialog(context);
              if (name == null || name.isEmpty) return;
              final tag = await ref.read(tagsRepositoryProvider).create(name);
              bumpDataRevision(ref);
              setState(() {
                _tagIds = {...(_tagIds ?? const {}), tag.id};
              });
            },
          ),
          loading: () => const SizedBox(height: 40),
          error: (e, _) => Text('Error: $e'),
        ),
      ],
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.tags});
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(tag.name, style: const TextStyle(color: Color(0xFF92400E), fontSize: 12)),
          ),
      ],
    );
  }
}

class _AudioPlayer extends StatefulWidget {
  const _AudioPlayer({required this.path});
  final String path;
  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.setFilePath(widget.path).then((d) {
      if (d != null) setState(() => _duration = d);
    });
    _player.positionStream.listen((p) => setState(() => _position = p));
    _player.playerStateStream.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.playing;
    final dur = _player.duration ?? _duration;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              if (playing) {
                _player.pause();
              } else {
                _player.play();
              }
            },
            icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Slider(
                  min: 0,
                  max: dur.inMilliseconds.toDouble().clamp(1, double.infinity),
                  value: _position.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                  onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                  activeColor: AppColors.accent,
                ),
                Text(
                  '${formatDuration(_position)} / ${formatDuration(dur)}',
                  style: const TextStyle(color: AppColors.subtle, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
