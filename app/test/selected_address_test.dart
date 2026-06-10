import 'package:flutter_test/flutter_test.dart';
import 'package:jobsiterecords/core/selected_address.dart';

void main() {
  group('resolveSelectedAddress', () {
    test('prefers prediction when formatted drops letter suffix', () {
      const prediction = 'Laugavegur 54b, Reykjavík, Miðborg, Iceland';
      const formatted = 'Laugavegur 54, 101 Reykjavík, Iceland';

      expect(resolveSelectedAddress(prediction, formatted), prediction);
    });

    test('uses formatted address when street lines match', () {
      const prediction = 'Laugavegur 54, Reykjavík, Iceland';
      const formatted = 'Laugavegur 54, 101 Reykjavík, Iceland';

      expect(resolveSelectedAddress(prediction, formatted), formatted);
    });

    test('falls back to prediction when formatted is empty', () {
      const prediction = 'Laugavegur 54b, Reykjavík, Iceland';

      expect(resolveSelectedAddress(prediction, null), prediction);
      expect(resolveSelectedAddress(prediction, ''), prediction);
    });
  });
}
