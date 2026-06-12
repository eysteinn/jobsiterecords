/// Helpers for workspace subscription / trial access from the auth session payload.

Map<String, dynamic>? findWorkspace(
  List<Map<String, dynamic>> workspaces,
  String workspaceId,
) {
  for (final ws in workspaces) {
    if (ws['id'] == workspaceId) return ws;
  }
  return null;
}

String workspaceAccessMode(Map<String, dynamic>? workspace) {
  return workspace?['access_mode'] as String? ?? 'active';
}

bool workspaceSyncPushAllowed(Map<String, dynamic>? workspace) {
  return workspace?['sync_push_allowed'] as bool? ?? true;
}

bool workspaceWritable(Map<String, dynamic>? workspace) {
  return workspace?['writable'] as bool? ?? true;
}

int workspaceGraceDaysRemaining(Map<String, dynamic>? workspace) {
  return workspace?['grace_days_remaining'] as int? ?? 0;
}

/// Short footer label for subscription-related sync states.
String subscriptionSyncFooterLabel(Map<String, dynamic>? workspace) {
  final mode = workspaceAccessMode(workspace);
  if (mode == 'read_only') {
    return 'Cloud sync paused · local records available';
  }
  if (mode == 'grace') {
    final days = workspaceGraceDaysRemaining(workspace);
    if (days > 0) {
      return 'Billing issue · sync works for $days ${days == 1 ? 'day' : 'days'}';
    }
    return 'Billing issue · update subscription';
  }
  if (mode == 'trial') {
    return 'Free trial · limited workspace';
  }
  return '';
}

/// Full mobile banner copy when cloud sync is paused.
const subscriptionSyncPausedBanner =
    'Cloud sync is paused. Your local records are still available on this device. '
    'Reactivate subscription to continue syncing with the web dashboard and your team.';
