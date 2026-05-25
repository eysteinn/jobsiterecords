import 'dart:io';

import '../../core/clock.dart';
import '../../core/file_utils.dart';
import '../../core/ids.dart';
import '../../domain/models/item.dart';
import '../../domain/models/media_file.dart';
import '../../domain/models/tag.dart';
import '../../domain/models/timeline_item.dart';
import '../../domain/models/timeline_query.dart';
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

  Future<List<TimelineItem>> forJob(String jobId, {TimelineQuery query = TimelineQuery.empty}) async {
    final where = <String>['i.job_id = ?'];
    final args = <Object?>[jobId];

    if (query.kinds.isNotEmpty) {
      final placeholders = List.filled(query.kinds.length, '?').join(',');
      where.add('i.kind IN ($placeholders)');
      args.addAll(query.kinds.map((k) => k.dbValue));
    }

    if (query.tagIds.isNotEmpty) {
      final placeholders = List.filled(query.tagIds.length, '?').join(',');
      where.add('''
        EXISTS (
          SELECT 1 FROM item_tags it
          WHERE it.item_id = i.id AND it.tag_id IN ($placeholders)
        )
      ''');
      args.addAll(query.tagIds);
    }

    final search = query.trimmedSearch;
    if (search != null) {
      final pattern = '%$search%';
      where.add('''
        (
          i.caption LIKE ? COLLATE NOCASE OR
          i.body LIKE ? COLLATE NOCASE OR
          EXISTS (
            SELECT 1 FROM item_tags it2
            JOIN tags t ON t.id = it2.tag_id
            WHERE it2.item_id = i.id AND t.name LIKE ? COLLATE NOCASE
          ) OR
          EXISTS (
            SELECT 1 FROM media_files mf
            WHERE mf.item_id = i.id AND (
              mf.original_filename LIKE ? COLLATE NOCASE OR
              mf.relative_path LIKE ? COLLATE NOCASE
            )
          )
        )
      ''');
      args.addAll([pattern, pattern, pattern, pattern, pattern]);
    }

    final rows = await _db.db.rawQuery('''
      SELECT DISTINCT i.* FROM items i
      WHERE ${where.join(' AND ')}
      ORDER BY i.captured_at DESC
    ''', args);

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
    MediaFile? file;
    for (final m in media) {
      if (m.role == MediaRole.primaryPhoto) photo = m;
      if (m.role == MediaRole.voiceNote) voice = m;
      if (m.role == MediaRole.file || m.role == MediaRole.attachment) file = m;
    }
    return TimelineItem(
      item: item,
      primaryPhoto: photo,
      voiceNote: voice,
      attachedFile: file,
      tags: tags,
    );
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

  /// Saves multiple photos from one capture session with shared caption and tags.
  /// Each entry keeps its own [BatchPhotoInput.capturedAt] for timeline ordering.
  Future<List<Item>> createPhotoBatch({
    required String jobId,
    required List<BatchPhotoInput> photos,
    String? caption,
    List<String> tagIds = const [],
  }) async {
    if (photos.isEmpty) return const [];
    final trimmedCaption = _trimOrNull(caption);
    final prepared = <({Item item, int photoSize})>[];

    for (final photo in photos) {
      final itemId = newId();
      final ts = photo.capturedAt;
      final dir = await _storage.dirForItem(jobId, itemId);

      final photoFile = File(photo.sourceFilePath);
      final photoSize = await photoFile.length();
      const photoName = 'photo.jpg';
      final photoDest = File('${dir.path}/$photoName');
      await photoFile.rename(photoDest.path).catchError((_) async {
        return photoFile.copy(photoDest.path);
      });

      prepared.add((
        item: Item(
          id: itemId,
          jobId: jobId,
          kind: ItemKind.photo,
          caption: trimmedCaption,
          capturedAt: ts,
          createdAt: ts,
          updatedAt: ts,
        ),
        photoSize: photoSize,
      ));
    }

    await _db.db.transaction((txn) async {
      for (final p in prepared) {
        final item = p.item;
        await txn.insert('items', item.toDb());
        await txn.insert('media_files', MediaFile(
          id: newId(),
          itemId: item.id,
          role: MediaRole.primaryPhoto,
          relativePath: _storage.relativeFor(jobId, item.id, 'photo.jpg'),
          mimeType: 'image/jpeg',
          sizeBytes: p.photoSize,
          createdAt: item.capturedAt,
        ).toDb());
        for (final tagId in tagIds) {
          await txn.insert('item_tags', {'item_id': item.id, 'tag_id': tagId});
        }
      }
      await txn.update(
        'jobs',
        {'updated_at': now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [jobId],
      );
    });

    return [for (final p in prepared) p.item];
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

  Future<Item> createFile({
    required String jobId,
    required String sourceFilePath,
    required String originalFilename,
    required String mimeType,
    String? caption,
    List<String> tagIds = const [],
  }) async {
    final source = File(sourceFilePath);
    final fileSize = await source.length();
    if (fileSize > maxUploadBytes) {
      throw FileTooLargeException(fileSize);
    }
    if (!isAllowedUploadExtension(originalFilename)) {
      throw UnsupportedFileTypeException(originalFilename);
    }

    final itemId = newId();
    final ts = now();
    final storageName = sanitizeStorageFilename(originalFilename);
    final dir = await _storage.dirForItem(jobId, itemId);
    final dest = File('${dir.path}/$storageName');
    await source.copy(dest.path);

    final item = Item(
      id: itemId,
      jobId: jobId,
      kind: ItemKind.file,
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
        role: MediaRole.file,
        relativePath: _storage.relativeFor(jobId, itemId, storageName),
        mimeType: mimeType,
        sizeBytes: fileSize,
        originalFilename: originalFilename,
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

  /// Adds [tagId] to every [itemId] that does not already have it.
  Future<void> addTagToItems({required List<String> itemIds, required String tagId}) async {
    if (itemIds.isEmpty) return;
    final ts = now();
    await _db.db.transaction((txn) async {
      String? jobId;
      for (final itemId in itemIds) {
        final existing = await txn.query(
          'item_tags',
          where: 'item_id = ? AND tag_id = ?',
          whereArgs: [itemId, tagId],
        );
        if (existing.isEmpty) {
          await txn.insert('item_tags', {'item_id': itemId, 'tag_id': tagId});
        }
        await txn.update(
          'items',
          {'updated_at': ts.toIso8601String()},
          where: 'id = ?',
          whereArgs: [itemId],
        );
        final r = await txn.query('items', columns: ['job_id'], where: 'id = ?', whereArgs: [itemId]);
        if (r.isNotEmpty) jobId = r.first['job_id'] as String;
      }
      if (jobId != null) {
        await txn.update(
          'jobs',
          {'updated_at': ts.toIso8601String()},
          where: 'id = ?',
          whereArgs: [jobId],
        );
      }
    });
  }

  /// Removes [tagId] from every [itemId] that has it.
  Future<void> removeTagFromItems({required List<String> itemIds, required String tagId}) async {
    if (itemIds.isEmpty) return;
    final ts = now();
    await _db.db.transaction((txn) async {
      String? jobId;
      for (final itemId in itemIds) {
        await txn.delete(
          'item_tags',
          where: 'item_id = ? AND tag_id = ?',
          whereArgs: [itemId, tagId],
        );
        await txn.update(
          'items',
          {'updated_at': ts.toIso8601String()},
          where: 'id = ?',
          whereArgs: [itemId],
        );
        final r = await txn.query('items', columns: ['job_id'], where: 'id = ?', whereArgs: [itemId]);
        if (r.isNotEmpty) jobId = r.first['job_id'] as String;
      }
      if (jobId != null) {
        await txn.update(
          'jobs',
          {'updated_at': ts.toIso8601String()},
          where: 'id = ?',
          whereArgs: [jobId],
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

class BatchPhotoInput {
  const BatchPhotoInput({required this.sourceFilePath, required this.capturedAt});
  final String sourceFilePath;
  final DateTime capturedAt;
}

class FileTooLargeException implements Exception {
  FileTooLargeException(this.sizeBytes);
  final int sizeBytes;
}

class UnsupportedFileTypeException implements Exception {
  UnsupportedFileTypeException(this.filename);
  final String filename;
}

String? _trimOrNull(String? v) {
  if (v == null) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}
