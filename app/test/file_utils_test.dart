import 'package:flutter_test/flutter_test.dart';
import 'package:jobsiterecords/core/file_utils.dart';

void main() {
  group('sanitizeStorageFilename', () {
    test('preserves extension and sanitizes stem', () {
      expect(sanitizeStorageFilename('change order #2.pdf'), 'change_order_2.pdf');
    });

    test('falls back when stem is empty', () {
      expect(sanitizeStorageFilename('.pdf'), 'file.pdf');
    });
  });

  group('mimeFromFilename', () {
    test('detects pdf', () {
      expect(mimeFromFilename('receipt.pdf'), 'application/pdf');
    });

    test('detects jpeg', () {
      expect(mimeFromFilename('scan.JPG'), 'image/jpeg');
    });
  });

  group('isAllowedUploadExtension', () {
    test('allows pdf and images', () {
      expect(isAllowedUploadExtension('a.pdf'), isTrue);
      expect(isAllowedUploadExtension('b.png'), isTrue);
    });

    test('rejects other types', () {
      expect(isAllowedUploadExtension('doc.docx'), isFalse);
    });
  });
}
