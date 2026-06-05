import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/storage/media_storage.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Database not initialized'),
);

final mediaStorageProvider = Provider<MediaStorage>(
  (ref) => throw UnimplementedError('MediaStorage not initialized'),
);
