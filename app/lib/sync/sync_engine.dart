import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../data/db/database.dart';
import '../data/storage/media_storage.dart';
import '../domain/models/item.dart';
import '../domain/models/job.dart';
import '../domain/models/media_file.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'network_gate.dart';
import 'sync_state.dart';

class SyncResult {
  const SyncResult({
    this.pushedJobs = 0,
    this.pushedItems = 0,
    this.pushedMedia = 0,
    this.pulledJobs = 0,
    this.error,
    this.pushError,
  });

  final int pushedJobs;
  final int pushedItems;
  final int pushedMedia;
  final int pulledJobs;
  final String? error;
  final String? pushError;

  bool get ok => error == null && pushError == null;
}

class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required ApiClient api,
    required AuthService auth,
    required MediaStorage storage,
  })  : _db = db,
        _api = api,
        _auth = auth,
        _storage = storage;

  final AppDatabase _db;
  final ApiClient _api;
  final AuthService _auth;
  final MediaStorage _storage;

  Future<SyncResult> sync({
    required AuthSession session,
    required String workspaceId,
    bool wifiOnly = false,
  }) async {
    var access = session.accessToken;
    var refresh = session.refreshToken;
    try {
      final pulled = await _pullRemote(
        accessToken: access,
        refreshToken: refresh,
        workspaceId: workspaceId,
        onTokenRefreshed: (a, r) {
          access = a;
          refresh = r;
        },
      );
      final pushed = await _pushPending(access, workspaceId, wifiOnly: wifiOnly);
      return SyncResult(
        pushedJobs: pushed.$1,
        pushedItems: pushed.$2,
        pushedMedia: pushed.$4,
        pulledJobs: pulled,
        pushError: pushed.$3,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        try {
          final renewed = await _auth.refreshSession(refresh);
          access = renewed.accessToken;
          refresh = renewed.refreshToken;
          final pulled = await _pullRemote(
            accessToken: access,
            refreshToken: refresh,
            workspaceId: workspaceId,
            onTokenRefreshed: (_, __) {},
          );
          final pushed = await _pushPending(access, workspaceId, wifiOnly: wifiOnly);
          return SyncResult(
            pushedJobs: pushed.$1,
            pushedItems: pushed.$2,
            pushedMedia: pushed.$4,
            pulledJobs: pulled,
            pushError: pushed.$3,
          );
        } catch (inner) {
          return SyncResult(error: inner.toString());
        }
      }
      return SyncResult(error: e.message);
    } catch (e) {
      return SyncResult(error: e.toString());
    }
  }

  Future<(int, int, String?, int)> _pushPending(
    String accessToken,
    String workspaceId, {
    required bool wifiOnly,
  }) async {
    var jobsPushed = 0;
    var itemsPushed = 0;
    var mediaPushed = 0;
    String? lastError;

    final jobRows = await _db.db.query(
      'jobs',
      where: "workspace_id = ? AND sync_state IN ('pending', 'failed')",
      whereArgs: [workspaceId],
    );

    for (final row in jobRows) {
      final job = Job.fromDb(row);
      try {
        final body = _jobPayload(job);
        final res = await _api.put('/api/v1/jobs/${job.id}', body: body, accessToken: accessToken);
        final data = decodeJsonMap(res);
        await _applyJobFromServer(data, markSynced: true);
        jobsPushed++;
      } catch (e) {
        lastError ??= e.toString();
        await _db.db.update(
          'jobs',
          {'sync_state': SyncState.failed.dbValue},
          where: 'id = ?',
          whereArgs: [job.id],
        );
      }
    }

    final itemRows = await _db.db.rawQuery('''
      SELECT i.* FROM items i
      JOIN jobs j ON j.id = i.job_id
      WHERE j.workspace_id = ?
        AND i.sync_state IN ('pending', 'failed')
    ''', [workspaceId]);

    for (final row in itemRows) {
      final item = Item.fromDb(row);
      try {
        final body = _itemPayload(item);
        final res = await _api.put(
          '/api/v1/jobs/${item.jobId}/items/${item.id}',
          body: body,
          accessToken: accessToken,
        );
        final data = decodeJsonMap(res);
        await _applyItemFromServer(data, markSynced: true);
        itemsPushed++;
      } catch (e) {
        lastError ??= e.toString();
        await _db.db.update(
          'items',
          {'sync_state': SyncState.failed.dbValue},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }
    }

    if (await canUploadBlobs(wifiOnly: wifiOnly)) {
      final pendingMedia = await _db.db.rawQuery('''
        SELECT m.* FROM media_files m
        JOIN items i ON i.id = m.item_id
        JOIN jobs j ON j.id = i.job_id
        WHERE j.workspace_id = ?
          AND m.sync_state IN ('pending', 'failed')
          AND m.role IN ('primary_photo', 'annotated_render', 'voice_note', 'file')
      ''', [workspaceId]);

      for (final row in pendingMedia) {
        final media = MediaFile.fromDb(row);
        if (!_shouldUploadMedia(media.itemId, media)) continue;
        try {
          await _uploadMediaFile(media, accessToken);
          mediaPushed++;
        } catch (e) {
          lastError ??= e.toString();
          await _db.db.update(
            'media_files',
            {'sync_state': SyncState.failed.dbValue},
            where: 'id = ?',
            whereArgs: [media.id],
          );
        }
      }
    }

    return (jobsPushed, itemsPushed, lastError, mediaPushed);
  }

  bool _shouldUploadMedia(String itemId, MediaFile media) {
    if (media.role == MediaRole.annotatedRender) return true;
    if (media.role != MediaRole.primaryPhoto) {
      return media.needsBlobUpload;
    }
    // Prefer annotated render over raw photo when present.
    return true;
  }

  Future<void> _uploadMediaFile(MediaFile media, String accessToken) async {
    final itemRows = await _db.db.query('items', where: 'id = ?', whereArgs: [media.itemId], limit: 1);
    if (itemRows.isEmpty) return;
    final item = Item.fromDb(itemRows.first);
    if (item.syncState == SyncState.pending || item.syncState == SyncState.failed) {
      final body = _itemPayload(item);
      final res = await _api.put(
        '/api/v1/jobs/${item.jobId}/items/${item.id}',
        body: body,
        accessToken: accessToken,
      );
      await _applyItemFromServer(decodeJsonMap(res), markSynced: true);
    }

    if (media.role == MediaRole.primaryPhoto) {
      final annotated = await _db.db.query(
        'media_files',
        where: 'item_id = ? AND role = ?',
        whereArgs: [media.itemId, MediaRole.annotatedRender.dbValue],
        limit: 1,
      );
      if (annotated.isNotEmpty) {
        final state = annotated.first['sync_state'] as String?;
        if (state == SyncState.synced.dbValue || state == SyncState.pending.dbValue) {
          await _db.db.update(
            'media_files',
            {'sync_state': SyncState.synced.dbValue},
            where: 'id = ?',
            whereArgs: [media.id],
          );
          return;
        }
      }
    }

    final absPath = _storage.absolutePath(media.relativePath);
    final bytes = await File(absPath).readAsBytes();
    final mintRes = await _api.post(
      '/api/v1/items/${media.itemId}/media-files',
      body: {
        'id': media.id,
        'role': media.role.serverRole,
        'mime_type': media.mimeType,
        'size_bytes': bytes.length,
        'original_filename': media.originalFilename,
        'width': media.width,
        'height': media.height,
        'duration_ms': media.durationMs,
      },
      accessToken: accessToken,
    );
    final mint = decodeJsonMap(mintRes);
    final uploadUrl = mint['upload_url'] as String;
    final uploadRes = await _api.putBytes(
      Uri.parse(uploadUrl),
      body: bytes,
      contentType: media.mimeType,
    );
    if (uploadRes.statusCode >= 400) {
      throw ApiException('Blob upload failed', statusCode: uploadRes.statusCode);
    }
    final etag = uploadRes.headers['etag'];
    final completeRes = await _api.post(
      '/api/v1/media-files/${media.id}/complete',
      body: {
        'etag': etag ?? '',
        'size_bytes': bytes.length,
      },
      accessToken: accessToken,
    );
    final complete = decodeJsonMap(completeRes);
    final remote = Map<String, dynamic>.from(complete['media_file'] as Map);
    await _db.db.update(
      'media_files',
      {
        'sync_state': SyncState.synced.dbValue,
        'remote_storage_key': remote['storage_key'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [media.id],
    );
  }

  Future<int> _pullRemote({
    required String accessToken,
    required String refreshToken,
    required String workspaceId,
    required void Function(String access, String refresh) onTokenRefreshed,
  }) async {
    var access = accessToken;
    var pulled = 0;

    http.Response assignmentsRes;
    try {
      assignmentsRes = await _api.get(
        '/api/v1/workspaces/$workspaceId/assignments',
        accessToken: access,
      );
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      final renewed = await _auth.refreshSession(refreshToken);
      access = renewed.accessToken;
      onTokenRefreshed(access, renewed.refreshToken);
      assignmentsRes = await _api.get(
        '/api/v1/workspaces/$workspaceId/assignments',
        accessToken: access,
      );
    }

    final assignments = decodeJsonMap(assignmentsRes);
    final ids = (assignments['job_ids'] as List? ?? []).cast<String>();

    for (final jobId in ids) {
      // Full pull every sync — incremental `since` used wall-clock last_synced_at and
      // skipped older web items that were never downloaded to the phone.
      final bundleRes = await _api.get('/api/v1/jobs/$jobId', accessToken: access);
      final bundle = decodeJsonMap(bundleRes);
      final jobJson = Map<String, dynamic>.from(bundle['job'] as Map);
      if (jobJson['deleted_at'] != null) {
        await _deleteLocalJob(jobId);
        continue;
      }
      await _mergeJobFromServer(jobJson);
      final items = (bundle['items'] as List? ?? []);
      for (final raw in items) {
        final itemJson = Map<String, dynamic>.from(raw as Map);
        if (itemJson['deleted_at'] != null) {
          await _deleteLocalItem(itemJson['id'] as String, jobId);
          continue;
        }
        await _mergeItemFromServer(itemJson);
      }
      final mediaFiles = (bundle['media_files'] as List? ?? []);
      for (final raw in mediaFiles) {
        final mediaJson = Map<String, dynamic>.from(raw as Map);
        await _mergeMediaFromServer(mediaJson, jobId, access);
      }
      final cursor = _syncCursorFromBundle(jobJson, items, mediaFiles);
      if (cursor != null) {
        await _setLastSyncedAt(jobId, cursor);
      }
      pulled++;
    }

    return pulled;
  }

  Future<void> _mergeMediaFromServer(
    Map<String, dynamic> json,
    String jobId,
    String accessToken,
  ) async {
    final id = json['id'] as String;
    if (json['deleted_at'] != null) {
      await _db.db.delete('media_files', where: 'id = ?', whereArgs: [id]);
      return;
    }
    final status = json['status'] as String? ?? 'pending';
    final itemId = json['item_id'] as String;
    final role = MediaRole.fromServer(json['role'] as String);
    final remoteUpdated = DateTime.parse(json['updated_at'] as String).toLocal();

    final existing = await _db.db.query('media_files', where: 'id = ?', whereArgs: [id], limit: 1);
    if (existing.isNotEmpty) {
      final local = MediaFile.fromDb(existing.first);
      if (local.syncState.needsPush && local.updatedAt.isAfter(remoteUpdated)) {
        return;
      }
    }

    final relativePath = existing.isNotEmpty
        ? existing.first['relative_path']! as String
        : _defaultRelativePath(jobId, itemId, role, json['original_filename'] as String?);

    if (status == 'uploaded') {
      final absPath = _storage.absolutePath(relativePath);
      final file = File(absPath);
      if (!await file.exists()) {
        await _storage.dirForItem(jobId, itemId);
        final bytes = await _api.downloadMedia(id, accessToken: accessToken);
        await file.writeAsBytes(bytes, flush: true);
      }
    }

    final row = {
      'id': id,
      'item_id': itemId,
      'role': _localRole(role).dbValue,
      'relative_path': relativePath,
      'mime_type': json['mime_type'],
      'width': json['width'],
      'height': json['height'],
      'duration_ms': json['duration_ms'],
      'size_bytes': json['size_bytes'],
      'original_filename': json['original_filename'],
      'sync_state': SyncState.synced.dbValue,
      'remote_storage_key': json['storage_key'],
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
    };
    await _db.db.insert('media_files', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  MediaRole _localRole(MediaRole serverRole) {
    return switch (serverRole) {
      MediaRole.primaryPhoto => MediaRole.primaryPhoto,
      MediaRole.voiceNote => MediaRole.voiceNote,
      MediaRole.file => MediaRole.file,
      _ => MediaRole.attachment,
    };
  }

  String _defaultRelativePath(String jobId, String itemId, MediaRole role, String? originalFilename) {
    return switch (role) {
      MediaRole.primaryPhoto => _storage.relativeFor(jobId, itemId, 'photo.jpg'),
      MediaRole.voiceNote => _storage.relativeFor(jobId, itemId, 'voice.m4a'),
      MediaRole.file => _storage.relativeFor(jobId, itemId, originalFilename ?? 'file.bin'),
      _ => _storage.relativeFor(jobId, itemId, originalFilename ?? 'attachment.bin'),
    };
  }

  Map<String, dynamic> _jobPayload(Job job) => {
        'id': job.id,
        'workspace_id': job.workspaceId,
        'name': job.name,
        'client_name': job.clientName,
        'address': job.address,
        'job_number': job.jobNumber,
        'status': job.status.dbValue,
        'start_date': job.startDate?.toIso8601String().split('T').first,
        'end_date': job.endDate?.toIso8601String().split('T').first,
        'notes': job.notes,
        'cover_item_id': job.coverItemId,
        'created_at': job.createdAt.toUtc().toIso8601String(),
        'updated_at': job.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _itemPayload(Item item) => {
        'job_id': item.jobId,
        'kind': item.kind.dbValue,
        'caption': item.caption,
        'body': item.body,
        'captured_at': item.capturedAt.toUtc().toIso8601String(),
        'created_at': item.createdAt.toUtc().toIso8601String(),
        'updated_at': item.updatedAt.toUtc().toIso8601String(),
      };

  Future<void> _mergeJobFromServer(Map<String, dynamic> json) async {
    final remote = _jobFromApi(json);
    final existing = await _db.db.query('jobs', where: 'id = ?', whereArgs: [remote.id], limit: 1);
    if (existing.isEmpty) {
      await _applyJobFromServer(json, markSynced: true);
      return;
    }
    final local = Job.fromDb(existing.first);
    if (local.syncState.needsPush && local.updatedAt.isAfter(remote.updatedAt)) {
      return;
    }
    await _applyJobFromServer(json, markSynced: true);
  }

  Future<void> _mergeItemFromServer(Map<String, dynamic> json) async {
    final remote = _itemFromApi(json);
    final existing = await _db.db.query('items', where: 'id = ?', whereArgs: [remote.id], limit: 1);
    if (existing.isEmpty) {
      await _applyItemFromServer(json, markSynced: true);
      return;
    }
    final local = Item.fromDb(existing.first);
    if (local.syncState.needsPush && local.updatedAt.isAfter(remote.updatedAt)) {
      return;
    }
    await _applyItemFromServer(json, markSynced: true);
  }

  Future<void> _applyJobFromServer(Map<String, dynamic> json, {required bool markSynced}) async {
    final job = _jobFromApi(json);
    final row = job.toDb()
      ..['sync_state'] = markSynced ? SyncState.synced.dbValue : SyncState.pending.dbValue
      ..['last_synced_at'] = DateTime.now().toUtc().toIso8601String();
    await _db.db.insert('jobs', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _applyItemFromServer(Map<String, dynamic> json, {required bool markSynced}) async {
    final item = _itemFromApi(json);
    final row = item.toDb()
      ..['sync_state'] = markSynced ? SyncState.synced.dbValue : SyncState.pending.dbValue
      ..['last_synced_at'] = DateTime.now().toUtc().toIso8601String();
    await _db.db.insert('items', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Job _jobFromApi(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String?,
      name: json['name'] as String,
      clientName: json['client_name'] as String?,
      address: json['address'] as String?,
      jobNumber: json['job_number'] as String?,
      status: JobStatus.fromDb(json['status'] as String? ?? 'in_progress'),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      notes: json['notes'] as String?,
      coverItemId: json['cover_item_id'] as String?,
      syncState: SyncState.synced,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Item _itemFromApi(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      kind: ItemKind.fromDb(json['kind'] as String),
      caption: json['caption'] as String?,
      body: json['body'] as String?,
      syncState: SyncState.synced,
      capturedAt: DateTime.parse(json['captured_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Future<void> _deleteLocalJob(String jobId) async {
    await _storage.deleteForJob(jobId);
    await _db.db.transaction((txn) async {
      await txn.delete('items', where: 'job_id = ?', whereArgs: [jobId]);
      await txn.delete('jobs', where: 'id = ?', whereArgs: [jobId]);
    });
  }

  Future<void> _deleteLocalItem(String itemId, String jobId) async {
    await _storage.deleteForItem(jobId, itemId);
    await _db.db.delete('items', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> _setLastSyncedAt(String jobId, DateTime at) async {
    await _db.db.update(
      'jobs',
      {'last_synced_at': at.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  DateTime? _syncCursorFromBundle(
    Map<String, dynamic> jobJson,
    List<dynamic> items,
    List<dynamic> mediaFiles,
  ) {
    DateTime? max;
    void consider(Object? raw) {
      if (raw == null) return;
      final t = DateTime.tryParse(raw.toString());
      if (t == null) return;
      final utc = t.toUtc();
      if (max == null || utc.isAfter(max!)) max = utc;
    }

    consider(jobJson['updated_at']);
    for (final raw in items) {
      final map = Map<String, dynamic>.from(raw as Map);
      consider(map['updated_at']);
    }
    for (final raw in mediaFiles) {
      final map = Map<String, dynamic>.from(raw as Map);
      consider(map['updated_at']);
    }
    return max;
  }

  Future<int> countPending(String workspaceId) async {
    final jobs = Sqflite.firstIntValue(await _db.db.rawQuery('''
      SELECT COUNT(*) FROM jobs
      WHERE workspace_id = ? AND sync_state IN ('pending', 'failed')
    ''', [workspaceId])) ?? 0;
    final items = Sqflite.firstIntValue(await _db.db.rawQuery('''
      SELECT COUNT(*) FROM items i
      JOIN jobs j ON j.id = i.job_id
      WHERE j.workspace_id = ?
        AND i.sync_state IN ('pending', 'failed')
    ''', [workspaceId])) ?? 0;
    final media = Sqflite.firstIntValue(await _db.db.rawQuery('''
      SELECT COUNT(*) FROM media_files m
      JOIN items i ON i.id = m.item_id
      JOIN jobs j ON j.id = i.job_id
      WHERE j.workspace_id = ?
        AND m.sync_state IN ('pending', 'failed')
        AND m.role IN ('primary_photo', 'annotated_render', 'voice_note', 'file')
    ''', [workspaceId])) ?? 0;
    return jobs + items + media;
  }
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.tryParse(v as String);
}
