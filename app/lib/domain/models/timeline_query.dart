import 'package:flutter/foundation.dart';

import 'item.dart';

/// Filters applied to a job timeline list.
@immutable
class TimelineQuery {
  const TimelineQuery({
    this.search,
    this.kinds = const {},
    this.tagIds = const {},
  });

  final String? search;
  final Set<ItemKind> kinds;
  final Set<String> tagIds;

  static const empty = TimelineQuery();

  String? get trimmedSearch {
    final s = search?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  bool get hasFilters =>
      trimmedSearch != null || kinds.isNotEmpty || tagIds.isNotEmpty;

  TimelineQuery copyWith({
    String? search,
    bool clearSearch = false,
    Set<ItemKind>? kinds,
    Set<String>? tagIds,
  }) {
    return TimelineQuery(
      search: clearSearch ? null : (search ?? this.search),
      kinds: kinds ?? this.kinds,
      tagIds: tagIds ?? this.tagIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineQuery &&
          trimmedSearch == other.trimmedSearch &&
          setEquals(kinds, other.kinds) &&
          setEquals(tagIds, other.tagIds);

  @override
  int get hashCode => Object.hash(
        trimmedSearch,
        Object.hashAllUnordered(kinds),
        Object.hashAllUnordered(tagIds),
      );
}
