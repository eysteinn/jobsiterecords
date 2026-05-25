import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobsiterecords/domain/models/photo_annotation.dart';
import 'package:jobsiterecords/domain/services/photo_annotation_renderer.dart';

void main() {
  test('annotation document json roundtrip', () {
    const doc = PhotoAnnotationDocument(
      shapes: [
        PhotoAnnotationShape(
          type: 'arrow',
          colorHex: '#EF4444',
          p1: [0.1, 0.2],
          p2: [0.8, 0.7],
        ),
        PhotoAnnotationShape(
          type: 'pen',
          colorHex: '#22C55E',
          points: [
            [0.2, 0.3],
            [0.25, 0.35],
            [0.3, 0.4],
          ],
        ),
      ],
    );

    final decoded = PhotoAnnotationDocument.decode(doc.encode());
    expect(decoded.shapes.length, 2);
    expect(decoded.shapes.first.type, 'arrow');
    expect(decoded.shapes.last.points.length, 3);
  });

  test('text label shape roundtrips in document json', () {
    const doc = PhotoAnnotationDocument(
      shapes: [
        PhotoAnnotationShape(
          type: 'text',
          colorHex: '#111827',
          p1: [0.4, 0.6],
          text: 'Leak here',
        ),
      ],
    );

    final decoded = PhotoAnnotationDocument.decode(doc.encode());
    expect(decoded.shapes.single.text, 'Leak here');
    expect(decoded.shapes.single.type, 'text');
  });

  test('layout maps normalized coordinates both ways', () {
    const layout = ImageLayoutMetrics(
      imageSize: Size(4000, 3000),
      canvasSize: Size(400, 300),
      destRect: Rect.fromLTWH(0, 0, 400, 300),
    );

    const norm = Offset(0.5, 0.25);
    final display = layout.normToDisplay(norm);
    expect(display, const Offset(200, 75));

    final back = layout.displayToNorm(display);
    expect(back.dx, closeTo(0.5, 0.001));
    expect(back.dy, closeTo(0.25, 0.001));
  });
}
