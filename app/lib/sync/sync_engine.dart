import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../data/db/database.dart';
import '../domain/models/item.dart';
import '../domain/models/job.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'sync_state.dart';

class SyncResult {
  const SyncResult({
    this.pushedJobs = 0,
    this.pushedItems = 0,
    this.pulledJobs = 0,
    this.error,
    this.pushError,
  });

  final int pushedJobs;
  final int pushedItems;
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
  })  : _db = db,
        _api = api,
        _auth = auth;

  final AppDatabase _db;
  final ApiClient _api;
  final AuthService _auth;

  Future<SyncResult> sync({
    required AuthSession session,
    required String workspaceId,
  }) async {
    var access = session.accessToken;
    var refresh = session.refreshToken;
    try {
      final pushed = await _pushPending(access, workspaceId);
      final pulled = await _pullRemote(
        accessToken: access,
        refreshToken: refresh,
        workspaceId: workspaceId,
        onTokenRefreshed: (a, r) {
          access = a;
          refresh = r;
        },
      );
      return SyncResult(
        pushedJobs: pushed.$1,
        pushedItems: pushed.$2,
        pulledJobs: pulled,
        pushError: pushed.$3,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        try {
          final renewed = await _auth.refreshSession(refresh);
          access = renewed.accessToken;
          refresh = renewed.refreshToken;
          final pushed = await _pushPending(access, workspaceId);
          final pulled = await _pullRemote(
            accessToken: access,
            refreshToken: refresh,
            workspaceId: workspaceId,
            onTokenRefreshed: (_, __) {},
          );
          return SyncResult(
            pushedJobs: pushed.$1,
            pushedItems: pushed.$2,
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

  Future<(int, int, String?)> _pushPending(String accessToken, String workspaceId) async {
    var jobsPushed = 0;
    var itemsPushed = 0;
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
        AND i.kind = 'note'
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

    return (jobsPushed, itemsPushed, lastError);
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
      final since = await _lastSyncedAt(jobId);
      final path = since == null
          ? '/api/v1/jobs/$jobId'
          : '/api/v1/jobs/$jobId?since=${Uri.encodeQueryComponent(since.toUtc().toIso8601String())}';
      final bundleRes = await _api.get(path, accessToken: access);
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
          await _db.db.delete('items', where: 'id = ?', whereArgs: [itemJson['id']]);
          continue;
        }
        if (itemJson['kind'] != 'note') continue;
        await _mergeItemFromServer(itemJson);
      }
      await _setLastSyncedAt(jobId, DateTime.now().toUtc());
      pulled++;
    }

    return pulled;
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
        'id': item.id,
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
    await _db.db.transaction((txn) async {
      await txn.delete('items', where: 'job_id = ?', whereArgs: [jobId]);
      await txn.delete('jobs', where: 'id = ?', whereArgs: [jobId]);
    });
  }

  Future<DateTime?> _lastSyncedAt(String jobId) async {
    final rows = await _db.db.query('jobs', columns: ['last_synced_at'], where: 'id = ?', whereArgs: [jobId], limit: 1);
    if (rows.isEmpty) return null;
    final raw = rows.first['last_synced_at'] as String?;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _setLastSyncedAt(String jobId, DateTime at) async {
    await _db.db.update(
      'jobs',
      {'last_synced_at': at.toIso8601String()},
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<int> countPending(String workspaceId) async {
    final jobs = Sqflite.firstIntValue(await _db.db.rawQuery('''
      SELECT COUNT(*) FROM jobs
      WHERE workspace_id = ? AND sync_state IN ('pending', 'failed')
    ''', [workspaceId])) ?? 0;
    final items = Sqflite.firstIntValue(await _db.db.rawQuery('''
      SELECT COUNT(*) FROM items i
      JOIN jobs j ON j.id = i.job_id
      WHERE j.workspace_id = ? AND i.kind = 'note'
        AND i.sync_state IN ('pending', 'failed')
    ''', [workspaceId])) ?? 0;
    return jobs + items;
  }
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.tryParse(v as String);
}
