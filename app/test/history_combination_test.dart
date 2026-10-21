import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/history.dart';

ProductionHistory _history(
  HistoryDay day,
  List<HistorySample> samples, {
  int minutes = 15,
}) => ProductionHistory(
  day: day,
  interval: Duration(minutes: minutes),
  samples: samples,
  dailyWh: {historyDate(day.date): 2000},
);

void main() {
  final day = HistoryDay(DateTime.utc(2026, 10, 20), 'Europe/Amsterdam');
  final noon = day.start.add(const Duration(hours: 12));

  test(
    'combined AC adds matching 15-minute samples without adding energy or DC',
    () {
      final edge = _history(day, [HistorySample(noon, 1000, mppt1: 9000)]);
      final solax = _history(day, [
        HistorySample(noon, 300, mppt1: 9000),
        HistorySample(noon.add(const Duration(minutes: 5)), 8000),
        HistorySample(noon.add(const Duration(minutes: 10)), 9000),
        HistorySample(noon.add(const Duration(minutes: 15)), 400),
      ], minutes: 5);
      final combined = combinedPowerHistory(edge, solax)!;
      expect(combined.interval, const Duration(minutes: 15));
      expect(combined.samples.length, 96);
      expect(combined.samples[48].watts, 1300);
      expect(combined.samples[49].watts, isNull);
      expect(combined.energyWh, isNull);
      expect(combined.samples[48].mppt1, isNull);
      expect(edge.energyWh, 2000);
      expect(solax.samples.length, 4);
    },
  );

  test('missing samples and nearby timestamps never become a partial sum', () {
    final edge = _history(day, [HistorySample(noon, 1000)]);
    for (final samples in <List<HistorySample>>[
      [],
      [HistorySample(noon, null)],
      [HistorySample(noon.add(const Duration(minutes: 5)), 300)],
      [HistorySample(noon.add(const Duration(seconds: 1)), 300)],
    ]) {
      final combined = combinedPowerHistory(
        edge,
        _history(day, samples, minutes: 5),
      )!;
      expect(combined.samples.every((sample) => sample.watts == null), isTrue);
    }
    expect(combinedPowerHistory(edge, null), isNull);
    expect(combinedPowerHistory(null, edge), isNull);
  });

  test('reported zeros remain zero', () {
    final zero = _history(day, [HistorySample(noon, 0)]);
    expect(combinedPowerHistory(zero, zero)!.samples[48].watts, 0);
    expect(
      combinedPowerHistory(
        zero,
        _history(day, [HistorySample(noon, 300)]),
      )!.samples[48].watts,
      300,
    );
  });

  test('duplicate, negative, nonfinite and overflowing values remain gaps', () {
    final edge = _history(day, [HistorySample(noon, double.maxFinite)]);
    for (final samples in [
      [HistorySample(noon, 1), HistorySample(noon, 1)],
      [HistorySample(noon, -1)],
      [HistorySample(noon, double.nan)],
      [HistorySample(noon, double.infinity)],
      [HistorySample(noon, double.maxFinite)],
    ]) {
      expect(
        combinedPowerHistory(edge, _history(day, samples))!.samples[48].watts,
        isNull,
      );
      expect(
        combinedPowerHistory(_history(day, samples), edge)!.samples[48].watts,
        isNull,
      );
    }
  });

  test('different dates, zones and unsupported intervals cannot combine', () {
    final edge = _history(day, []);
    expect(
      combinedPowerHistory(
        edge,
        _history(HistoryDay(DateTime.utc(2026, 10, 19), day.timeZone), []),
      ),
      isNull,
    );
    expect(
      combinedPowerHistory(edge, _history(HistoryDay(day.date, 'UTC'), [])),
      isNull,
    );
    expect(combinedPowerHistory(edge, _history(day, [], minutes: 10)), isNull);
  });

  test(
    'combination preserves gaps and resumes only at the next matching sample',
    () {
      final edge = _history(day, [
        HistorySample(noon, 100),
        HistorySample(noon.add(const Duration(minutes: 30)), 200),
      ]);
      final solax = _history(day, [
        HistorySample(noon.add(const Duration(minutes: 30)), 300),
        HistorySample(noon.add(const Duration(minutes: 15)), 300),
        HistorySample(noon, 300),
      ]);
      expect(
        combinedPowerHistory(
          edge,
          solax,
        )!.samples.skip(48).take(3).map((sample) => sample.watts),
        [400, null, 500],
      );
    },
  );

  test('DST days use UTC instants and keep repeated local hours distinct', () {
    for (final (date, count) in [
      (DateTime.utc(2026, 3, 29), 92),
      (DateTime.utc(2026, 10, 25), 100),
    ]) {
      final dstDay = HistoryDay(date, day.timeZone);
      final edge = _history(dstDay, [
        for (final time in dstDay.buckets(const Duration(minutes: 15)))
          HistorySample(time, 100),
      ]);
      final combined = combinedPowerHistory(edge, edge)!;
      expect(combined.samples.length, count);
      expect(
        combined.samples.map((sample) => sample.time).toSet().length,
        count,
      );
      expect(combined.samples.every((sample) => sample.watts == 200), isTrue);
    }
  });
}
