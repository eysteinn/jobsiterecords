import 'package:flutter/foundation.dart';

@immutable
class Tag {
  final String id;
  final String name;
  final String? color;
  final bool isDefault;
  final int sortOrder;

  const Tag({
    required this.id,
    required this.name,
    this.color,
    required this.isDefault,
    required this.sortOrder,
  });

  Map<String, Object?> toDb() => {
        'id': id,
        'name': name,
        'color': color,
        'is_default': isDefault ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory Tag.fromDb(Map<String, Object?> r) => Tag(
        id: r['id']! as String,
        name: r['name']! as String,
        color: r['color'] as String?,
        isDefault: ((r['is_default'] as int?) ?? 0) == 1,
        sortOrder: (r['sort_order'] as int?) ?? 0,
      );
}
