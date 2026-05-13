import 'dart:io';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../domain/models/item.dart';
import '../../domain/models/media_file.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/timeline_item.dart';
import '../db/database.dart';
import '../storage/media_storage.dart';

class ItemsRepository {
  ItemsRepository(this._db, this._storage);
  final AppDatabase _db;
  final MediaStorage _storage;

  Future<TimelineItem?> byId(String id) async {
    final rows = await _db.db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final item = Item.fromDb(rows.first);
    final media = await _mediaForItems([id]);
    final tags = await _tagsForItems([id]);
    return _join(item, media[id] ?? const [], tags[id] ?? const []);
  }

  Future<List<TimelineItem>> forJob(String jobId, {String? tagFilter}) async {
    final rows = tagFilter == null
        ? await _db.db.query(
            'items',
            where: 'job_id = ?',
            whereArgs: [jobId],
            orderBy: 'captured_at DESC',
          )
        : await _db.db.rawQuery('''
            SELECT i.* FROM items i
            JOIN item_tags it ON it.item_id = i.id
            JOIN tags t ON t.id = it.tag_id
            WHERE i.job_id = ? AND t.name = ? COLLATE NOCASE
            ORDER BY i.captured_at DESC
          ''', [jobId, tagFilter]);

    final items = rows.map(Item.fromDb).toList();
    if (items.isEmpty) return const [];
    final ids = items.map((e) => e.id).toList();
    final media = await _mediaForItems(ids);
    final tags = await _tagsForItems(ids);
    return [for (final i in items) _join(i, media[i.id] ?? const [], tags[i.id] ?? const [])];
  }

  TimelineItem _join(Item item, List<MediaFile> media, List<Tag> tags) {
    MediaFile? photo;
    MediaFile? voice;
    for (final m in media) {
      if (m.role == MediaRole.primaryPhoto) photo = m;
      if (m.role == MediaRole.voiceNote) voice = m;
    }
    return TimelineItem(item: item, primaryPhoto: photo, voiceNote: voice, tags: tags);
  }

  Future<Map<String, List<MediaFile>>> _mediaForItems(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.db.rawQuery(
      'SELECT * FROM media_files WHERE item_id IN ($placeholders)',
      ids,
    );
    final out = <String, List<MediaFile>>{};
    for (final r in rows) {
      final m = MediaFile.fromDb(r);
      (out[m.itemId] ??= []).add(m);
    }
    return out;
  }

  Future<Map<String, List<Tag>>> _tagsForItems(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.db.rawQuery('''
      SELECT it.item_id AS item_id, t.*
      FROM item_tags it
      JOIN tags t ON t.id = it.tag_id
      WHERE it.item_id IN ($placeholders)
      ORDER BY t.sort_order ASC, t.name ASC
    ''', ids);
    final out = <String, List<Tag>>{};
    for (final r in rows) {
      final itemId = r['item_id']! as String;
      (out[itemId] ??= []).add(Tag.fromDb(r));
    }
    return out;
  }

  Future<Item> createPhoto({
    required String jobId,
    required String sourceFilePath,
    String? caption,
    List<String> tagIds = const [],
    String? voiceNoteSourcePath,
    int? voiceDurationMs,
  }) async {
    final itemId = newId();
    final ts = now();
    final dir = await _storage.dirForItem(jobId, itemId);

    final photoFile = File(sourceFilePath);
    final photoSize = await photoFile.length();
    final photoName = 'photo.jpg';
    final photoDest = File('${dir.path}/$photoName');
    await photoFile.rename(photoDest.path).catchError((_) async {
      return photoFile.copy(photoDest.path);
    });

    File? voiceDest;
    int? voiceSize;
    if (voiceNoteSourcePath != null) {
      final voiceFile = File(voiceNoteSourcePath);
      voiceSize = await voiceFile.length();
      final destFile = File('${dir.path}/voice.m4a');
      voiceDest = destFile;
      await voiceFile.rename(destFile.path).catchError((_) async {
        return voiceFile.copy(destFile.path);
      });
    }

    final item = Item(
      id: itemId,
      jobId: jobId,
      kind: ItemKind.photo,
      caption: _trimOrNull(caption),
      capturedAt: ts,
      createdAt: ts,
      updatedAt: ts,
    );

    await _db.db.transaction((txn) async {
      await txn.insert('items', item.toDb());
      await txn.insert('media_files', MediaFile(
        id: newId(),
        itemId: itemId,
        role: MediaRole.primaryPhoto,
        relativePath: _storage.relativeFor(jobId, itemId, photoName),
        mimeType: 'image/jpeg',
        sizeBytes: photoSize,
        createdAt: ts,
      ).toDb());
      if (voiceDest != null) {
        await txn.insert('media_files', MediaFile(
          id: newId(),
          itemId: itemId,
          role: MediaRole.voiceNote,
          relativePath: _storage.relativeFor(jobId, itemId, 'voice.m4a'),
          mimeType: 'audio/mp4',
          durationMs: voiceDurationMs,
          sizeBytes: voiceSize ?? 0,
          createdAt: ts,
        ).toDb());
      }
      for (final tagId in tagIds) {
        await txn.insert('item_tags', {'item_id': itemId, 'tag_id': tagId});
      }
      await txn.update(
        'jobs',
        {'updated_at': ts.toIso8601String()},
        where: 'id = ?',
        whereArgs: [jobId],
      );
    });

    return item;
  }

