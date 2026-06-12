import 'package:intl/intl.dart';

String formatJobDate(DateTime d) {
  final local = d.toLocal();
  return DateFormat.yMMMMd().format(local);
}

String formatDay(DateTime d) {
  final local = d.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(local.year, local.month, local.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today, ${DateFormat.yMMMd().format(local)}';
  if (diff == 1) return 'Yesterday, ${DateFormat.yMMMd().format(local)}';
  return DateFormat.yMMMMEEEEd().format(local);
}

String formatTime(DateTime d) {
  return DateFormat.jm().format(d.toLocal());
}

String formatRelative(DateTime d) {
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(d.toLocal());
}

/// Matches web `formatUpdatedLabel` — "Updated 2h ago" or full date when older.
String formatUpdatedLabel(DateTime d) {
  final diff = DateTime.now().toUtc().difference(d.toUtc());
  if (diff.inDays < 7) return 'Updated ${formatRelative(d)}';
  return 'Updated ${DateFormat.yMMMd().format(d.toLocal())}';
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
