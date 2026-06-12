import 'package:flutter/foundation.dart';

import 'item.dart';

/// Filters applied to a job timeline list.
@immutable
class TimelineQuery {
  const TimelineQuery({
    this.search,
    this.kinds = const {},
    this.tagIds = const {},
    this.fromDate,
    this.toDate,
    this.sortOldest = false,
  });

  final String? search;
  final Set<ItemKind> kinds;
  final Set<String> tagIds;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool sortOldest;

  static const empty = TimelineQuery();

  String? get trimmedSearch {
    final s = search?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Single active kind for summary chip UI (null = All).
  ItemKind? get activeKind => kinds.length == 1 ? kinds.first : null;

  bool get hasFilters =>
      trimmedSearch != null ||
      kinds.isNotEmpty ||
      tagIds.isNotEmpty ||
      fromDate != null ||
      toDate != null ||
      sortOldest;

  bool get hasAdvancedFilters =>
      kinds.isNotEmpty || tagIds.isNotEmpty || fromDate != null || toDate != null || sortOldest;

  TimelineQuery copyWith({
    String? search,
    bool clearSearch = false,
    Set<ItemKind>? kinds,
    bool clearKinds = false,
    Set<String>? tagIds,
    bool clearTagIds = false,
    DateTime? fromDate,
    bool clearFromDate = false,
    DateTime? toDate,
    bool clearToDate = false,
    bool? sortOldest,
    bool clearAll = false,
  }) {
    if (clearAll) return TimelineQuery.empty;
    return TimelineQuery(
      search: clearSearch ? null : (search ?? this.search),
      kinds: clearKinds ? const {} : (kinds ?? this.kinds),
      tagIds: clearTagIds ? const {} : (tagIds ?? this.tagIds),
      fromDate: clearFromDate ? null : (fromDate ?? this.fromDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      sortOldest: sortOldest ?? this.sortOldest,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineQuery &&
          trimmedSearch == other.trimmedSearch &&
          setEquals(kinds, other.kinds) &&
          setEquals(tagIds, other.tagIds) &&
          fromDate == other.fromDate &&
          toDate == other.toDate &&
          sortOldest == other.sortOldest;

  @override
  int get hashCode => Object.hash(
        trimmedSearch,
        Object.hashAllUnordered(kinds),
        Object.hashAllUnordered(tagIds),
        fromDate,
        toDate,
        sortOldest,
      );
}
