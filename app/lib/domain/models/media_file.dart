import 'package:flutter/foundation.dart';

enum MediaRole {
  primaryPhoto,
  voiceNote,
  attachment;

  String get dbValue => switch (this) {
        MediaRole.primaryPhoto => 'primary_photo',
        MediaRole.voiceNote => 'voice_note',
        MediaRole.attachment => 'attachment',
      };

  static MediaRole fromDb(String v) => switch (v) {
        'primary_photo' => MediaRole.primaryPhoto,
        'voice_note' => MediaRole.voiceNote,
        _ => MediaRole.attachment,
      };
}

@immutable
class MediaFile {
  final String id;
  final String itemId;
  final MediaRole role;
  final String relativePath;
  final String mimeType;
  final int? width;
  final int? height;
  final int? durationMs;
  final int sizeBytes;
  final DateTime createdAt;

  const MediaFile({
    required this.id,
    required this.itemId,
    required this.role,
    required this.relativePath,
    required this.mimeType,
    this.width,
    this.height,
    this.durationMs,
    required this.sizeBytes,
    required this.createdAt,
  });

  Map<String, Object?> toDb() => {
        'id': id,
        'item_id': itemId,
        'role': role.dbValue,
        'relative_path': relativePath,
        'mime_type': mimeType,
        'width': width,
        'height': height,
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
        'created_at': createdAt.toIso8601String(),
      };

  factory MediaFile.fromDb(Map<String, Object?> r) => MediaFile(
        id: r['id']! as String,
        itemId: r['item_id']! as String,
        role: MediaRole.fromDb(r['role']! as String),
        relativePath: r['relative_path']! as String,
        mimeType: r['mime_type']! as String,
        width: r['width'] as int?,
        height: r['height'] as int?,
        durationMs: r['duration_ms'] as int?,
        sizeBytes: (r['size_bytes'] as int?) ?? 0,
        createdAt: DateTime.parse(r['created_at']! as String),
      );
}
