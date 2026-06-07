import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/item.dart';
import '../../domain/models/timeline_item.dart';

/// Consecutive photos → grid segment; voice/notes/files → row segments.
List<_TimelineSegment> _segmentDayTimelineItems(List<TimelineItem> dayItems) {
  final segments = <_TimelineSegment>[];
  var photoBatch = <TimelineItem>[];

  void flush() {
    if (photoBatch.isNotEmpty) {
      segments.add(_PhotoSegment(List.of(photoBatch)));
      photoBatch = [];
    }
  }

  for (final t in dayItems) {
    if (t.item.kind == ItemKind.photo) {
      photoBatch.add(t);
    } else {
      flush();
      segments.add(_RowSegment(t));
    }
  }
  flush();
  return segments;
}

sealed class _TimelineSegment {}

class _PhotoSegment extends _TimelineSegment {
  _PhotoSegment(this.items);
  final List<TimelineItem> items;
}

class _RowSegment extends _TimelineSegment {
  _RowSegment(this.item);
  final TimelineItem item;
}

class TimelineDayContent extends StatelessWidget {
  const TimelineDayContent({
    super.key,
    required this.dayItems,
    required this.storage,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
    required this.rowBuilder,
  });

  final List<TimelineItem> dayItems;
  final String Function(String) storage;
  final bool selecting;
  final Set<String> selected;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onLongPress;
  final Widget Function(TimelineItem item) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final segments = _segmentDayTimelineItems(dayItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          switch (segments[i]) {
            _PhotoSegment(:final items) => _PhotoGrid(
                items: items,
                storage: storage,
                selecting: selecting,
                selected: selected,
                onToggle: onToggle,
                onLongPress: onLongPress,
              ),
            _RowSegment(:final item) => rowBuilder(item),
          },
        ],
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.items,
    required this.storage,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
  });

  final List<TimelineItem> items;
  final String Function(String) storage;
  final bool selecting;
  final Set<String> selected;
  final void Function(String itemId) onToggle;
  final void Function(String itemId) onLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const minCellWidth = 100.0;
        final columns =
            ((constraints.maxWidth + spacing) / (minCellWidth + spacing)).floor().clamp(2, 4);
        final cellWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final t in items)
              SizedBox(
                width: cellWidth,
                child: _PhotoCell(
                  timeline: t,
                  storage: storage,
                  selecting: selecting,
                  selected: selected.contains(t.item.id),
                  onToggle: () => onToggle(t.item.id),
                  onLongPress: () => onLongPress(t.item.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.timeline,
    required this.storage,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onLongPress,
  });

  final TimelineItem timeline;
  final String Function(String) storage;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = timeline;
    final path = t.displayPhotoRelativePath;
    final hasImage = path != null && File(storage(path)).existsSync();
    final caption = t.previewText;
    final emptyCaption = caption == '(no caption)';
    final time = formatTime(t.item.capturedAt);

    return Semantics(
      label: 'Photo, $time, ${emptyCaption ? 'no caption' : caption}'
          '${t.hasPhotoAnnotations ? ', annotated' : ''}',
      button: true,
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: selecting
              ? onToggle
              : () => context.pushNamed('item-detail', pathParameters: {'id': t.item.id}),
          onLongPress: selecting ? null : onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected ? AppColors.accent : const Color(0xFFE5E7EB),
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: hasImage
                            ? Image.file(
                                File(storage(path)),
                                key: ValueKey(
                                  '${t.item.updatedAt.millisecondsSinceEpoch}-${t.annotatedRender?.sizeBytes ?? 0}',
                                ),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: const Color(0xFFF3F4F6),
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_outlined, color: AppColors.subtle),
                              ),
                      ),
                    ),
                    if (t.hasPhotoAnnotations && !selecting)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('✎', style: TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          time,
                          style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.2),
                        ),
                      ),
                    ),
                    if (selecting)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: Checkbox(
                            value: selected,
                            onChanged: (_) => onToggle(),
                            activeColor: AppColors.accent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emptyCaption ? 'No caption' : caption,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: emptyCaption ? AppColors.subtle : AppColors.ink,
                  fontStyle: emptyCaption ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
