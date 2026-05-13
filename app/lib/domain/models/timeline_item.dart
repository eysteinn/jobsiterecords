import 'package:flutter/foundation.dart';

import 'item.dart';
import 'media_file.dart';
import 'tag.dart';

/// An item joined with its media files and tags — what the UI actually shows.
@immutable
class TimelineItem {
  final Item item;
  final MediaFile? primaryPhoto;
  final MediaFile? voiceNote;
  final List<Tag> tags;

  const TimelineItem({
    required this.item,
    this.primaryPhoto,
    this.voiceNote,
    this.tags = const [],
  });

  bool get hasPhoto => primaryPhoto != null;
  bool get hasVoice => voiceNote != null;
  bool get hasNote => (item.body ?? '').trim().isNotEmpty;
}

@immutable
class JobSummary {
  final String jobId;
  final int items;
  final int photos;
  final int voiceNotes;
  final int notes;
  final int issues;
  final DateTime? lastUpdated;
  final String? coverPhotoRelativePath;

  const JobSummary({
    required this.jobId,
    required this.items,
    required this.photos,
    required this.voiceNotes,
    required this.notes,
    required this.issues,
    this.lastUpdated,
    this.coverPhotoRelativePath,
  });
}
