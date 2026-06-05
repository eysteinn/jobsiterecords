/// Tunable sync scheduler constants (S1 — see docs/sync-strategy-plan.md §7.1).
abstract final class SyncConfig {
  static const writeDebounce = Duration(seconds: 8);
  static const pendingHardCap = Duration(seconds: 60);
  static const minAutoSyncInterval = Duration(seconds: 30);
  static const resumeSyncThreshold = Duration(minutes: 2);
  static const periodicSyncInterval = Duration(minutes: 15);
  /// While job detail is open — pull web/supervisor changes without staring 15 min.
  static const watchJobPollInterval = Duration(seconds: 30);

  static const backoffSteps = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static const poisonQuarantineThreshold = 5;
}
