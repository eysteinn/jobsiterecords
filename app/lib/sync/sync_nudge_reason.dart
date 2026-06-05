enum SyncNudgeReason {
  write,
  launch,
  foreground,
  workspaceSwitch,
  connectivity,
  periodic,
  /// Fast poll while job detail is open — pull remote changes (e.g. supervisor on web).
  watching,
  manual,
}

extension SyncNudgeReasonX on SyncNudgeReason {
  bool get bypassesRateLimit => this == SyncNudgeReason.manual;

  bool get bypassesBackoff =>
      this == SyncNudgeReason.manual ||
      this == SyncNudgeReason.launch ||
      this == SyncNudgeReason.foreground ||
      this == SyncNudgeReason.workspaceSwitch ||
      this == SyncNudgeReason.connectivity;

  bool get isManual => this == SyncNudgeReason.manual;
}
