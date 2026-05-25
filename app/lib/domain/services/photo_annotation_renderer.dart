import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/photo_annotation.dart';

class ImageLayoutMetrics {
  const ImageLayoutMetrics({
    required this.imageSize,
    required this.canvasSize,
    required this.destRect,
  });

  final Size imageSize;
  final Size canvasSize;
  final Rect destRect;

  static ImageLayoutMetrics compute(Size imageSize, Size canvasSize) {
    final fit = applyBoxFit(BoxFit.contain, imageSize, canvasSize);
    final dest = Alignment.center.inscribe(fit.destination, Offset.zero & canvasSize);
    return ImageLayoutMetrics(imageSize: imageSize, canvasSize: canvasSize, destRect: dest);
  }

  Offset normToDisplay(Offset norm) {
    return Offset(
      destRect.left + norm.dx * destRect.width,
      destRect.top + norm.dy * destRect.height,
    );
  }

  Offset displayToNorm(Offset display) {
    if (destRect.width <= 0 || destRect.height <= 0) return Offset.zero;
    return Offset(
      ((display.dx - destRect.left) / destRect.width).clamp(0.0, 1.0),
      ((display.dy - destRect.top) / destRect.height).clamp(0.0, 1.0),
    );
  }

  Offset normPoint(List<double> point) => normToDisplay(Offset(point[0], point[1]));

  Rect normRect(List<double> rect) {
    final topLeft = normToDisplay(Offset(rect[0], rect[1]));
    final bottomRight = normToDisplay(Offset(rect[0] + rect[2], rect[1] + rect[3]));
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

class PhotoAnnotationRenderer {
  static double strokeWidthPx(double imageWidth) =>
      math.max(2, imageWidth * PhotoAnnotationShape.strokeWidthNorm);

  static void paintShapes(
    Canvas canvas, {
    required List<PhotoAnnotationShape> shapes,
    required ImageLayoutMetrics layout,
    PhotoAnnotationShape? preview,
  }) {
    final all = preview == null ? shapes : [...shapes, preview];
    for (final shape in all) {
      _paintShape(canvas, shape, layout);
    }
  }

  static Future<Uint8List> renderJpeg({
    required String photoPath,
    required PhotoAnnotationDocument document,
    int quality = 90,
  }) async {
    final bytes = await File(photoPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode photo at $photoPath');
    }

    final uiImage = await _uiImageFromDecoded(decoded);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(uiImage, Offset.zero, Paint());
    uiImage.dispose();

    final layout = ImageLayoutMetrics.compute(
      Size(decoded.width.toDouble(), decoded.height.toDouble()),
      Size(decoded.width.toDouble(), decoded.height.toDouble()),
    );
    paintShapes(canvas, shapes: document.shapes, layout: layout);

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(decoded.width, decoded.height);
    picture.dispose();

    final rgba = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    rendered.dispose();
    if (rgba == null) throw StateError('Failed to read rendered image bytes');

    final image = img.Image.fromBytes(
      width: decoded.width,
      height: decoded.height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  static Future<ui.Image> _uiImageFromDecoded(img.Image decoded) async {
    final rgba = decoded.getBytes(order: img.ChannelOrder.rgba);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      decoded.width,
      decoded.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  static void _paintShape(Canvas canvas, PhotoAnnotationShape shape, ImageLayoutMetrics layout) {
    final color = AnnotationPalette.colorFor(shape.colorHex);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidthPx(layout.imageSize.width)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (color.value == 0xFFFFFFFF) {
      stroke.color = Colors.white;
    }

    switch (shape.type) {
      case 'pen':
        _paintPen(canvas, shape.points, stroke, layout);
      case 'line':
        final p1 = shape.p1;
        final p2 = shape.p2;
        if (p1 == null || p2 == null) return;
        canvas.drawLine(layout.normPoint(p1), layout.normPoint(p2), stroke);
      case 'arrow':
        final p1 = shape.p1;
        final p2 = shape.p2;
        if (p1 == null || p2 == null) return;
        _paintArrow(canvas, layout.normPoint(p1), layout.normPoint(p2), stroke);
      case 'ellipse':
        final rect = shape.rect;
        if (rect == null) return;
        canvas.drawOval(layout.normRect(rect), stroke);
      case 'rectangle':
        final rect = shape.rect;
        if (rect == null) return;
        canvas.drawRect(layout.normRect(rect), stroke);
    }
  }

  static void _paintPen(
    Canvas canvas,
    List<List<double>> points,
    Paint stroke,
    ImageLayoutMetrics layout,
  ) {
    if (points.length < 2) {
      if (points.length == 1) {
        canvas.drawCircle(layout.normPoint(points.first), stroke.strokeWidth / 2, stroke);
      }
      return;
    }
    final path = Path()..moveTo(layout.normPoint(points.first).dx, layout.normPoint(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final p = layout.normPoint(points[i]);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, stroke);
  }

  static void _paintArrow(Canvas canvas, Offset start, Offset end, Paint stroke) {
    canvas.drawLine(start, end, stroke);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final headLength = stroke.strokeWidth * 4;
    const headAngle = math.pi / 7;
    final p1 = Offset(
      end.dx - headLength * math.cos(angle - headAngle),
      end.dy - headLength * math.sin(angle - headAngle),
    );
    final p2 = Offset(
      end.dx - headLength * math.cos(angle + headAngle),
      end.dy - headLength * math.sin(angle + headAngle),
    );
    canvas.drawLine(end, p1, stroke);
    canvas.drawLine(end, p2, stroke);
  }
}

class PhotoAnnotationPainter extends CustomPainter {
  PhotoAnnotationPainter({
    required this.shapes,
    required this.layout,
    this.preview,
  });

  final List<PhotoAnnotationShape> shapes;
  final ImageLayoutMetrics layout;
  final PhotoAnnotationShape? preview;

  @override
  void paint(Canvas canvas, Size size) {
    PhotoAnnotationRenderer.paintShapes(
      canvas,
      shapes: shapes,
      layout: layout,
      preview: preview,
    );
  }

  @override
  bool shouldRepaint(covariant PhotoAnnotationPainter oldDelegate) {
    return oldDelegate.shapes != shapes ||
        oldDelegate.preview != preview ||
        oldDelegate.layout.destRect != layout.destRect;
  }
}
