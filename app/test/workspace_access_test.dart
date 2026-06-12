import 'package:flutter_test/flutter_test.dart';
import 'package:jobsiterecords/sync/workspace_access.dart';

void main() {
  test('subscriptionSyncFooterLabel read_only', () {
    expect(
      subscriptionSyncFooterLabel({'access_mode': 'read_only'}),
      'Cloud sync paused · local records available',
    );
  });

  test('workspaceSyncPushAllowed defaults true', () {
    expect(workspaceSyncPushAllowed(null), isTrue);
    expect(workspaceSyncPushAllowed({'sync_push_allowed': false}), isFalse);
  });
}
