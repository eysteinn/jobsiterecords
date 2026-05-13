import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/items_repository.dart';
import '../../data/repositories/jobs_repository.dart';
import '../../data/storage/media_storage.dart';
import '../models/item.dart';
import '../models/job.dart';
import '../models/timeline_item.dart';

class ExportOptions {
  final bool includeCaptions;
  final bool includeTags;
  final bool includeTimestamps;
  final bool includeNotes;
  final bool oldestFirst;

  const ExportOptions({
    this.includeCaptions = true,
    this.includeTags = true,
    this.includeTimestamps = true,
    this.includeNotes = true,
    this.oldestFirst = true,
  });
}

class ExportResult {
  final File zipFile;
  final int itemCount;
  final int sizeBytes;
  const ExportResult({required this.zipFile, required this.itemCount, required this.sizeBytes});
}

class ExportService {
  ExportService(this._jobsRepo, this._itemsRepo, this._storage);
  final JobsRepository _jobsRepo;
  final ItemsRepository _itemsRepo;
  final MediaStorage _storage;

  Future<ExportResult> exportJob({
    required String jobId,
    required Set<String> selectedItemIds,
    ExportOptions options = const ExportOptions(),
  }) async {
    final job = await _jobsRepo.byId(jobId);
    if (job == null) {
      throw StateError('Job not found');
    }
    final allItems = await _itemsRepo.forJob(jobId);
    final items = allItems.where((t) => selectedItemIds.contains(t.item.id)).toList();
    items.sort((a, b) => options.oldestFirst
        ? a.item.capturedAt.compareTo(b.item.capturedAt)
        : b.item.capturedAt.compareTo(a.item.capturedAt));

    final archive = Archive();

    for (final t in items) {
      if (t.primaryPhoto != null) {
        final f = File(_storage.absolutePath(t.primaryPhoto!.relativePath));
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          final name = _photoName(t);
          archive.addFile(ArchiveFile('photos/$name', bytes.length, bytes));
        }
      }
      if (t.voiceNote != null) {
        final f = File(_storage.absolutePath(t.voiceNote!.relativePath));
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          final name = _voiceName(t);
          archive.addFile(ArchiveFile('voice_notes/$name', bytes.length, bytes));
        }
      }
      if (t.item.kind == ItemKind.note && (t.item.body ?? '').isNotEmpty) {
        final name = _noteName(t);
        final body = t.item.body!;
        final bytes = utf8.encode(body);
        archive.addFile(ArchiveFile('notes/$name', bytes.length, bytes));
      }
    }

    final csv = _buildCsv(items, options);
    final csvBytes = utf8.encode(csv);
    archive.addFile(ArchiveFile('index.csv', csvBytes.length, csvBytes));

    final html = _buildHtml(job, items, options);
    final htmlBytes = utf8.encode(html);
    archive.addFile(ArchiveFile('index.html', htmlBytes.length, htmlBytes));

    final json = _buildJobJson(job, items, options);
    final jsonBytes = utf8.encode(json);
    archive.addFile(ArchiveFile('job.json', jsonBytes.length, jsonBytes));

    final encoder = ZipEncoder();
    final out = encoder.encode(archive);
    if (out == null) {
      throw StateError('Zip encoder returned null');
    }

    final tmpDir = await getTemporaryDirectory();
    final exportsDir = Directory(p.join(tmpDir.path, 'exports'));
    if (!await exportsDir.exists()) await exportsDir.create(recursive: true);
    final filename = _filename(job);
    final zipFile = File(p.join(exportsDir.path, filename));
    await zipFile.writeAsBytes(out, flush: true);

    return ExportResult(zipFile: zipFile, itemCount: items.length, sizeBytes: out.length);
  }

  String _filename(Job job) {
    final safe = job.name
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return 'SiteLog_${safe}_$stamp.zip';
  }

  String _stamp(DateTime t) =>
      DateFormat('yyyy-MM-dd_HH-mm').format(t.toLocal());

  String _shortCaption(TimelineItem t) {
    final c = (t.item.caption ?? '').trim();
    if (c.isEmpty) return 'item';
    final cleaned = c.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').replaceAll(RegExp(r'\s+'), '-');
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  String _photoName(TimelineItem t) => '${_stamp(t.item.capturedAt)}_${_shortCaption(t)}.jpg';
  String _voiceName(TimelineItem t) => '${_stamp(t.item.capturedAt)}_${_shortCaption(t)}.m4a';
  String _noteName(TimelineItem t) => '${_stamp(t.item.capturedAt)}_${_shortCaption(t)}.txt';

  String _csvEscape(String? v) {
    final s = v ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _buildCsv(List<TimelineItem> items, ExportOptions opts) {
    final b = StringBuffer();
    b.writeln('timestamp,kind,caption,tags,photo,voice,note');
    for (final t in items) {
      final cap = opts.includeCaptions ? t.item.caption : null;
      final tags = opts.includeTags ? t.tags.map((e) => e.name).join('|') : '';
      final photo = t.primaryPhoto != null ? 'photos/${_photoName(t)}' : '';
      final voice = t.voiceNote != null ? 'voice_notes/${_voiceName(t)}' : '';
      final note = t.item.kind == ItemKind.note ? 'notes/${_noteName(t)}' : '';
      b.write(_csvEscape(t.item.capturedAt.toLocal().toIso8601String()));
      b.write(',');
      b.write(_csvEscape(t.item.kind.dbValue));
      b.write(',');
      b.write(_csvEscape(cap));
      b.write(',');
      b.write(_csvEscape(tags));
      b.write(',');
      b.write(_csvEscape(photo));
      b.write(',');
      b.write(_csvEscape(voice));
      b.write(',');
      b.write(_csvEscape(note));
      b.writeln();
    }
    return b.toString();
  }

  String _buildJobJson(Job job, List<TimelineItem> items, ExportOptions opts) {
    final m = <String, Object?>{
      'schema': 'sitelog.job/v1',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'job': {
        'id': job.id,
        'name': job.name,
        'client_name': job.clientName,
        'address': job.address,
        'job_number': job.jobNumber,
        'status': job.status.dbValue,
        'start_date': job.startDate?.toIso8601String(),
        'end_date': job.endDate?.toIso8601String(),
        'notes': job.notes,
        'created_at': job.createdAt.toIso8601String(),
        'updated_at': job.updatedAt.toIso8601String(),
      },
      'options': {
        'include_captions': opts.includeCaptions,
        'include_tags': opts.includeTags,
        'include_timestamps': opts.includeTimestamps,
        'include_notes': opts.includeNotes,
        'oldest_first': opts.oldestFirst,
      },
      'items': [
        for (final t in items)
          {
            'id': t.item.id,
            'kind': t.item.kind.dbValue,
            'captured_at': t.item.capturedAt.toIso8601String(),
            'caption': opts.includeCaptions ? t.item.caption : null,
            'body': opts.includeNotes ? t.item.body : null,
            'tags': opts.includeTags ? t.tags.map((e) => e.name).toList() : <String>[],
            if (t.primaryPhoto != null)
              'photo': {
                'file': 'photos/${_photoName(t)}',
                'width': t.primaryPhoto!.width,
                'height': t.primaryPhoto!.height,
                'mime': t.primaryPhoto!.mimeType,
              },
            if (t.voiceNote != null)
              'voice': {
                'file': 'voice_notes/${_voiceName(t)}',
                'duration_ms': t.voiceNote!.durationMs,
                'mime': t.voiceNote!.mimeType,
              },
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(m);
  }

  String _buildHtml(Job job, List<TimelineItem> items, ExportOptions opts) {
    String esc(String? s) {
      if (s == null) return '';
      return s
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;');
    }

    final byDay = <String, List<TimelineItem>>{};
    for (final t in items) {
      final d = DateFormat('EEEE, MMMM d, y').format(t.item.capturedAt.toLocal());
      (byDay[d] ??= []).add(t);
    }

    final b = StringBuffer();
    b.writeln('<!doctype html>');
    b.writeln('<html lang="en"><head><meta charset="utf-8">');
    b.writeln('<title>SiteLog — ${esc(job.name)}</title>');
    b.writeln('<meta name="viewport" content="width=device-width,initial-scale=1">');
    b.writeln('<style>');
    b.writeln('''
      *{box-sizing:border-box}
      body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:880px;margin:24px auto;padding:0 16px;color:#111;line-height:1.45}
      header{border-bottom:2px solid #f59e0b;padding-bottom:12px;margin-bottom:24px}
      h1{margin:0 0 4px 0;font-size:28px}
      .sub{color:#555;font-size:14px}
      .meta{font-size:13px;color:#666;margin-top:6px}
      h2{margin:32px 0 12px;font-size:18px;color:#374151;border-bottom:1px solid #eee;padding-bottom:6px}
      .item{display:grid;grid-template-columns:160px 1fr;gap:14px;padding:14px 0;border-bottom:1px solid #f1f5f9}
      .item img{width:100%;height:auto;border-radius:6px;background:#f1f5f9}
      .item .when{font-size:12px;color:#6b7280}
      .item .cap{margin:4px 0 8px;font-weight:600}
      .tags{margin-top:6px}
      .tag{display:inline-block;padding:2px 8px;margin-right:6px;border-radius:999px;background:#fef3c7;color:#92400e;font-size:11px}
      audio{width:100%;margin-top:6px}
      .note{white-space:pre-wrap;background:#f9fafb;padding:10px;border-radius:6px;font-size:14px}
      footer{margin-top:32px;font-size:12px;color:#9ca3af;text-align:center}
      @media (max-width:560px){.item{grid-template-columns:1fr}}
    ''');
    b.writeln('</style></head><body>');

    b.writeln('<header>');
    b.writeln('<h1>${esc(job.name)}</h1>');
    final addrLine = [job.clientName, job.address].where((s) => (s ?? '').isNotEmpty).join(' · ');
    if (addrLine.isNotEmpty) b.writeln('<div class="sub">${esc(addrLine)}</div>');
    b.writeln('<div class="meta">${items.length} items · exported ${DateFormat.yMMMd().add_jm().format(DateTime.now())}</div>');
    b.writeln('</header>');

    final dayKeys = byDay.keys.toList();
    if (!opts.oldestFirst) {
      // already ordered by items list which respects oldestFirst.
    }

    for (final day in dayKeys) {
      b.writeln('<h2>${esc(day)}</h2>');
      for (final t in byDay[day]!) {
        b.writeln('<div class="item">');
        if (t.primaryPhoto != null) {
          b.writeln('<img alt="" src="photos/${esc(_photoName(t))}">');
        } else {
          b.writeln('<div></div>');
        }
        b.writeln('<div>');
        if (opts.includeTimestamps) {
          b.writeln('<div class="when">${esc(DateFormat.jm().format(t.item.capturedAt.toLocal()))} · ${esc(t.item.kind.label)}</div>');
        }
        if (opts.includeCaptions && (t.item.caption ?? '').isNotEmpty) {
          b.writeln('<div class="cap">${esc(t.item.caption)}</div>');
        }
        if (opts.includeNotes && (t.item.body ?? '').isNotEmpty) {
          b.writeln('<div class="note">${esc(t.item.body)}</div>');
        }
        if (t.voiceNote != null) {
          b.writeln('<audio controls preload="none" src="voice_notes/${esc(_voiceName(t))}"></audio>');
        }
        if (opts.includeTags && t.tags.isNotEmpty) {
          b.writeln('<div class="tags">');
          for (final tag in t.tags) {
            b.writeln('<span class="tag">${esc(tag.name)}</span>');
          }
          b.writeln('</div>');
        }
        b.writeln('</div></div>');
      }
    }

    b.writeln('<footer>Generated by SiteLog · ${esc(job.id)}</footer>');
    b.writeln('</body></html>');
    return b.toString();
  }
}