  Future<Item> createVoice({
    required String jobId,
    required String sourceFilePath,
    String? caption,
    List<String> tagIds = const [],
    int? durationMs,
  }) async {
    final itemId = newId();
    final ts = now();
    final dir = await _storage.dirForItem(jobId, itemId);

    final voiceFile = File(sourceFilePath);
    final voiceSize = await voiceFile.length();
    final voiceDest = File('${dir.path}/voice.m4a');
    await voiceFile.rename(voiceDest.path).catchError((_) async {
      return voiceFile.copy(voiceDest.path);
    });

    final item = Item(
      id: itemId,
      jobId: jobId,
      kind: ItemKind.voice,
      caption: _trimOrNull(caption),
      capturedAt: ts,
      createdAt: ts,
      updatedAt: ts,
    );

    await _db.db.transaction((txn) async {
      await txn.insert('items', item.toDb());
      await txn.insert('media_files', MediaFile(
        id: newId(),
        itemId: itemId,
        role: MediaRole.voiceNote,
        relativePath: _storage.relativeFor(jobId, itemId, 'voice.m4a'),
        mimeType: 'audio/mp4',
        durationMs: durationMs,
        sizeBytes: voiceSize,
        createdAt: ts,
      ).toDb());
      for (final tagId in tagIds) {
        await txn.insert('item_tags', {'item_id': itemId, 'tag_id': tagId});
      }
      await txn.update(
        'jobs',
        {'updated_at': ts.toIso8601String()},
        where: 'id = ?',
        whereArgs: [jobId],
      );
    });

    return item;
  }

  Future<Item> createNote({
    required String jobId,
    required String body,
    String? caption,
    List<String> tagIds = const [],
  }) async {
    final itemId = newId();
    final ts = now();
    final item = Item(
      id: itemId,
      jobId: jobId,
      kind: ItemKind.note,
      caption: _trimOrNull(caption),
      body: body.trim(),
      capturedAt: ts,
      createdAt: ts,
      updatedAt: ts,
    );

    await _db.db.transaction((txn) async {
      await txn.insert('items', item.toDb());
      for (final tagId in tagIds) {
        await txn.insert('item_tags', {'item_id': itemId, 'tag_id': tagId});
      }
      await txn.update(
        'jobs',
        {'updated_at': ts.toIso8601String()},
        where: 'id = ?',
        whereArgs: [jobId],
      );
    });

    return item;
  }

  Future<void> updateMeta({
    required String itemId,
    String? caption,
    String? body,
    required List<String> tagIds,
  }) async {
    final ts = now();
    await _db.db.transaction((txn) async {
      final patch = <String, Object?>{'updated_at': ts.toIso8601String()};
      patch['caption'] = _trimOrNull(caption);
      if (body != null) patch['body'] = _trimOrNull(body);
      await txn.update('items', patch, where: 'id = ?', whereArgs: [itemId]);
      await txn.delete('item_tags', where: 'item_id = ?', whereArgs: [itemId]);
      for (final tagId in tagIds) {
        await txn.insert('item_tags', {'item_id': itemId, 'tag_id': tagId});
      }
      final r = await txn.query('items', columns: ['job_id'], where: 'id = ?', whereArgs: [itemId]);
      if (r.isNotEmpty) {
        await txn.update(
          'jobs',
          {'updated_at': ts.toIso8601String()},
          where: 'id = ?',
          whereArgs: [r.first['job_id']],
        );
      }
    });
  }

  Future<void> delete(String itemId) async {
    String? jobId;
    final r = await _db.db.query('items', columns: ['job_id'], where: 'id = ?', whereArgs: [itemId]);
    if (r.isNotEmpty) jobId = r.first['job_id'] as String;
    await _db.db.delete('items', where: 'id = ?', whereArgs: [itemId]);
    if (jobId != null) {
      await _storage.deleteForItem(jobId, itemId);
    }
  }
}

String? _trimOrNull(String? v) {
  if (v == null) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
