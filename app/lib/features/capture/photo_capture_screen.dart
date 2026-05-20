import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/clock.dart';
import '../../data/repositories/items_repository.dart';
import 'widgets/tag_chips.dart';

class _BatchPhoto {
  const _BatchPhoto({required this.path, required this.capturedAt});
  final String path;
  final DateTime capturedAt;
}

class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  bool _permissionDenied = false;
  FlashMode _flash = FlashMode.off;

  final List<_BatchPhoto> _batch = [];
  bool _reviewing = false;
  bool _saving = false;

  final _captionCtrl = TextEditingController();
  final Set<String> _tagIds = {};

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _permissionDenied = true);
        return;
      }
      _cameras = cameras;
      await _bind(cameras[_camIndex]);
    } catch (_) {
      setState(() => _permissionDenied = true);
    }
  }

  Future<void> _bind(CameraDescription desc) async {
    final c = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = c;
    _initFuture = c.initialize().then((_) async {
      try {
        await c.setFlashMode(_flash);
      } catch (_) {}
    });
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      final f = await c.takePicture();
      setState(() {
        _batch.add(_BatchPhoto(path: f.path, capturedAt: now()));
      });
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (f != null) {
      setState(() {
        _batch.add(_BatchPhoto(path: f.path, capturedAt: now()));
      });
    }
  }

  void _removeFromBatch(int index) {
    setState(() {
      _batch.removeAt(index);
      if (_batch.isEmpty && _reviewing) _reviewing = false;
    });
  }

  void _undoLast() {
    if (_batch.isEmpty) return;
    setState(() => _batch.removeLast());
  }

  Future<bool> _confirmDiscard() async {
    if (_batch.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard photos?'),
        content: Text(
          'You have ${_batch.length} unsaved photo${_batch.length == 1 ? '' : 's'}. '
          'Leaving now will discard them.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onBack() async {
    if (_reviewing) {
      setState(() => _reviewing = false);
      return;
    }
    if (await _confirmDiscard()) {
      if (mounted) context.pop();
    }
  }

  void _finishBatch() {
    if (_batch.isEmpty) return;
    setState(() => _reviewing = true);
  }

  Future<void> _saveBatch() async {
    if (_batch.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemsRepositoryProvider).createPhotoBatch(
            jobId: widget.jobId,
            photos: [
              for (final p in _batch)
                BatchPhotoInput(sourceFilePath: p.path, capturedAt: p.capturedAt),
            ],
            caption: _captionCtrl.text,
            tagIds: _tagIds.toList(),
          );
      bumpDataRevision(ref);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {}
  }

  Future<void> _swapCamera() async {
    if (_cameras.length < 2) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    await _controller?.dispose();
    await _bind(_cameras[_camIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('Capture')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined, size: 56, color: AppColors.subtle),
              const SizedBox(height: 12),
              const Text('Camera unavailable',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 6),
              const Text(
                'Allow camera access in system settings, or pick a photo from your gallery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.subtle),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Pick from gallery'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: openAppSettings, child: const Text('Open settings')),
            ],
          ),
        ),
      );
    }

    if (_reviewing) {
      return _BatchReviewView(
        batch: _batch,
        captionCtrl: _captionCtrl,
        selectedTagIds: _tagIds,
        onToggleTag: (id) => setState(() {
          if (!_tagIds.add(id)) _tagIds.remove(id);
        }),
        onAddTag: () async {
          final name = await showAddTagDialog(context);
          if (name == null || name.isEmpty) return;
          final tag = await ref.read(tagsRepositoryProvider).create(name);
          bumpDataRevision(ref);
          setState(() => _tagIds.add(tag.id));
        },
        onRemove: _removeFromBatch,
        onBack: _onBack,
        onSave: _saving ? null : _saveBatch,
        saving: _saving,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(_batch.isEmpty ? 'Capture' : '${_batch.length} photo${_batch.length == 1 ? '' : 's'}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _onBack,
          ),
          actions: [
            IconButton(
              onPressed: _toggleFlash,
              icon: Icon(switch (_flash) {
                FlashMode.off => Icons.flash_off,
                FlashMode.auto => Icons.flash_auto,
                _ => Icons.flash_on,
              }),
            ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done || _controller == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final c = _controller!;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: _CameraPreviewFill(controller: c)),
                if (_batch.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: _BatchStrip(batch: _batch),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      16 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                          tooltip: 'Gallery',
                        ),
                        IconButton(
                          onPressed: _batch.isEmpty ? null : _undoLast,
                          icon: Icon(
                            Icons.undo,
                            color: _batch.isEmpty ? Colors.white24 : Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Remove last',
                        ),
                        GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: const Center(
                              child: CircleAvatar(radius: 30, backgroundColor: AppColors.accent),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _batch.isEmpty ? null : _finishBatch,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(56, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor:
                                _batch.isEmpty ? Colors.white12 : AppColors.accent,
                            foregroundColor:
                                _batch.isEmpty ? Colors.white38 : Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: _cameras.length < 2 ? null : _swapCamera,
                          icon: Icon(
                            Icons.cameraswitch,
                            color: _cameras.length < 2 ? Colors.white24 : Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Flip camera',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BatchStrip extends StatelessWidget {
  const _BatchStrip({required this.batch});
  final List<_BatchPhoto> batch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(batch.last.path),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${batch.length} in batch — keep shooting',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen viewfinder. We seed [FittedBox] with the preview's natural pixel size
/// (rotated for portrait) so the underlying texture has a concrete size to render into;
/// [BoxFit.cover] then scales it up to fill the available area without distortion.
class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final size = controller.value.previewSize;
    if (size == null) {
      return CameraPreview(controller);
    }
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final renderW = isPortrait ? size.height : size.width;
    final renderH = isPortrait ? size.width : size.height;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        child: SizedBox(
          width: renderW,
          height: renderH,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _BatchReviewView extends ConsumerWidget {
  const _BatchReviewView({
    required this.batch,
    required this.captionCtrl,
    required this.selectedTagIds,
    required this.onToggleTag,
    required this.onAddTag,
    required this.onRemove,
    required this.onBack,
    required this.onSave,
    required this.saving,
  });
  final List<_BatchPhoto> batch;
  final TextEditingController captionCtrl;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onAddTag;
  final ValueChanged<int> onRemove;
  final Future<void> Function() onBack;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Tag batch (${batch.length})'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: saving ? null : onBack,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: batch.length,
                        itemBuilder: (context, i) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(batch[i].path), fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: saving ? null : () => onRemove(i),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: captionCtrl,
                        maxLines: 3,
                        maxLength: 160,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Caption (optional)',
                          hintText: 'What does this batch show?',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                        'Applied to every photo in this batch.',
                        style: TextStyle(color: AppColors.subtle, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      tagsAsync.when(
                        data: (tags) => TagChips(
                          allTags: tags,
                          selectedIds: selectedTagIds,
                          onToggle: onToggleTag,
                          onAddTag: onAddTag,
                        ),
                        loading: () => const SizedBox(height: 40),
                        error: (e, _) => Text('Error: $e'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: ElevatedButton.icon(
                  onPressed: batch.isEmpty || saving ? null : onSave,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(saving ? 'Saving…' : 'Save ${batch.length} photo${batch.length == 1 ? '' : 's'}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
