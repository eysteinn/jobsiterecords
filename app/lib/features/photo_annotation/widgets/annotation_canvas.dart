import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/models/photo_annotation.dart';
import '../../../domain/services/photo_annotation_renderer.dart';

class AnnotationCanvas extends StatefulWidget {
  const AnnotationCanvas({
    super.key,
    required this.photoPath,
    required this.initialDocument,
    required this.tool,
    required this.color,
    required this.onShapesChanged,
  });

  final String photoPath;
  final PhotoAnnotationDocument initialDocument;
  final AnnotationTool tool;
  final Color color;
  final ValueChanged<List<PhotoAnnotationShape>> onShapesChanged;

  @override
  State<AnnotationCanvas> createState() => AnnotationCanvasState();
}

class AnnotationCanvasState extends State<AnnotationCanvas> {
  ui.Image? _image;
  Size? _imageSize;
  ImageLayoutMetrics? _layout;
  late List<PhotoAnnotationShape> _shapes;
  final List<List<PhotoAnnotationShape>> _undoStack = [];
  final List<List<PhotoAnnotationShape>> _redoStack = [];
  PhotoAnnotationShape? _preview;
  List<List<double>> _penPoints = const [];
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _shapes = List<PhotoAnnotationShape>.from(widget.initialDocument.shapes);
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant AnnotationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) {
      _loadImage();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.photoPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() {
      _image?.dispose();
      _image = frame.image;
      _imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    });
  }

  List<PhotoAnnotationShape> get shapes => List.unmodifiable(_shapes);

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_cloneShapes(_shapes));
    _shapes = _undoStack.removeLast();
    _notifyChanged();
    setState(() => _preview = null);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_cloneShapes(_shapes));
    _shapes = _redoStack.removeLast();
    _notifyChanged();
    setState(() => _preview = null);
  }

  Future<bool> clearAll() async {
    if (_shapes.isEmpty) return false;
    _pushUndo();
    _shapes = [];
    _notifyChanged();
    setState(() => _preview = null);
    return true;
  }

  void _pushUndo() {
    _undoStack.add(_cloneShapes(_shapes));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  List<PhotoAnnotationShape> _cloneShapes(List<PhotoAnnotationShape> source) {
    return [
      for (final s in source)
        PhotoAnnotationShape(
          type: s.type,
          colorHex: s.colorHex,
          points: [for (final p in s.points) [p[0], p[1]]],
          p1: s.p1 == null ? null : [s.p1![0], s.p1![1]],
          p2: s.p2 == null ? null : [s.p2![0], s.p2![1]],
          rect: s.rect == null ? null : [s.rect![0], s.rect![1], s.rect![2], s.rect![3]],
          text: s.text,
        ),
    ];
  }

  void _notifyChanged() => widget.onShapesChanged(_shapes);

  void _commitShape(PhotoAnnotationShape shape) {
    _pushUndo();
    _shapes = [..._shapes, shape];
    _notifyChanged();
    setState(() {
      _preview = null;
      _penPoints = const [];
      _dragStart = null;
    });
  }

  void _onPanStart(DragStartDetails details) {
    final layout = _layout;
    if (layout == null) return;
    final norm = layout.displayToNorm(details.localPosition);
    final colorHex = AnnotationPalette.hexFor(widget.color);

    switch (widget.tool) {
      case AnnotationTool.pen:
        _penPoints = [[norm.dx, norm.dy]];
        _preview = PhotoAnnotationShape(type: 'pen', colorHex: colorHex, points: _penPoints);
      case AnnotationTool.line:
      case AnnotationTool.arrow:
      case AnnotationTool.ellipse:
      case AnnotationTool.rectangle:
        _dragStart = norm;
        _preview = _shapeForDrag(widget.tool, colorHex, norm, norm);
      case AnnotationTool.text:
        break;
    }
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final layout = _layout;
    if (layout == null) return;
    final norm = layout.displayToNorm(details.localPosition);
    final colorHex = AnnotationPalette.hexFor(widget.color);

    switch (widget.tool) {
      case AnnotationTool.pen:
        _penPoints = [..._penPoints, [norm.dx, norm.dy]];
        _preview = PhotoAnnotationShape(type: 'pen', colorHex: colorHex, points: _penPoints);
      case AnnotationTool.line:
      case AnnotationTool.arrow:
      case AnnotationTool.ellipse:
      case AnnotationTool.rectangle:
        final start = _dragStart ?? norm;
        _preview = _shapeForDrag(widget.tool, colorHex, start, norm);
      case AnnotationTool.text:
        break;
    }
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    final preview = _preview;
    if (preview == null) return;

    if (preview.type == 'pen') {
      if (_penPoints.isNotEmpty) _commitShape(preview);
      return;
    }

    if (preview.p1 == null || preview.p2 == null) {
      setState(() => _preview = null);
      return;
    }

    if (preview.type == 'ellipse' || preview.type == 'rectangle') {
      final rect = preview.rect;
      if (rect == null || rect[2].abs() < 0.005 || rect[3].abs() < 0.005) {
        setState(() => _preview = null);
        return;
      }
    } else {
      final dx = preview.p2![0] - preview.p1![0];
      final dy = preview.p2![1] - preview.p1![1];
      if ((dx * dx + dy * dy) < 0.00001) {
        setState(() => _preview = null);
        return;
      }
    }

    _commitShape(preview);
  }

  PhotoAnnotationShape _shapeForDrag(
    AnnotationTool tool,
    String colorHex,
    Offset start,
    Offset end,
  ) {
    final type = switch (tool) {
      AnnotationTool.line => 'line',
      AnnotationTool.arrow => 'arrow',
      AnnotationTool.ellipse => 'ellipse',
      AnnotationTool.rectangle => 'rectangle',
      AnnotationTool.pen => 'pen',
      AnnotationTool.text => 'text',
    };
    if (tool == AnnotationTool.ellipse || tool == AnnotationTool.rectangle) {
      final left = start.dx < end.dx ? start.dx : end.dx;
      final top = start.dy < end.dy ? start.dy : end.dy;
      final width = (end.dx - start.dx).abs();
      final height = (end.dy - start.dy).abs();
      return PhotoAnnotationShape(
        type: type,
        colorHex: colorHex,
        rect: [left, top, width, height],
      );
    }
    return PhotoAnnotationShape(
      type: type,
      colorHex: colorHex,
      p1: [start.dx, start.dy],
      p2: [end.dx, end.dy],
    );
  }

  Future<void> _onTextTap(TapUpDetails details) async {
    if (widget.tool != AnnotationTool.text) return;
    final layout = _layout;
    if (layout == null) return;
    final norm = layout.displayToNorm(details.localPosition);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TextLabelDialog(),
    );
    if (!mounted || text == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _commitShape(
      PhotoAnnotationShape(
        type: 'text',
        colorHex: AnnotationPalette.hexFor(widget.color),
        p1: [norm.dx, norm.dy],
        text: trimmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final imageSize = _imageSize;
    if (image == null || imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = ImageLayoutMetrics.compute(imageSize, canvasSize);
        _layout = layout;

        return GestureDetector(
          onTapUp: widget.tool == AnnotationTool.text ? _onTextTap : null,
          onPanStart: widget.tool == AnnotationTool.text ? null : _onPanStart,
          onPanUpdate: widget.tool == AnnotationTool.text ? null : _onPanUpdate,
          onPanEnd: widget.tool == AnnotationTool.text ? null : _onPanEnd,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _BackgroundImagePainter(image: image, destRect: layout.destRect),
                ),
                CustomPaint(
                  painter: PhotoAnnotationPainter(
                    shapes: _shapes,
                    layout: layout,
                    preview: _preview,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundImagePainter extends CustomPainter {
  const _BackgroundImagePainter({required this.image, required this.destRect});

  final ui.Image image;
  final Rect destRect;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destRect,
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.destRect != destRect;
  }
}

class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.tool,
    required this.color,
    required this.canUndo,
    required this.canRedo,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  final AnnotationTool tool;
  final Color color;
  final bool canUndo;
  final bool canRedo;
  final ValueChanged<AnnotationTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolButton(
                      icon: Icons.gesture,
                      label: 'Pen',
                      selected: tool == AnnotationTool.pen,
                      onTap: () => onToolChanged(AnnotationTool.pen),
                    ),
                    _ToolButton(
                      icon: Icons.horizontal_rule,
                      label: 'Line',
                      selected: tool == AnnotationTool.line,
                      onTap: () => onToolChanged(AnnotationTool.line),
                    ),
                    _ToolButton(
                      icon: Icons.arrow_right_alt,
                      label: 'Arrow',
                      selected: tool == AnnotationTool.arrow,
                      onTap: () => onToolChanged(AnnotationTool.arrow),
                    ),
                    _ToolButton(
                      icon: Icons.circle_outlined,
                      label: 'Circle',
                      selected: tool == AnnotationTool.ellipse,
                      onTap: () => onToolChanged(AnnotationTool.ellipse),
                    ),
                    _ToolButton(
                      icon: Icons.crop_square,
                      label: 'Box',
                      selected: tool == AnnotationTool.rectangle,
                      onTap: () => onToolChanged(AnnotationTool.rectangle),
                    ),
                    _ToolButton(
                      icon: Icons.text_fields,
                      label: 'Text',
                      selected: tool == AnnotationTool.text,
                      onTap: () => onToolChanged(AnnotationTool.text),
                    ),
                    IconButton(
                      tooltip: 'Undo',
                      onPressed: canUndo ? onUndo : null,
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      onPressed: canRedo ? onRedo : null,
                      icon: const Icon(Icons.redo),
                    ),
                    IconButton(
                      tooltip: 'Clear all',
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(width: 8),
                  for (final c in AnnotationPalette.colors)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onColorChanged(c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: Border.all(
                              color: color == c ? AppColors.accent : const Color(0xFFD1D5DB),
                              width: color == c ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFEF3C7) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accent : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              Text(label, style: const TextStyle(fontSize: 10, color: AppColors.subtle)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextLabelDialog extends StatefulWidget {
  const _TextLabelDialog();

  @override
  State<_TextLabelDialog> createState() => _TextLabelDialogState();
}

class _TextLabelDialogState extends State<_TextLabelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add label'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(
          hintText: 'e.g. Leak here',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
