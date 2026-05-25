import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/file_utils.dart';
import '../../core/format.dart';
import '../../data/repositories/items_repository.dart';
import 'widgets/tag_chips.dart';

class FileCaptureScreen extends ConsumerStatefulWidget {
  const FileCaptureScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<FileCaptureScreen> createState() => _FileCaptureScreenState();
}

class _FileCaptureScreenState extends ConsumerState<FileCaptureScreen> {
  final _captionCtrl = TextEditingController();
  final Set<String> _tagIds = {};
  bool _saving = false;
  bool _picking = true;
  String? _sourcePath;
  String? _originalName;
  String? _mimeType;
  int? _sizeBytes;
  String? _pickError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickFile());
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _picking = true;
      _pickError = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedUploadExtensions,
        allowMultiple: false,
        withData: false,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        context.pop();
        return;
      }
      final picked = result.files.single;
      final path = picked.path;
      if (path == null) {
        setState(() {
          _picking = false;
          _pickError = 'Could not read the selected file.';
        });
        return;
      }
      final name = picked.name;
      if (!isAllowedUploadExtension(name)) {
        setState(() {
          _picking = false;
          _pickError = 'Unsupported file type. Use PDF or image files.';
        });
        return;
      }
      final size = picked.size;
      if (size > maxUploadBytes) {
        setState(() {
          _picking = false;
          _pickError = 'File is too large (${formatBytes(size)}). Maximum is ${formatBytes(maxUploadBytes)}.';
        });
        return;
      }
      setState(() {
        _picking = false;
        _sourcePath = path;
        _originalName = name;
        _mimeType = picked.extension != null ? mimeFromExtension('.${picked.extension}') : mimeFromFilename(name);
        _sizeBytes = size;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _pickError = 'Could not open file picker.';
      });
    }
  }

  Future<void> _save() async {
    final path = _sourcePath;
    final name = _originalName;
    final mime = _mimeType;
    if (path == null || name == null || mime == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemsRepositoryProvider).createFile(
            jobId: widget.jobId,
            sourceFilePath: path,
            originalFilename: name,
            mimeType: mime,
            caption: _captionCtrl.text,
            tagIds: _tagIds.toList(),
          );
      bumpDataRevision(ref);
      if (mounted) context.pop();
    } on FileTooLargeException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File is too large (${formatBytes(e.sizeBytes)}).')),
        );
      }
    } on UnsupportedFileTypeException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unsupported file type.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_picking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add File')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_pickError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add File')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_pickError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink)),
                const SizedBox(height: 16),
                FilledButton(onPressed: _pickFile, child: const Text('Try again')),
                TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      );
    }

    final tagsAsync = ref.watch(tagsProvider);
    final isPdf = _mimeType == 'application/pdf' ||
        (_originalName?.toLowerCase().endsWith('.pdf') ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add File'),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file_outlined,
                    size: 40,
                    color: isPdf ? const Color(0xFFDC2626) : AppColors.subtle,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _originalName ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_sizeBytes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${formatBytes(_sizeBytes!)} · ${_mimeType ?? ''}',
                              style: const TextStyle(color: AppColors.subtle, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _pickFile, child: const Text('Change')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionCtrl,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                hintText: 'e.g. Home Depot receipt',
              ),
            ),
            const SizedBox(height: 8),
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
