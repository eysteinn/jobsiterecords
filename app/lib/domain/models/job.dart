import 'package:flutter/foundation.dart';

enum JobStatus {
  planning,
  inProgress,
  completed;

  String get label => switch (this) {
        JobStatus.planning => 'Planning',
        JobStatus.inProgress => 'In Progress',
        JobStatus.completed => 'Completed',
      };

  String get dbValue => switch (this) {
        JobStatus.planning => 'planning',
        JobStatus.inProgress => 'in_progress',
        JobStatus.completed => 'completed',
      };

  static JobStatus fromDb(String v) => switch (v) {
        'planning' => JobStatus.planning,
        'completed' => JobStatus.completed,
        _ => JobStatus.inProgress,
      };
}

@immutable
class Job {
  final String id;
  final String name;
  final String? clientName;
  final String? address;
  final String? jobNumber;
  final JobStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final String? coverItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Job({
    required this.id,
    required this.name,
    this.clientName,
    this.address,
    this.jobNumber,
    required this.status,
    this.startDate,
    this.endDate,
    this.notes,
    this.coverItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  Job copyWith({
    String? name,
    String? clientName,
    String? address,
    String? jobNumber,
    JobStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? coverItemId,
    DateTime? updatedAt,
  }) {
    return Job(
      id: id,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      address: address ?? this.address,
      jobNumber: jobNumber ?? this.jobNumber,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      coverItemId: coverItemId ?? this.coverItemId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'name': name,
        'client_name': clientName,
        'address': address,
        'job_number': jobNumber,
        'status': status.dbValue,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'notes': notes,
        'cover_item_id': coverItemId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Job.fromDb(Map<String, Object?> r) => Job(
        id: r['id']! as String,
        name: r['name']! as String,
        clientName: r['client_name'] as String?,
        address: r['address'] as String?,
        jobNumber: r['job_number'] as String?,
        status: JobStatus.fromDb((r['status'] as String?) ?? 'in_progress'),
        startDate: _parseDate(r['start_date']),
        endDate: _parseDate(r['end_date']),
        notes: r['notes'] as String?,
        coverItemId: r['cover_item_id'] as String?,
        createdAt: DateTime.parse(r['created_at']! as String),
        updatedAt: DateTime.parse(r['updated_at']! as String),
      );
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.tryParse(v as String);
}
