import 'package:path/path.dart' as p;

const maxUploadBytes = 50 * 1024 * 1024;

const allowedUploadExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'heic'];

String mimeFromFilename(String filename) {
  return mimeFromExtension(p.extension(filename));
}

String mimeFromExtension(String ext) {
  return switch (ext.toLowerCase().replaceFirst('.', '')) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'heic' => 'image/heic',
    _ => 'application/octet-stream',
  };
}

String sanitizeStorageFilename(String original) {
  final base = p.basename(original.trim());
  if (base.isEmpty) return 'file.bin';
  var ext = p.extension(base);
  var stem = p.basenameWithoutExtension(base);
  // Names like ".pdf" have no extension per `path` — treat the whole name as ext.
  if (ext.isEmpty && stem.startsWith('.') && stem.length > 1) {
    ext = stem;
    stem = '';
  }
  stem = stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').replaceAll(RegExp(r'_+'), '_');
  if (!RegExp(r'[A-Za-z0-9]').hasMatch(stem)) {
    return 'file${ext.isEmpty ? '.bin' : ext}';
  }
  return '$stem$ext';
}

bool isAllowedUploadExtension(String filename) {
  final ext = p.extension(filename).replaceFirst('.', '').toLowerCase();
  return allowedUploadExtensions.contains(ext);
}
