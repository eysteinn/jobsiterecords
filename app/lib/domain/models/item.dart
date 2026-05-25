import 'package:flutter/foundation.dart';

import '../../sync/sync_state.dart';

enum ItemKind {
  photo,
  voice,
  note,
  file;

  String get dbValue => name;

  static ItemKind fromDb(String v) => ItemKind.values.firstWhere(
        (k) => k.name == v,
        orElse: () => ItemKind.note,
      );

  String get label => switch (this) {
        ItemKind.photo => 'Photo',
        ItemKind.voice => 'Voice Note',
        ItemKind.note => 'Note',
        ItemKind.file => 'File',
      };
}

@immutable
class Item {
  final String id;
  final String jobId;
  final ItemKind kind;
  final String? caption;
  final String? body;
  final SyncState syncState;
  final DateTime? lastSyncedAt;
  final DateTime capturedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Item({
    required this.id,
    required this.jobId,
    required this.kind,
    this.caption,
    this.body,
    this.syncState = SyncState.localOnly,
    this.lastSyncedAt,
    required this.capturedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Item copyWith({
    String? caption,
    String? body,
    SyncState? syncState,
    DateTime? lastSyncedAt,
    DateTime? capturedAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id,
      jobId: jobId,
      kind: kind,
      caption: caption ?? this.caption,
      body: body ?? this.body,
      syncState: syncState ?? this.syncState,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'job_id': jobId,
        'kind': kind.dbValue,
        'caption': caption,
        'body': body,
        'sync_state': syncState.dbValue,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'captured_at': capturedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Item.fromDb(Map<String, Object?> r) => Item(
        id: r['id']! as String,
        jobId: r['job_id']! as String,
        kind: ItemKind.fromDb(r['kind']! as String),
        caption: r['caption'] as String?,
        body: r['body'] as String?,
        syncState: SyncState.fromDb(r['sync_state'] as String?),
        lastSyncedAt: r['last_synced_at'] == null ? null : DateTime.tryParse(r['last_synced_at']! as String),
        capturedAt: DateTime.parse(r['captured_at']! as String),
        createdAt: DateTime.parse(r['created_at']! as String),
        updatedAt: DateTime.parse(r['updated_at']! as String),
      );
}
