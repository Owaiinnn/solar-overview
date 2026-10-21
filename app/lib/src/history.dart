import 'package:timezone/timezone.dart' as tz;

import 'site_time.dart';

String historyDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

String historyMonth(DateTime day) => historyDate(day).substring(0, 7);

DateTime? siteToday(String? zone, DateTime now) {
  final location = siteLocation(zone);
  if (location == null) return null;
  final local = tz.TZDateTime.from(now, location);
  return DateTime.utc(local.year, local.month, local.day);
}

double? historyNumber(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

class HistoryDay {
  HistoryDay(DateTime date, this.timeZone)
    : date = DateTime.utc(date.year, date.month, date.day) {
    final location = siteLocation(timeZone);
    if (location == null) throw const FormatException('Unknown site timezone');
    start = tz.TZDateTime(location, date.year, date.month, date.day).toUtc();
    end = tz.TZDateTime(location, date.year, date.month, date.day + 1).toUtc();
  }

  final DateTime date;
  final String timeZone;
  late final DateTime start;
  late final DateTime end;
  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  List<DateTime> buckets(Duration interval) => [
    for (var time = start; time.isBefore(end); time = time.add(interval)) time,
  ];
}

class HistorySample {
  const HistorySample(this.time, this.watts, {this.mppt1, this.mppt2});
  final DateTime time;
  final double? watts;
  final double? mppt1;
  final double? mppt2;
  Map<String, dynamic> toJson() => {
    'time': time.toUtc().toIso8601String(),
    'watts': watts,
    'mppt1': mppt1,
    'mppt2': mppt2,
  };
  factory HistorySample.fromJson(Map<String, dynamic> json) {
    final time = DateTime.parse(json['time'] as String);
    if (!time.isUtc) throw const FormatException();
    return HistorySample(
      time,
      historyNumber(json['watts']),
      mppt1: historyNumber(json['mppt1']),
      mppt2: historyNumber(json['mppt2']),
    );
  }
}

class ProductionHistory {
  ProductionHistory({
    required this.day,
    required this.interval,
    required List<HistorySample> samples,
    required Map<String, double?> dailyWh,
  }) : samples = List.unmodifiable(samples),
       dailyWh = Map.unmodifiable(dailyWh) {
    if (interval.inMinutes <= 0 ||
        samples.length > 1500 ||
        samples.any((sample) => !day.contains(sample.time))) {
      throw const FormatException();
    }
  }

  final HistoryDay day;
  final Duration interval;
  final List<HistorySample> samples;
  final Map<String, double?> dailyWh;
  double? get energyWh => dailyWh[historyDate(day.date)];
  Map<String, dynamic> toJson() => {
    'date': historyDate(day.date),
    'zone': day.timeZone,
    'minutes': interval.inMinutes,
    'samples': samples.map((sample) => sample.toJson()).toList(),
    'dailyWh': dailyWh,
  };
  factory ProductionHistory.fromJson(Map<String, dynamic> json) =>
      ProductionHistory(
        day: HistoryDay(
          DateTime.parse(json['date'] as String),
          json['zone'] as String,
        ),
        interval: Duration(minutes: json['minutes'] as int),
        samples: (json['samples'] as List)
            .map((row) => HistorySample.fromJson(row as Map<String, dynamic>))
            .toList(),
        dailyWh: (json['dailyWh'] as Map<String, dynamic>).map(
          (date, value) => MapEntry(date, historyNumber(value)),
        ),
      );
}

List<HistorySample> historyBuckets(
  HistoryDay day,
  Duration interval,
  Iterable<HistorySample> samples,
) {
  final values = <int, List<HistorySample>>{};
  for (final sample in samples.where((sample) => day.contains(sample.time))) {
    final index =
        sample.time.difference(day.start).inMilliseconds ~/
        interval.inMilliseconds;
    values.putIfAbsent(index, () => []).add(sample);
  }
  final buckets = day.buckets(interval);
  return [
    for (var index = 0; index < buckets.length; index++)
      if (values[index]?.length == 1)
        HistorySample(
          buckets[index],
          values[index]!.single.watts,
          mppt1: values[index]!.single.mppt1,
          mppt2: values[index]!.single.mppt2,
        )
      else
        HistorySample(buckets[index], null),
  ];
}

ProductionHistory? combinedPowerHistory(
  ProductionHistory? solarEdge,
  ProductionHistory? solax,
) {
  if (solarEdge == null || solax == null) return null;
  final day = solarEdge.day;
  if (day.date != solax.day.date || day.timeZone != solax.day.timeZone) {
    return null;
  }
  const interval = Duration(minutes: 15);
  if ([solarEdge, solax].any(
    (source) =>
        source.interval != interval &&
        source.interval != const Duration(minutes: 5),
  )) {
    return null;
  }
  final sources = <Map<DateTime, List<HistorySample>>>[];
  for (final source in [solarEdge, solax]) {
    final byTime = <DateTime, List<HistorySample>>{};
    for (final sample in source.samples) {
      byTime.putIfAbsent(sample.time.toUtc(), () => []).add(sample);
    }
    sources.add(byTime);
  }
  return ProductionHistory(
    day: day,
    interval: interval,
    samples: [
      for (final time in day.buckets(interval))
        HistorySample(time, _combinedWatts(sources, time)),
    ],
    dailyWh: const {},
  );
}

double? _combinedWatts(
  List<Map<DateTime, List<HistorySample>>> sources,
  DateTime time,
) {
  var total = 0.0;
  for (final source in sources) {
    final samples = source[time];
    if (samples == null || samples.length != 1) return null;
    final watts = historyNumber(samples.single.watts);
    if (watts == null) return null;
    total += watts;
  }
  return historyNumber(total);
}

String historyClock(DateTime instant, String zone) {
  final time = tz.TZDateTime.from(instant, siteLocation(zone)!);
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.timeZoneName}';
}
