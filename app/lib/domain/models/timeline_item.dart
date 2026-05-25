import 'package:flutter/foundation.dart';

import '../../core/note_markdown.dart';
import 'item.dart';
import 'media_file.dart';
import 'tag.dart';

/// An item joined with its media files and tags — what the UI actually shows.
@immutable
class TimelineItem {
  final Item item;
  final MediaFile? primaryPhoto;
  final MediaFile? voiceNote;
  final MediaFile? attachedFile;
  final MediaFile? annotationOverlay;
  final MediaFile? annotatedRender;
  final List<Tag> tags;

  const TimelineItem({
    required this.item,
    this.primaryPhoto,
    this.voiceNote,
    this.attachedFile,
    this.annotationOverlay,
    this.annotatedRender,
    this.tags = const [],
  });

  bool get hasPhoto => primaryPhoto != null;
  bool get hasVoice => voiceNote != null;
  bool get hasFile => attachedFile != null;
  bool get hasNote => (item.body ?? '').trim().isNotEmpty;
  bool get hasPhotoAnnotations => annotationOverlay != null;

  /// Timeline / detail thumbnail — annotated render when present.
  String? get displayPhotoRelativePath =>
      annotatedRender?.relativePath ?? primaryPhoto?.relativePath;

  String get previewText {
    final caption = (item.caption ?? '').trim();
    if (caption.isNotEmpty) return caption;
    if (hasFile) return attachedFile!.displayName;
    final body = notePlainTextPreview(item.body);
    if (body.isNotEmpty) return body;
    return '(no caption)';
  }
}

@immutable
class JobSummary {
  final String jobId;
  final int items;
  final int photos;
  final int voiceNotes;
  final int notes;
  final int files;
  final int issues;
  final DateTime? lastUpdated;
  final String? coverPhotoRelativePath;

  const JobSummary({
    required this.jobId,
    required this.items,
    required this.photos,
    required this.voiceNotes,
    required this.notes,
    required this.files,
    required this.issues,
    this.lastUpdated,
    this.coverPhotoRelativePath,
  });
}
