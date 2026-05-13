import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/models/job.dart';

class JobFormScreen extends ConsumerStatefulWidget {
  const JobFormScreen({super.key, this.jobId});
  final String? jobId;

  @override
  ConsumerState<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends ConsumerState<JobFormScreen> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _client;
  late TextEditingController _address;
  late TextEditingController _jobNumber;
  late TextEditingController _notes;
  JobStatus _status = JobStatus.inProgress;
  DateTime? _start;
  DateTime? _end;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _client = TextEditingController();
    _address = TextEditingController();
    _jobNumber = TextEditingController();
    _notes = TextEditingController();
    if (widget.jobId == null) _loaded = true;
  }

  Future<void> _loadIfNeeded(Job? job) async {
    if (_loaded || job == null) return;
    _name.text = job.name;
    _client.text = job.clientName ?? '';
    _address.text = job.address ?? '';
    _jobNumber.text = job.jobNumber ?? '';
    _notes.text = job.notes ?? '';
    _status = job.status;
    _start = job.startDate;
    _end = job.endDate;
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(jobsRepositoryProvider);
    try {
      if (widget.jobId == null) {
        await repo.create(
          name: _name.text,
          clientName: _client.text,
          address: _address.text,
          jobNumber: _jobNumber.text,
          status: _status,
          startDate: _start,
          endDate: _end,
          notes: _notes.text,
        );
      } else {
        final existing = await repo.byId(widget.jobId!);
        if (existing == null) return;
        await repo.update(existing.copyWith(
          name: _name.text,
          clientName: _client.text,
          address: _address.text,
          jobNumber: _jobNumber.text,
          status: _status,
          startDate: _start,
          endDate: _end,
          notes: _notes.text,
        ));
      }
      bumpDataRevision(ref);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.jobId != null;
    if (isEdit && !_loaded) {
      ref.watch(jobProvider(widget.jobId!)).whenData(_loadIfNeeded);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Job' : 'New Job'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(isEdit ? 'Save' : 'Create',
                style: const TextStyle(color: AppColors.accentDark, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _label('Name'),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(hintText: 'e.g. Kitchen Remodel'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _label('Client'),
                    TextFormField(controller: _client, decoration: const InputDecoration(hintText: 'Client name (optional)')),
                    const SizedBox(height: 12),
                    _label('Address'),
                    TextFormField(controller: _address, decoration: const InputDecoration(hintText: 'Site address (optional)')),
                    const SizedBox(height: 12),
                    _label('Job number'),
                    TextFormField(controller: _jobNumber, decoration: const InputDecoration(hintText: 'Optional')),
                    const SizedBox(height: 12),
                    _label('Status'),
                    SegmentedButton<JobStatus>(
                      segments: const [
                        ButtonSegment(value: JobStatus.planning, label: Text('Planning')),
                        ButtonSegment(value: JobStatus.inProgress, label: Text('In Progress')),
                        ButtonSegment(value: JobStatus.completed, label: Text('Completed')),
                      ],
                      selected: {_status},
                      onSelectionChanged: (s) => setState(() => _status = s.first),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _DateField(label: 'Start', value: _start, onPick: (d) => setState(() => _start = d))),
                        const SizedBox(width: 12),
                        Expanded(child: _DateField(label: 'End', value: _end, onPick: (d) => setState(() => _end = d))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _label('Notes'),
                    TextFormField(
                      controller: _notes,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Optional details about the job'),
                    ),
                    const SizedBox(height: 24),
                    if (isEdit)
                      OutlinedButton.icon(
                        onPressed: _saving ? null : () async {
                          final ok = await _confirmDelete(context);
                          if (ok != true) return;
                          await ref.read(jobsRepositoryProvider).delete(widget.jobId!);
                          bumpDataRevision(ref);
                          if (!mounted) return;
                          context.go('/jobs');
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Delete Job', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
      );

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete job?'),
          content: const Text('This will permanently delete the job and all of its photos, voice notes, and notes from this device.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
            );
            onPick(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 18, color: AppColors.subtle),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null ? 'Pick a date' : formatJobDate(value!),
                    style: TextStyle(
                      color: value == null ? AppColors.subtle : AppColors.ink,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => onPick(null),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
