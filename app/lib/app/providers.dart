import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/items_repository.dart';
import '../data/repositories/jobs_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../domain/models/job.dart';
import '../domain/models/tag.dart';
import '../domain/models/timeline_item.dart';
import '../domain/models/timeline_query.dart';
import '../domain/services/export_service.dart';
import '../sync/sync_nudge_reason.dart';
import '../sync/sync_providers.dart';
import '../sync/sync_runner.dart';
import '../sync/sync_scheduler.dart';
import 'data_revision.dart';
import 'storage_providers.dart';

export 'data_revision.dart';
export 'storage_providers.dart';
export '../sync/sync_providers.dart' show SyncStatus, syncStatusProvider;

final jobsRepositoryProvider = Provider<JobsRepository>(
  (ref) => JobsRepository(ref.watch(databaseProvider), ref.watch(mediaStorageProvider)),
);

final itemsRepositoryProvider = Provider<ItemsRepository>(
  (ref) => ItemsRepository(ref.watch(databaseProvider), ref.watch(mediaStorageProvider)),
);

final tagsRepositoryProvider = Provider<TagsRepository>(
  (ref) => TagsRepository(ref.watch(databaseProvider)),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(
    ref.watch(jobsRepositoryProvider),
    ref.watch(itemsRepositoryProvider),
    ref.watch(mediaStorageProvider),
  ),
);

void bumpDataRevision(WidgetRef ref) {
  ref.read(dataRevisionProvider.notifier).state++;
  final ctx = ref.read(captureContextProvider);
  if (ctx.isWorkspace) {
    ref.read(syncSchedulerProvider).nudge(SyncNudgeReason.write);
    unawaited(ref.read(syncExecutorProvider).refreshCounts());
  }
}

class JobsListQuery {
  final String? search;
  final int revision;
  const JobsListQuery({this.search, required this.revision});
}

final jobsListProvider = FutureProvider.family<List<Job>, String?>((ref, search) async {
  ref.watch(dataRevisionProvider);
  final ctx = ref.watch(captureContextProvider);
  return ref.watch(jobsRepositoryProvider).all(
        query: search,
        localOnly: ctx.isLocal,
        workspaceId: ctx.workspaceId,
      );
});

final jobSummariesProvider = FutureProvider<Map<String, JobSummary>>((ref) {
  ref.watch(dataRevisionProvider);
  final ctx = ref.watch(captureContextProvider);
  return ref.watch(jobsRepositoryProvider).summaries(
        localOnly: ctx.isLocal,
        workspaceId: ctx.workspaceId,
      );
});

final jobProvider = FutureProvider.family<Job?, String>((ref, jobId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(jobsRepositoryProvider).byId(jobId);
});

typedef JobTimelineKey = ({String jobId, TimelineQuery query});

final jobTimelineProvider =
    FutureProvider.family<List<TimelineItem>, JobTimelineKey>((ref, key) {
  ref.watch(dataRevisionProvider);
  return ref.watch(itemsRepositoryProvider).forJob(key.jobId, query: key.query);
});

final itemProvider = FutureProvider.family<TimelineItem?, String>((ref, itemId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(itemsRepositoryProvider).byId(itemId);
});

final tagsProvider = FutureProvider<List<Tag>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(tagsRepositoryProvider).all();
});

