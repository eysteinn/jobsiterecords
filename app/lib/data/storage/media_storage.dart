import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaStorage {
  MediaStorage._(this.root);
  final Directory root;

  static Future<MediaStorage> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory(p.join(dir.path, 'media'));
    if (!await media.exists()) {
      await media.create(recursive: true);
    }
    return MediaStorage._(media);
  }

  String absolutePath(String relativePath) => p.join(root.path, relativePath);

  Future<Directory> dirForItem(String jobId, String itemId) async {
    final d = Directory(p.join(root.path, jobId, itemId));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  String relativeFor(String jobId, String itemId, String filename) =>
      p.join(jobId, itemId, filename);

  Future<void> deleteForItem(String jobId, String itemId) async {
    final d = Directory(p.join(root.path, jobId, itemId));
    if (await d.exists()) {
      await d.delete(recursive: true);
    }
  }

  Future<void> deleteForJob(String jobId) async {
    final d = Directory(p.join(root.path, jobId));
    if (await d.exists()) {
      await d.delete(recursive: true);
    }
  }

  Future<int> totalSizeBytes() async {
    var total = 0;
    if (!await root.exists()) return 0;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
