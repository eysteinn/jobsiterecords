import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models/photo_annotation.dart';
import 'widgets/annotation_canvas.dart';

class PhotoAnnotationScreen extends ConsumerStatefulWidget {
  const PhotoAnnotationScreen({super.key, required this.itemId})
      : draftPhotoPath = null,
        draftInitialDocument = const PhotoAnnotationDocument();

  const PhotoAnnotationScreen.draft({
    super.key,
    required this.draftPhotoPath,
    this.draftInitialDocument = const PhotoAnnotationDocument(),
  }) : itemId = null;

  final String? itemId;
  final String? draftPhotoPath;
  final PhotoAnnotationDocument draftInitialDocument;

  bool get isDraft => itemId == null;

  @override
  ConsumerState<PhotoAnnotationScreen> createState() => _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends ConsumerState<PhotoAnnotationScreen> {
  final _canvasKey = GlobalKey<AnnotationCanvasState>();
  AnnotationTool _tool = AnnotationTool.pen;
  Color _color = AnnotationPalette.colors.first;
  bool _saving = false;
  bool _dirty = false;
  bool _loadingPhoto = true;
  String? _photoPath;
  String? _photoLoadError;
  late final Future<PhotoAnnotationDocument?> _annotationsFuture;
  List<PhotoAnnotationShape> _currentShapes = const [];
  bool _shapesSeeded = false;

  @override
  void initState() {
    super.initState();
    if (widget.isDraft) {
      _photoPath = widget.draftPhotoPath;
      _loadingPhoto = false;
      _annotationsFuture = Future.value(widget.draftInitialDocument);
    } else {
      _annotationsFuture = ref.read(itemsRepositoryProvider).loadPhotoAnnotations(widget.itemId!);
      _loadPhotoPath();
    }
  }

  Future<void> _loadPhotoPath() async {
    try {
      final item = await ref.read(itemsRepositoryProvider).byId(widget.itemId!);
      final storage = ref.read(mediaStorageProvider);
      if (!mounted) return;
      setState(() {
        _loadingPhoto = false;
        if (item?.primaryPhoto == null) {
          _photoPath = null;
        } else {
          _photoPath = storage.absolutePath(item!.primaryPhoto!.relativePath);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPhoto = false;
        _photoLoadError = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final shapes = PhotoAnnotationDocument.cloneShapes(_currentShapes);
    final document = PhotoAnnotationDocument(shapes: shapes);
    setState(() => _saving = true);
    try {
      if (widget.isDraft) {
        if (mounted) Navigator.pop(context, document);
        return;
      }

      await ref.read(itemsRepositoryProvider).savePhotoAnnotations(
            itemId: widget.itemId!,
            document: document,
          );
      await _evictRenderedImageCache();
      if (mounted) {
        context.pop();
        bumpDataRevision(ref);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _evictRenderedImageCache() async {
    final updated = await ref.read(itemsRepositoryProvider).byId(widget.itemId!);
    if (updated == null) return;
    final storage = ref.read(mediaStorageProvider);
    final paths = <String>[
      if (updated.annotatedRender != null) storage.absolutePath(updated.annotatedRender!.relativePath),
      if (updated.primaryPhoto != null) storage.absolutePath(updated.primaryPhoto!.relativePath),
    ];
    for (final path in paths) {
      await FileImage(File(path)).evict();
    }
  }

  Future<void> _confirmDiscard() async {
    if (!_dirty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your mark-up has not been saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all mark-up?'),
        content: const Text('This removes every stroke from this photo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _canvasKey.currentState?.clearAll();
      setState(() => _dirty = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPhoto) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Annotate')),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_photoLoadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Annotate')),
        body: Center(child: Text('Error: $_photoLoadError')),
      );
    }

    if (_photoPath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Annotate')),
        body: const Center(child: Text('Photo not found')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: FutureBuilder<PhotoAnnotationDocument?>(
        future: _annotationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: const Text('Annotate')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Annotate')),
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }

          final initial = snapshot.data ?? const PhotoAnnotationDocument();
          if (!_shapesSeeded) {
            _shapesSeeded = true;
            _currentShapes = PhotoAnnotationDocument.cloneShapes(initial.shapes);
          }

          final canvas = _canvasKey.currentState;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Annotate'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _confirmDiscard,
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Saving…' : 'Save',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: AnnotationCanvas(
                    key: _canvasKey,
                    photoPath: _photoPath!,
                    initialDocument: initial,
                    tool: _tool,
                    color: _color,
                    onShapesChanged: (shapes) => setState(() {
                      _currentShapes = shapes;
                      _dirty = true;
                    }),
                  ),
                ),
                AnnotationToolbar(
                  tool: _tool,
                  color: _color,
                  canUndo: canvas?.canUndo ?? false,
                  canRedo: canvas?.canRedo ?? false,
                  onToolChanged: (t) => setState(() => _tool = t),
                  onColorChanged: (c) => setState(() => _color = c),
                  onUndo: () {
                    canvas?.undo();
                    setState(() => _dirty = true);
                  },
                  onRedo: () {
                    canvas?.redo();
                    setState(() => _dirty = true);
                  },
                  onClear: _confirmClear,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
