import 'package:flutter/foundation.dart';

import '../../sync/sync_state.dart';

enum MediaRole {
  primaryPhoto,
  voiceNote,
  attachment,
  file,
  annotationOverlay,
  annotatedRender;

  String get dbValue => switch (this) {
        MediaRole.primaryPhoto => 'primary_photo',
        MediaRole.voiceNote => 'voice_note',
        MediaRole.attachment => 'attachment',
        MediaRole.file => 'file',
        MediaRole.annotationOverlay => 'annotation_overlay',
        MediaRole.annotatedRender => 'annotated_render',
      };

  /// Server-side role for blob upload.
  String get serverRole => switch (this) {
        MediaRole.annotatedRender => 'annotated_render',
        MediaRole.annotationOverlay => 'annotation_overlay',
        MediaRole.primaryPhoto => 'primary_photo',
        MediaRole.voiceNote => 'voice_note',
        MediaRole.file => 'file',
        MediaRole.attachment => 'attachment',
      };

  static MediaRole fromDb(String v) => switch (v) {
        'primary_photo' => MediaRole.primaryPhoto,
        'voice_note' => MediaRole.voiceNote,
        'file' => MediaRole.file,
        'attachment' => MediaRole.attachment,
        'annotation_overlay' => MediaRole.annotationOverlay,
        'annotated_render' => MediaRole.annotatedRender,
        _ => MediaRole.attachment,
      };

  static MediaRole fromServer(String v) => fromDb(v);
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
  final String? originalFilename;
  final SyncState syncState;
  final String? remoteStorageKey;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.originalFilename,
    this.syncState = SyncState.localOnly,
    this.remoteStorageKey,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  bool get needsBlobUpload => syncState.needsPush;

  String get displayName {
    final original = originalFilename?.trim();
    if (original != null && original.isNotEmpty) return original;
    final parts = relativePath.split('/');
    return parts.isNotEmpty ? parts.last : relativePath;
  }

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
        'original_filename': originalFilename,
        'sync_state': syncState.dbValue,
        'remote_storage_key': remoteStorageKey,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
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
        originalFilename: r['original_filename'] as String?,
        syncState: SyncState.fromDb(r['sync_state'] as String?),
        remoteStorageKey: r['remote_storage_key'] as String?,
        createdAt: DateTime.parse(r['created_at']! as String),
        updatedAt: DateTime.parse((r['updated_at'] ?? r['created_at'])! as String),
      );
}
