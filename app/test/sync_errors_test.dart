import 'package:flutter_test/flutter_test.dart';
import 'package:jobsiterecords/sync/api_client.dart';
import 'package:jobsiterecords/sync/sync_errors.dart';

void main() {
  group('classifySyncError', () {
    test('401 is auth', () {
      expect(
        classifySyncError(ApiException('unauthorized', statusCode: 401)),
        SyncErrorKind.auth,
      );
    });

    test('5xx is transient', () {
      expect(
        classifySyncError(ApiException('server', statusCode: 503)),
        SyncErrorKind.transient,
      );
    });

    test('permanent 4xx codes', () {
      for (final code in [400, 409, 413, 422]) {
        expect(
          classifySyncError(ApiException('bad', statusCode: code)),
          SyncErrorKind.permanent,
        );
      }
    });

    test('429 is transient', () {
      expect(
        classifySyncError(ApiException('rate', statusCode: 429)),
        SyncErrorKind.transient,
      );
    });
  });
}
