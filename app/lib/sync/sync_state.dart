enum SyncState {
  localOnly('local_only'),
  synced('synced'),
  pending('pending'),
  failed('failed'),
  quarantined('quarantined');

  const SyncState(this.dbValue);
  final String dbValue;

  static SyncState fromDb(String? v) => SyncState.values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => SyncState.localOnly,
      );

  bool get needsPush => this == SyncState.pending || this == SyncState.failed;
}
