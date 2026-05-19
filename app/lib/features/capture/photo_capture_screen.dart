import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import 'widgets/tag_chips.dart';

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
  String? _capturedPath;
  bool _saving = false;
  bool _permissionDenied = false;
  FlashMode _flash = FlashMode.off;

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
      setState(() => _capturedPath = f.path);
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (f != null) {
      setState(() => _capturedPath = f.path);
    }
  }

  Future<void> _save() async {
    if (_capturedPath == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemsRepositoryProvider).createPhoto(
            jobId: widget.jobId,
            sourceFilePath: _capturedPath!,
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

    if (_capturedPath != null) {
      return _ReviewView(
        path: _capturedPath!,
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
        onRetake: () => setState(() => _capturedPath = null),
        onSave: _saving ? null : _save,
        saving: _saving,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Capture'),
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
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28, left: 16, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
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
                      IconButton(
                        onPressed: _cameras.length < 2 ? null : _swapCamera,
                        icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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

class _ReviewView extends ConsumerWidget {
  const _ReviewView({
    required this.path,
    required this.captionCtrl,
    required this.selectedTagIds,
    required this.onToggleTag,
    required this.onAddTag,
    required this.onRetake,
    required this.onSave,
    required this.saving,
  });
  final String path;
  final TextEditingController captionCtrl;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onAddTag;
  final VoidCallback onRetake;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(path), fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: captionCtrl,
                      maxLines: 3,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Caption (optional)',
                        hintText: 'What does this photo show?',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : onRetake,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Retake'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(saving ? 'Saving…' : 'Save Photo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
