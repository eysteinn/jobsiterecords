import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/clock.dart';
import '../../core/ids.dart';

class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'jobsiterecords.db');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, _) async {
        await _createSchemaV1(d);
        await _seedDefaultTags(d);
      },
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}

Future<void> _createSchemaV1(Database d) async {
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
      captured_at TEXT NOT NULL,
      created_at  TEXT NOT NULL,
      updated_at  TEXT NOT NULL
    )
  ''');
  await d.execute('CREATE INDEX idx_items_job ON items(job_id, captured_at DESC)');

  await d.execute('''
    CREATE TABLE media_files (
      id            TEXT PRIMARY KEY,
      item_id       TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      role          TEXT NOT NULL,
      relative_path TEXT NOT NULL,
      mime_type     TEXT NOT NULL,
      width         INTEGER,
      height        INTEGER,
      duration_ms   INTEGER,
      size_bytes    INTEGER NOT NULL,
      created_at    TEXT NOT NULL
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

Future<void> _seedDefaultTags(Database d) async {
  final ts = now().toIso8601String();
  final defaults = <(String, String)>[
    ('Before', '#9CA3AF'),
    ('During', '#F59E0B'),
    ('After', '#10B981'),
    ('Issue', '#EF4444'),
    ('Completed', '#3B82F6'),
  ];
  final batch = d.batch();
  for (var i = 0; i < defaults.length; i++) {
    final (name, color) = defaults[i];
    batch.insert('tags', {
      'id': newId(),
      'name': name,
      'color': color,
      'is_default': 1,
      'sort_order': i,
    });
  }
  await batch.commit(noResult: true);
  // suppress unused warning
  ts.toString();
}
