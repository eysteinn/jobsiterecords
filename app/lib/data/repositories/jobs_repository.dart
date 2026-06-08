import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../domain/models/job.dart';
import '../../domain/models/timeline_item.dart';
import '../../sync/sync_state.dart';
import '../db/database.dart';
import '../storage/media_storage.dart';

class JobsRepository {
  JobsRepository(this._db, this._storage);
  final AppDatabase _db;
  final MediaStorage _storage;

  Future<List<Job>> all({String? query, bool localOnly = true, String? workspaceId}) async {
    final where = <String>[];
    final args = <Object?>[];
    where.add('deleted_at IS NULL');
    if (localOnly) {
      where.add('workspace_id IS NULL');
    } else if (workspaceId != null) {
      where.add('workspace_id = ?');
      args.add(workspaceId);
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('(name LIKE ? OR client_name LIKE ? OR address LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }
    final rows = await _db.db.query(
      'jobs',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Job.fromDb).toList();
  }

  Future<Job?> byId(String id) async {
    final rows = await _db.db.query(
      'jobs',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Job.fromDb(rows.first);
  }

  Future<Job> create({
    required String name,
    String? clientName,
    String? address,
    String? jobNumber,
    JobStatus status = JobStatus.inProgress,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? workspaceId,
  }) async {
    final ts = now();
    final syncState = workspaceId == null ? SyncState.localOnly : SyncState.pending;
    final job = Job(
      id: newId(),
      name: name.trim(),
      clientName: _trimOrNull(clientName),
      address: _trimOrNull(address),
      jobNumber: _trimOrNull(jobNumber),
      status: status,
      startDate: startDate,
      endDate: endDate,
      notes: _trimOrNull(notes),
      workspaceId: workspaceId,
      syncState: syncState,
      createdAt: ts,
      updatedAt: ts,
    );
    await _db.db.insert('jobs', job.toDb());
    return job;
  }

  Future<Job> update(Job j) async {
    final syncState = j.workspaceId == null
        ? SyncState.localOnly
        : (j.syncState == SyncState.synced ? SyncState.pending : j.syncState);
    final updated = j.copyWith(updatedAt: now(), syncState: syncState);
    await _db.db.update('jobs', updated.toDb(), where: 'id = ?', whereArgs: [j.id]);
    return updated;
  }

  Future<void> delete(String id) async {
    final rows = await _db.db.query('jobs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final job = Job.fromDb(rows.first);
    if (job.workspaceId == null) {
      await _hardDeleteJob(id);
      return;
    }
    final ts = now();
    await _db.db.update(
      'jobs',
      {
        'deleted_at': ts.toIso8601String(),
        'updated_at': ts.toIso8601String(),
        'sync_state': SyncState.pending.dbValue,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> purgeAfterSync(String jobId) async {
    await _hardDeleteJob(jobId);
  }

  Future<void> _hardDeleteJob(String id) async {
    await _db.db.transaction((txn) async {
      await txn.delete('jobs', where: 'id = ?', whereArgs: [id]);
    });
    await _storage.deleteForJob(id);
  }

  /// Compute counts + cover photo for every job in one pass. Cheap enough for
  /// realistic dataset sizes; we can index later if needed.
  Future<Map<String, JobSummary>> summaries({bool localOnly = true, String? workspaceId}) async {
    final where = <String>[];
    final args = <Object?>[];
    where.add('j.deleted_at IS NULL');
    if (localOnly) {
      where.add('j.workspace_id IS NULL');
    } else if (workspaceId != null) {
      where.add('j.workspace_id = ?');
      args.add(workspaceId);
    }
    final filter = 'WHERE ${where.join(' AND ')}';
    final rows = await _db.db.rawQuery('''
      SELECT
        j.id AS job_id,
        COUNT(i.id) AS items,
        SUM(CASE WHEN i.kind = 'photo' THEN 1 ELSE 0 END) AS photos,
        SUM(CASE WHEN i.kind = 'voice' THEN 1 ELSE 0 END) AS voice_notes,
        SUM(CASE WHEN i.kind = 'note'  THEN 1 ELSE 0 END) AS notes,
        SUM(CASE WHEN i.kind = 'file'  THEN 1 ELSE 0 END) AS files,
        MAX(i.updated_at) AS last_item_update
      FROM jobs j
      LEFT JOIN items i ON i.job_id = j.id AND i.deleted_at IS NULL
      $filter
      GROUP BY j.id
    ''', args);

    final issuesRows = await _db.db.rawQuery('''
      SELECT i.job_id AS job_id, COUNT(DISTINCT i.id) AS issues
      FROM items i
      JOIN item_tags it ON it.item_id = i.id
      JOIN tags t ON t.id = it.tag_id
      WHERE t.name = 'Issue' COLLATE NOCASE
      GROUP BY i.job_id
    ''');
    final issuesByJob = {
      for (final r in issuesRows) r['job_id'] as String: (r['issues'] as int?) ?? 0,
    };

    final coverRows = await _db.db.rawQuery('''
      SELECT i.job_id AS job_id, m.relative_path AS rel
      FROM items i
      JOIN media_files m ON m.item_id = i.id AND m.role = 'primary_photo'
      WHERE i.id IN (
        SELECT id FROM items i2 WHERE i2.job_id = i.job_id AND i2.kind = 'photo'
        ORDER BY i2.captured_at DESC LIMIT 1
      )
    ''');
    final coverByJob = {
      for (final r in coverRows) r['job_id'] as String: r['rel'] as String,
    };

    final out = <String, JobSummary>{};
    for (final r in rows) {
      final jobId = r['job_id']! as String;
      out[jobId] = JobSummary(
        jobId: jobId,
        items: (r['items'] as int?) ?? 0,
        photos: (r['photos'] as int?) ?? 0,
        voiceNotes: (r['voice_notes'] as int?) ?? 0,
        notes: (r['notes'] as int?) ?? 0,
        files: (r['files'] as int?) ?? 0,
        issues: issuesByJob[jobId] ?? 0,
        lastUpdated: r['last_item_update'] == null
            ? null
            : DateTime.tryParse(r['last_item_update']! as String),
        coverPhotoRelativePath: coverByJob[jobId],
      );
    }
    return out;
  }

  Future<int> countJobs() async {
    final r = await _db.db.rawQuery('SELECT COUNT(*) AS c FROM jobs');
    return (r.first['c'] as int?) ?? 0;
  }
}

String? _trimOrNull(String? v) {
  if (v == null) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
