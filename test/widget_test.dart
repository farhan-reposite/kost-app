import 'package:flutter_test/flutter_test.dart';
import 'package:kost_app/core/utils/date_helpers.dart';
import 'package:kost_app/core/utils/format.dart';

void main() {
  group('addMonthsAnchored', () {
    test('clamps to the last day of shorter months', () {
      expect(addMonthsAnchored(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsAnchored(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('returns to the anchor day afterwards', () {
      expect(addMonthsAnchored(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
    });

    test('crosses year boundaries', () {
      expect(addMonthsAnchored(DateTime(2026, 11, 15), 2), DateTime(2027, 1, 15));
    });
  });

  group('latestDueOnOrBefore', () {
    test('due day already passed this month', () {
      expect(
        latestDueOnOrBefore(DateTime(2026, 1, 12), DateTime(2026, 9, 20)),
        DateTime(2026, 9, 12),
      );
    });

    test('due day not reached yet this month', () {
      expect(
        latestDueOnOrBefore(DateTime(2026, 1, 25), DateTime(2026, 9, 20)),
        DateTime(2026, 8, 25),
      );
    });

    test('move-in in the future returns the move-in date', () {
      expect(
        latestDueOnOrBefore(DateTime(2026, 10, 1), DateTime(2026, 9, 20)),
        DateTime(2026, 10, 1),
      );
    });
  });

  test('normalizePhone', () {
    expect(normalizePhone('0812-3456-7890'), '6281234567890');
    expect(normalizePhone('+62 812 3456 7890'), '6281234567890');
  });

  test('naturalCompare sorts A2 before A10', () {
    final rooms = ['A10', 'A2', 'A1'];
    rooms.sort(naturalCompare);
    expect(rooms, ['A1', 'A2', 'A10']);
  });
}
