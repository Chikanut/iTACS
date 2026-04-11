import 'package:flutter_application_1/pages/calendar_page/calendar_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalendarUtils', () {
    test('returns end of month as inclusive end of last day', () {
      final endOfMonth = CalendarUtils.getEndOfMonth(DateTime(2026, 3, 14));

      expect(endOfMonth.year, 2026);
      expect(endOfMonth.month, 3);
      expect(endOfMonth.day, 31);
      expect(endOfMonth.hour, 23);
      expect(endOfMonth.minute, 59);
      expect(endOfMonth.second, 59);
    });

    test('builds week days correctly on a month boundary', () {
      final weekDays = CalendarUtils.getWeekDays(DateTime(2026, 4, 2));

      expect(weekDays, [
        DateTime(2026, 3, 30),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 2),
        DateTime(2026, 4, 3),
        DateTime(2026, 4, 4),
        DateTime(2026, 4, 5),
      ]);
    });

    test(
      'adds calendar days without shifting the local day at DST boundary',
      () {
        final previousWeek = CalendarUtils.addDays(DateTime(2026, 3, 30), -7);

        expect(previousWeek, DateTime(2026, 3, 23));
        expect(previousWeek.hour, 0);
        expect(previousWeek.minute, 0);
      },
    );
  });
}
