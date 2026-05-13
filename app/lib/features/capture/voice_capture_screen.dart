import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import 'widgets/tag_chips.dart';

class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({super.key, required this.jobId});
  final String jobId;

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

enum _Phase { idle, recording, paused, review, denied }

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen> {
  final _recorder = AudioRecorder();
  _Phase _phase = _Phase.idle;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  Timer? _timer;
  bool _saving = false;
  final _captionCtrl = TextEditingController();
  final Set<String> _tagIds = {};
  List<double> _amps = const [];

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    if (!await _recorder.hasPermission()) {
      setState(() => _phase = _Phase.denied);
      return;
    }

    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'voice_capture'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
    _elapsed = Duration.zero;
    _amps = const [];
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      if (!mounted) return;
      final amp = await _recorder.getAmplitude();
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt!);
        final db = amp.current;
        final norm = ((db + 60) / 60).clamp(0.0, 1.0);
        _amps = [..._amps, norm];
        if (_amps.length > 80) {
          _amps = _amps.sublist(_amps.length - 80);
        }
      });
    });

    setState(() {
      _phase = _Phase.recording;
      _filePath = path;
    });
  }

  Future<void> _togglePause() async {
    if (_phase == _Phase.recording) {
      await _recorder.pause();
      _timer?.cancel();
      setState(() => _phase = _Phase.paused);
    } else if (_phase == _Phase.paused) {
      await _recorder.resume();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        if (!mounted) return;
        final amp = await _recorder.getAmplitude();
        setState(() {
          _elapsed += const Duration(milliseconds: 200);
          final db = amp.current;
          final norm = ((db + 60) / 60).clamp(0.0, 1.0);
          _amps = [..._amps, norm];
          if (_amps.length > 80) _amps = _amps.sublist(_amps.length - 80);
        });
      });
      setState(() => _phase = _Phase.recording);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _filePath = path ?? _filePath;
      _phase = _Phase.review;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    if (_filePath != null) {
      final f = File(_filePath!);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    if (mounted) context.pop();
  }

  Future<void> _save() async {
    if (_filePath == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemsRepositoryProvider).createVoice(
            jobId: widget.jobId,
            sourceFilePath: _filePath!,
            caption: _captionCtrl.text,
            tagIds: _tagIds.toList(),
            durationMs: _elapsed.inMilliseconds,
          );
      bumpDataRevision(ref);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.denied) {
      return _denied();
    }
    if (_phase == _Phase.review) {
      return _review();
    }
    return _recorderView();
  }

  Scaffold _denied() => Scaffold(
        appBar: AppBar(title: const Text('Record Voice Note')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_off, size: 56, color: AppColors.subtle),
              const SizedBox(height: 12),
              const Text('Microphone unavailable',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 6),
              const Text('Allow microphone access in system settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.subtle)),
              const SizedBox(height: 16),
              TextButton(onPressed: openAppSettings, child: const Text('Open settings')),
            ],
          ),
        ),
      );

  Scaffold _recorderView() => Scaffold(
        appBar: AppBar(
          title: const Text('Record Voice Note'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _phase == _Phase.idle ? () => context.pop() : _cancel,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  height: 90,
                  child: _WaveformView(amps: _amps, active: _phase == _Phase.recording),
                ),
                const SizedBox(height: 28),
                Text(
                  formatDuration(_elapsed),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 36, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  switch (_phase) {
                    _Phase.idle => 'Tap to record',
                    _Phase.recording => 'Recording…',
                    _Phase.paused => 'Paused',
                    _ => '',
                  },
                  style: const TextStyle(color: AppColors.subtle),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_phase != _Phase.idle)
                      IconButton.filledTonal(
                        iconSize: 28,
                        onPressed: _cancel,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    const SizedBox(width: 28),
                    GestureDetector(
                      onTap: () {
                        if (_phase == _Phase.idle) {
                          _start();
                        } else {
                          _togglePause();
                        }
                      },
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                        child: Icon(
                          _phase == _Phase.recording ? Icons.pause : Icons.fiber_manual_record,
                          color: Colors.black,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    if (_phase != _Phase.idle)
                      IconButton.filled(
                        iconSize: 28,
                        style: IconButton.styleFrom(backgroundColor: Colors.black),
                        onPressed: _stop,
                        icon: const Icon(Icons.check, color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      );

  Widget _review() {
    final tagsAsync = ref.watch(tagsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Note')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: AppColors.accentDark),
                          const SizedBox(width: 10),
                          Text(formatDuration(_elapsed),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _captionCtrl,
                      maxLines: 3,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Caption (optional)',
                        hintText: 'What is this note about?',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tags', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    tagsAsync.when(
                      data: (tags) => TagChips(
                        allTags: tags,
                        selectedIds: _tagIds,
                        onToggle: (id) => setState(() {
                          if (!_tagIds.add(id)) _tagIds.remove(id);
                        }),
                        onAddTag: () async {
                          final name = await showAddTagDialog(context);
                          if (name == null || name.isEmpty) return;
                          final tag = await ref.read(tagsRepositoryProvider).create(name);
                          bumpDataRevision(ref);
                          setState(() => _tagIds.add(tag.id));
                        },
                      ),
                      loading: () => const SizedBox(height: 40),
                      error: (e, _) => Text('Error: $e'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              setState(() {
                                _phase = _Phase.idle;
                                _elapsed = Duration.zero;
                              });
                            },
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Re-record'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformView extends StatelessWidget {
  const _WaveformView({required this.amps, required this.active});
  final List<double> amps;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        const barWidth = 4.0;
        const gap = 2.0;
        final count = (c.maxWidth / (barWidth + gap)).floor();
        final displayed = amps.length >= count
            ? amps.sublist(amps.length - count)
            : List<double>.filled(count - amps.length, 0.0) + amps;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final v in displayed) ...[
              Container(
                width: barWidth,
                height: (v * c.maxHeight).clamp(3.0, c.maxHeight),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}
