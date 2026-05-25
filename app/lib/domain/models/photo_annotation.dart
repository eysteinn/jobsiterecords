import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';

enum AnnotationTool { pen, line, arrow, ellipse, rectangle, text }

@immutable
class PhotoAnnotationShape {
  const PhotoAnnotationShape({
    required this.type,
    required this.colorHex,
    this.points = const [],
    this.p1,
    this.p2,
    this.rect,
    this.text,
  });

  final String type;
  final String colorHex;
  final List<List<double>> points;
  final List<double>? p1;
  final List<double>? p2;
  final List<double>? rect;
  final String? text;

  static const strokeWidthNorm = 0.0035;

  PhotoAnnotationShape copyWith({
    String? type,
    String? colorHex,
    List<List<double>>? points,
    List<double>? p1,
    List<double>? p2,
    List<double>? rect,
    String? text,
  }) {
    return PhotoAnnotationShape(
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      points: points ?? this.points,
      p1: p1 ?? this.p1,
      p2: p2 ?? this.p2,
      rect: rect ?? this.rect,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'color': colorHex,
        if (points.isNotEmpty) 'points': points,
        if (p1 != null) 'p1': p1,
        if (p2 != null) 'p2': p2,
        if (rect != null) 'rect': rect,
        if (text != null && text!.isNotEmpty) 'text': text,
      };

  factory PhotoAnnotationShape.fromJson(Map<String, dynamic> json) {
    return PhotoAnnotationShape(
      type: json['type'] as String,
      colorHex: json['color'] as String,
      points: _readPointList(json['points']),
      p1: _readPoint(json['p1']),
      p2: _readPoint(json['p2']),
      rect: _readRect(json['rect']),
      text: json['text'] as String?,
    );
  }

  static List<List<double>> _readPointList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final p in raw)
        if (p is List && p.length >= 2) [ (p[0] as num).toDouble(), (p[1] as num).toDouble() ],
    ];
  }

  static List<double>? _readPoint(Object? raw) {
    if (raw is! List || raw.length < 2) return null;
    return [ (raw[0] as num).toDouble(), (raw[1] as num).toDouble() ];
  }

  static List<double>? _readRect(Object? raw) {
    if (raw is! List || raw.length < 4) return null;
    return [
      (raw[0] as num).toDouble(),
      (raw[1] as num).toDouble(),
      (raw[2] as num).toDouble(),
      (raw[3] as num).toDouble(),
    ];
  }
}

@immutable
class PhotoAnnotationDocument {
  const PhotoAnnotationDocument({this.shapes = const []});

  static const int version = 2;

  final List<PhotoAnnotationShape> shapes;

  bool get isEmpty => shapes.isEmpty;

  PhotoAnnotationDocument copyWith({List<PhotoAnnotationShape>? shapes}) {
    return PhotoAnnotationDocument(shapes: shapes ?? this.shapes);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'shapes': [for (final s in shapes) s.toJson()],
      };

  factory PhotoAnnotationDocument.fromJson(Map<String, dynamic> json) {
    final raw = json['shapes'];
    if (raw is! List) return const PhotoAnnotationDocument();
    return PhotoAnnotationDocument(
      shapes: [
        for (final s in raw)
          if (s is Map<String, dynamic>) PhotoAnnotationShape.fromJson(s),
      ],
    );
  }

  static PhotoAnnotationDocument decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return const PhotoAnnotationDocument();
    return PhotoAnnotationDocument.fromJson(decoded);
  }

  String encode() => jsonEncode(toJson());

  static List<PhotoAnnotationShape> cloneShapes(List<PhotoAnnotationShape> source) {
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
}

class AnnotationPalette {
  static const colors = <Color>[
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFFFFFFFF),
    Color(0xFF111827),
    Color(0xFF22C55E),
  ];

  static String hexFor(Color color) {
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color colorFor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final parsed = int.tryParse(cleaned, radix: 16) ?? 0xEF4444;
    return Color(0xFF000000 | parsed);
  }
}
