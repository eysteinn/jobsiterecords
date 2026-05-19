import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/timeline_item.dart';
import '../../domain/services/export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late Set<String> _selected;
  bool _initialized = false;
  bool _exporting = false;
  bool _captions = true;
  bool _tags = true;
  bool _timestamps = true;
  bool _notes = true;
  bool _oldestFirst = true;
  String? _lastError;

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(jobTimelineProvider(widget.jobId));
    final jobAsync = ref.watch(jobProvider(widget.jobId));
    final storage = ref.watch(mediaStorageProvider);
    return Scaffold(
      appBar: AppBar(
        title: jobAsync.maybeWhen(
          data: (j) => Text('Export — ${j?.name ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
          orElse: () => const Text('Export'),
        ),
      ),
      body: timelineAsync.when(
        data: (items) {
          if (!_initialized) {
            _selected = items.map((t) => t.item.id).toSet();
            _initialized = true;
          }
          if (items.isEmpty) {
            return const Center(child: Text('No items to export.'));
          }
          return Column(
            children: [
              _Options(
                captions: _captions,
                tags: _tags,
                timestamps: _timestamps,
                notes: _notes,
                oldestFirst: _oldestFirst,
                onChange: ({bool? c, bool? t, bool? ts, bool? n, bool? o}) => setState(() {
                  if (c != null) _captions = c;
                  if (t != null) _tags = t;
                  if (ts != null) _timestamps = ts;
                  if (n != null) _notes = n;
                  if (o != null) _oldestFirst = o;
                }),
                onSelectAll: () => setState(() => _selected = items.map((e) => e.item.id).toSet()),
                onClear: () => setState(() => _selected = {}),
                selectedCount: _selected.length,
                total: items.length,
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final t = items[i];
                    return _Row(
                      t: t,
                      selected: _selected.contains(t.item.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(t.item.id);
                          } else {
                            _selected.remove(t.item.id);
                          }
                        });
                      },
                      coverPath: t.primaryPhoto == null
                          ? null
                          : storage.absolutePath(t.primaryPhoto!.relativePath),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ElevatedButton.icon(
                onPressed: (_selected.isEmpty || _exporting) ? null : _doExport,
                icon: _exporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.ios_share),
                label: Text(_exporting ? 'Building zip…' : 'Share ${_selected.length} item${_selected.length == 1 ? '' : 's'}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doExport() async {
    setState(() {
      _exporting = true;
      _lastError = null;
    });
    try {
      final result = await ref.read(exportServiceProvider).exportJob(
            jobId: widget.jobId,
            selectedItemIds: _selected,
            options: ExportOptions(
              includeCaptions: _captions,
              includeTags: _tags,
              includeTimestamps: _timestamps,
              includeNotes: _notes,
              oldestFirst: _oldestFirst,
            ),
          );
      await Share.shareXFiles(
        [XFile(result.zipFile.path)],
        subject: 'Job Site Records export',
        text: '${result.itemCount} items · ${formatBytes(result.sizeBytes)}',
      );
    } catch (e) {
      setState(() => _lastError = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.captions,
    required this.tags,
    required this.timestamps,
    required this.notes,
    required this.oldestFirst,
    required this.onChange,
    required this.onSelectAll,
    required this.onClear,
    required this.selectedCount,
    required this.total,
  });
  final bool captions, tags, timestamps, notes, oldestFirst;
  final void Function({bool? c, bool? t, bool? ts, bool? n, bool? o}) onChange;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final int selectedCount, total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$selectedCount of $total selected',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
              const Spacer(),
              TextButton(onPressed: onSelectAll, child: const Text('All')),
              TextButton(onPressed: onClear, child: const Text('None')),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: -6,
            children: [
              _toggle('Captions', captions, (v) => onChange(c: v)),
              _toggle('Tags', tags, (v) => onChange(t: v)),
              _toggle('Timestamps', timestamps, (v) => onChange(ts: v)),
              _toggle('Notes', notes, (v) => onChange(n: v)),
              _toggle('Oldest first', oldestFirst, (v) => onChange(o: v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool v, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: v,
      onSelected: onChanged,
      selectedColor: AppColors.accent,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.t, required this.selected, required this.onChanged, required this.coverPath});
  final TimelineItem t;
  final bool selected;
  final ValueChanged<bool?> onChanged;
  final String? coverPath;

  @override
  Widget build(BuildContext context) {
    final cap = (t.item.caption ?? '').trim();
    return CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      activeColor: AppColors.accent,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        cap.isEmpty ? t.item.kind.label : cap,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${formatDay(t.item.capturedAt)} · ${formatTime(t.item.capturedAt)}'),
      secondary: SizedBox(
        width: 44,
        height: 44,
        child: coverPath != null && File(coverPath!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(coverPath!), fit: BoxFit.cover),
              )
            : Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  switch (t.item.kind.label) {
                    'Photo' => Icons.image_outlined,
                    'Voice Note' => Icons.mic_none,
                    _ => Icons.sticky_note_2_outlined,
                  },
                  color: AppColors.subtle,
                ),
              ),
      ),
    );
  }
}
