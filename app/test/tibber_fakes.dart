import 'dart:async';
import 'dart:convert';

import 'package:solar_overview/src/tibber.dart';
import 'package:solar_overview/src/tibber_store.dart';

final tibberNow = DateTime.utc(2026, 10, 25, 0, 5);
Map<String, dynamic> priceJson(String start, {double? total = 0.2}) => {
  'startsAt': start,
  'total': total,
  'energy': total == null ? null : total - 0.1,
  'tax': 0.1,
  'currency': 'EUR',
};
Map<String, dynamic> homeJson({
  String id = 'test-home',
  String? status = 'running',
  List<dynamic>? today,
  List<dynamic>? tomorrow,
}) => {
  'id': id,
  'appNickname': 'Test home',
  'timeZone': 'Europe/Amsterdam',
  'currentSubscription': status == null
      ? null
      : {
          'status': status,
          'priceInfo': {
            'today':
                today ??
                [
                  priceJson('2026-10-25T02:00:00+02:00', total: -0.05),
                  priceJson('2026-10-25T02:15:00+02:00', total: 0),
                  priceJson('2026-10-25T02:00:00+01:00'),
                ],
            'tomorrow': tomorrow ?? [],
          },
        },
};
String responseJson({
  List<dynamic>? homes,
  Map<String, dynamic>? home,
  List<dynamic>? errors,
}) => jsonEncode({
  'data': {
    'viewer': home == null
        ? {
            'homes': homes ?? [homeJson()],
          }
        : {'home': home},
  },
  'errors': ?errors,
});
TibberHome testHome({
  String id = 'test-home',
  PriceResolution resolution = PriceResolution.quarterHourly,
  DateTime? day,
  bool complete = false,
  String? status = 'running',
}) {
  final base = TibberHome(
    id: id,
    name: 'Test home',
    timeZone: 'Europe/Amsterdam',
    subscriptionStatus: status,
    resolution: resolution,
    prices: [],
  );
  final start = complete
      ? base.day(day ?? tibberNow).toUtc()
      : DateTime.utc(2026, 10, 25);
  final count = complete ? base.expectedIntervals(day ?? tibberNow) : 3;
  return TibberHome(
    id: id,
    name: 'Test home',
    timeZone: base.timeZone,
    subscriptionStatus: status,
    resolution: resolution,
    prices: [
      for (var i = 0; i < count; i++)
        PriceInterval(
          start: start.add(Duration(minutes: i * resolution.minutes)),
          end: start.add(Duration(minutes: (i + 1) * resolution.minutes)),
          currency: 'EUR',
          total: i == 0
              ? -0.05
              : i == 1
              ? 0
              : 0.2,
          energy: i == 0
              ? -0.15
              : i == 1
              ? -0.1
              : 0.1,
          tax: 0.1,
        ),
    ],
  );
}

class MemoryTibberStore implements TibberStore {
  TibberRecord record = const TibberRecord();
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<TibberRecord> read() async {
    if (failRead) throw const FormatException();
    return TibberRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(TibberRecord value) async {
    writes++;
    if (failWrite) throw StateError('synthetic storage failure');
    record = value;
  }
}

class FakeTibberSource implements TibberSource {
  List<TibberHome> homes = [testHome()];
  TibberFailure? failure;
  Completer<List<TibberHome>>? pending;
  int calls = 0;
  String? requestedHome;
  @override
  Future<List<TibberHome>> read(
    String token,
    PriceResolution resolution, {
    String? homeId,
  }) async {
    calls++;
    requestedHome = homeId;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    return homes;
  }
}
