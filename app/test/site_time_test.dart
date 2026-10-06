import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/solar_freshness.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax.dart';

void main() {
  test('both solar sources preserve the exact freshness boundary', () {
    final stamp = DateTime.utc(2026, 9, 28, 12);
    final edge = SolarOverview(
      reportedAt: '2026-09-28 14:00:00',
      timeZone: 'Europe/Amsterdam',
    );
    final solax = SolaxReading.fromResponse({
      'dataTime': '2026-09-28T12:00:00Z',
    }, 'Europe/Amsterdam');
    for (final freshness in [edge.freshness, solax.freshness]) {
      expect(
        freshness(stamp.subtract(const Duration(microseconds: 1))),
        ReadingFreshness.unknown,
      );
      expect(freshness(stamp), ReadingFreshness.recent);
      expect(
        freshness(
          stamp
              .add(const Duration(minutes: 30))
              .subtract(const Duration(microseconds: 1)),
        ),
        ReadingFreshness.recent,
      );
      expect(
        freshness(stamp.add(const Duration(minutes: 30))),
        ReadingFreshness.stale,
      );
      expect(
        freshness(stamp.add(const Duration(minutes: 30)).toLocal()),
        ReadingFreshness.stale,
      );
    }
    expect(const SolarOverview().freshness(stamp), ReadingFreshness.unknown);
    expect(
      SolaxReading.fromResponse({}, 'Europe/Amsterdam').freshness(stamp),
      ReadingFreshness.unknown,
    );
  });
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
