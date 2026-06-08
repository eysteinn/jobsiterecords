import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/ids.dart';

const _dbVersion = 6;

class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'jobsiterecords.db');
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, _) async {
        await _createSchema(d);
        await _seedDefaultTags(d);
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await d.execute('ALTER TABLE media_files ADD COLUMN original_filename TEXT');
          await _insertMissingDefaultTags(d);
        }
        if (oldVersion < 3) {
          await d.execute('ALTER TABLE jobs ADD COLUMN workspace_id TEXT');
          await d.execute("ALTER TABLE jobs ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'local_only'");
          await d.execute('ALTER TABLE jobs ADD COLUMN last_synced_at TEXT');
          await d.execute("ALTER TABLE items ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'local_only'");
          await d.execute('ALTER TABLE items ADD COLUMN last_synced_at TEXT');
          await d.execute('''
            CREATE TABLE sync_meta (
              key   TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await d.execute("ALTER TABLE media_files ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'local_only'");
          await d.execute('ALTER TABLE media_files ADD COLUMN remote_storage_key TEXT');
          await d.execute('ALTER TABLE media_files ADD COLUMN updated_at TEXT');
          await d.execute('UPDATE media_files SET updated_at = created_at WHERE updated_at IS NULL');
        }
        if (oldVersion < 5) {
          for (final table in ['jobs', 'items', 'media_files']) {
            await d.execute('ALTER TABLE $table ADD COLUMN sync_attempts INTEGER NOT NULL DEFAULT 0');
            await d.execute('ALTER TABLE $table ADD COLUMN last_sync_error TEXT');
          }
        }
        if (oldVersion < 6) {
          await d.execute('ALTER TABLE jobs ADD COLUMN deleted_at TEXT');
          await d.execute('ALTER TABLE items ADD COLUMN deleted_at TEXT');
        }
      },
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}

Future<void> _createSchema(Database d) async {
  await d.execute('''
    CREATE TABLE jobs (
      id            TEXT PRIMARY KEY,
      name          TEXT NOT NULL,
      client_name   TEXT,
      address       TEXT,
      job_number    TEXT,
      status        TEXT NOT NULL DEFAULT 'in_progress',
      start_date    TEXT,
      end_date      TEXT,
      notes         TEXT,
      cover_item_id TEXT,
      workspace_id  TEXT,
      sync_state    TEXT NOT NULL DEFAULT 'local_only',
      last_synced_at TEXT,
      sync_attempts INTEGER NOT NULL DEFAULT 0,
      last_sync_error TEXT,
      deleted_at    TEXT,
      created_at    TEXT NOT NULL,
      updated_at    TEXT NOT NULL
    )
  ''');

  await d.execute('''
    CREATE TABLE items (
      id          TEXT PRIMARY KEY,
      job_id      TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
      kind        TEXT NOT NULL,
      caption     TEXT,
      body        TEXT,
      sync_state  TEXT NOT NULL DEFAULT 'local_only',
      last_synced_at TEXT,
      sync_attempts INTEGER NOT NULL DEFAULT 0,
      last_sync_error TEXT,
      deleted_at  TEXT,
      captured_at TEXT NOT NULL,
      created_at  TEXT NOT NULL,
      updated_at  TEXT NOT NULL
    )
  ''');
  await d.execute('CREATE INDEX idx_items_job ON items(job_id, captured_at DESC)');

  await d.execute('''
    CREATE TABLE media_files (
      id                TEXT PRIMARY KEY,
      item_id           TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      role              TEXT NOT NULL,
      relative_path     TEXT NOT NULL,
      mime_type         TEXT NOT NULL,
      width             INTEGER,
      height            INTEGER,
      duration_ms       INTEGER,
      size_bytes        INTEGER NOT NULL,
      original_filename TEXT,
      sync_state        TEXT NOT NULL DEFAULT 'local_only',
      remote_storage_key TEXT,
      sync_attempts     INTEGER NOT NULL DEFAULT 0,
      last_sync_error   TEXT,
      created_at        TEXT NOT NULL,
      updated_at        TEXT NOT NULL
    )
  ''');
  await d.execute('CREATE INDEX idx_media_item ON media_files(item_id)');

  await d.execute('''
    CREATE TABLE tags (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL UNIQUE COLLATE NOCASE,
      color       TEXT,
      is_default  INTEGER NOT NULL DEFAULT 0,
      sort_order  INTEGER NOT NULL DEFAULT 0
    )
  ''');

  await d.execute('''
    CREATE TABLE item_tags (
      item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      tag_id  TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
      PRIMARY KEY (item_id, tag_id)
    )
  ''');
  await d.execute('CREATE INDEX idx_item_tags_tag ON item_tags(tag_id)');
}

/// Default tags seeded on first install.
List<(String, String)> get defaultTagDefinitions => [
      ('Before', '#9CA3AF'),
      ('During', '#F59E0B'),
      ('After', '#10B981'),
      ('Issue', '#EF4444'),
      ('Completed', '#3B82F6'),
      ('Receipt', '#14B8A6'),
    ];

Future<void> _seedDefaultTags(Database d) async {
  final batch = d.batch();
  for (var i = 0; i < defaultTagDefinitions.length; i++) {
    final (name, color) = defaultTagDefinitions[i];
    batch.insert('tags', {
      'id': newId(),
      'name': name,
      'color': color,
      'is_default': 1,
      'sort_order': i,
    });
  }
  await batch.commit(noResult: true);
}

/// Inserts default tags that are missing (case-insensitive). Used on upgrade.
Future<void> _insertMissingDefaultTags(Database d) async {
  final maxOrder = Sqflite.firstIntValue(
        await d.rawQuery('SELECT MAX(sort_order) FROM tags'),
      ) ??
      -1;
  var nextOrder = maxOrder + 1;
  for (final (name, color) in defaultTagDefinitions) {
    final existing = await d.query(
      'tags',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isEmpty) {
      await d.insert('tags', {
        'id': newId(),
        'name': name,
        'color': color,
        'is_default': 1,
        'sort_order': nextOrder++,
      });
    }
  }
}
