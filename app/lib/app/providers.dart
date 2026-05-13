import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/repositories/items_repository.dart';
import '../data/repositories/jobs_repository.dart';
import '../data/repositories/tags_repository.dart';
import '../data/storage/media_storage.dart';
import '../domain/models/job.dart';
import '../domain/models/tag.dart';
import '../domain/models/timeline_item.dart';
import '../domain/services/export_service.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Database not initialized'),
);

final mediaStorageProvider = Provider<MediaStorage>(
  (ref) => throw UnimplementedError('MediaStorage not initialized'),
);

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

/// Bumped whenever any data write happens; consumers use this to re-fetch.
final dataRevisionProvider = StateProvider<int>((_) => 0);

void bumpDataRevision(WidgetRef ref) {
  ref.read(dataRevisionProvider.notifier).state++;
}

class JobsListQuery {
  final String? search;
  final int revision;
  const JobsListQuery({this.search, required this.revision});
}

final jobsListProvider = FutureProvider.family<List<Job>, String?>((ref, search) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(jobsRepositoryProvider).all(query: search);
});

final jobSummariesProvider = FutureProvider<Map<String, JobSummary>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(jobsRepositoryProvider).summaries();
});

final jobProvider = FutureProvider.family<Job?, String>((ref, jobId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(jobsRepositoryProvider).byId(jobId);
});

final jobTimelineProvider =
    FutureProvider.family<List<TimelineItem>, String>((ref, jobId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(itemsRepositoryProvider).forJob(jobId);
});

final itemProvider = FutureProvider.family<TimelineItem?, String>((ref, itemId) {
  ref.watch(dataRevisionProvider);
  return ref.watch(itemsRepositoryProvider).byId(itemId);
});

final tagsProvider = FutureProvider<List<Tag>>((ref) {
  ref.watch(dataRevisionProvider);
  return ref.watch(tagsRepositoryProvider).all();
});
