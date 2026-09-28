import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/solaredge.dart';

void main() {
  SolarOverview reading(String? stamp, [String? zone = 'Europe/Amsterdam']) =>
      SolarOverview.fromJson({
        'currentPower': {'power': 0},
        'lastDayData': {'energy': 420},
        'lastUpdateTime': stamp,
      }, timeZone: zone);

  test(
    'site timezone resolves summer and winter independent of phone timezone',
    () {
      expect(
        reading('2026-09-28 14:00:00').reportedAtUtc,
        DateTime.utc(2026, 9, 28, 12),
      );
      expect(
        reading('2026-01-28 14:00:00').reportedAtUtc,
        DateTime.utc(2026, 1, 28, 13),
      );
      expect(
        reading('2026-09-28 14:00:00', 'Asia/Kolkata').reportedAtUtc,
        DateTime.utc(2026, 9, 28, 8, 30),
      );
    },
  );
  test('invalid dates, DST gaps and repeated hours never look fresh', () {
    for (final stamp in [
      null,
      '2026-02-30 12:00:00',
      '2026-01-01 25:00:00',
      '2026-03-29 02:30:00',
      '2026-10-25 02:30:00',
    ]) {
      final value = reading(stamp);
      expect(value.reportedAtUtc, isNull);
      expect(
        value.freshness(DateTime.utc(2026, 10, 25)),
        ReadingFreshness.unknown,
      );
      expect(value.todayEnergyWh(DateTime.utc(2026, 10, 25)), isNull);
    }
  });
  test(
    'missing and unknown zones and future timestamps have unknown freshness',
    () {
      for (final zone in [null, 'Invalid/Zone']) {
        expect(
          reading(
            '2026-09-28 14:00:00',
            zone,
          ).freshness(DateTime.utc(2026, 9, 28, 12)),
          ReadingFreshness.unknown,
        );
      }
      final value = reading('2026-09-28 14:00:00');
      expect(
        value.freshness(DateTime.utc(2026, 9, 28, 11)),
        ReadingFreshness.unknown,
      );
      expect(value.todayEnergyWh(DateTime.utc(2026, 9, 28, 11)), isNull);
    },
  );
  test(
    'freshness ages at 30 minutes and daily energy expires at site midnight',
    () {
      final value = reading('2026-09-28 23:45:00');
      expect(value.source, 'SolarEdge');
      expect(value.powerWatts, 0);
      expect(
        value.freshness(DateTime.utc(2026, 9, 28, 22, 14)),
        ReadingFreshness.recent,
      );
      expect(
        value.freshness(DateTime.utc(2026, 9, 28, 22, 15)),
        ReadingFreshness.stale,
      );
      expect(value.todayEnergyWh(DateTime.utc(2026, 9, 28, 21, 59)), 420);
      expect(value.todayEnergyWh(DateTime.utc(2026, 9, 28, 22)), isNull);
    },
  );
}
