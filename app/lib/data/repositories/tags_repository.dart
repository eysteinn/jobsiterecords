import '../../core/ids.dart';
import '../../domain/models/tag.dart';
import '../db/database.dart';

class TagsRepository {
  TagsRepository(this._db);
  final AppDatabase _db;

  Future<List<Tag>> all() async {
    final rows = await _db.db.query(
      'tags',
      orderBy: 'is_default DESC, sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Tag.fromDb).toList();
  }

  Future<Tag> create(String name, {String? color}) async {
    final existing = await _db.db.query(
      'tags',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name.trim()],
      limit: 1,
    );
    if (existing.isNotEmpty) return Tag.fromDb(existing.first);

    final maxRow = await _db.db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM tags');
    final sortOrder = (maxRow.first['n'] as int?) ?? 0;
    final tag = Tag(
      id: newId(),
      name: name.trim(),
      color: color,
      isDefault: false,
      sortOrder: sortOrder,
    );
    await _db.db.insert('tags', tag.toDb());
    return tag;
  }

  Future<void> rename(String id, String name) async {
    await _db.db.update('tags', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    await _db.db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }
}
