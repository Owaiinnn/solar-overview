import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/battery_store.dart';

import 'battery_fakes.dart';

void main() {
  test('only private canonical IPv4 addresses are accepted', () {
    for (final host in [
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.1.2',
    ]) {
      expect(BatteryAddress(host).host, host);
    }
    for (final host in [
      '',
      'a',
      '1.2.3',
      '127.0.0.1',
      '8.8.8.8',
      '172.32.0.1',
      '192.168.1.999',
      '192.168.01.2',
      'http://192.168.1.2',
      '192.168.1.2:8080',
      'user@192.168.1.2',
      'battery.local',
      '192.168.1.2/path',
      '192.168.1.2?x=1',
    ]) {
      expect(
        () => BatteryAddress(host),
        throwsA(isA<BatteryFailure>()),
        reason: host,
      );
    }
  });
  test('signs and separate DC/AC provenance; no inferred measurement time', () {
    final r = batteryReading();
    expect(r.state, BatteryState.charging);
    expect(r.packWatts, -200);
    expect(r.inverterAcWatts, 220);
    expect(r.totalAcWatts, 300);
    expect(r.dailyChargeKwh, 1.2);
    expect(r.statePowerConflict, isFalse);
    expect(r.measuredAt, isNull);
    expect(r.suitableForHouseholdBalance, isFalse);
    expect(batteryReading(power: 200, state: 1002).statePowerConflict, isFalse);
    expect(batteryReading(power: 200).statePowerConflict, isTrue);
    expect(batteryReading(power: 0, state: 1000).state, BatteryState.idle);
  });
  test('missing, malformed, unknown enums and zero are distinct', () {
    final r = BatteryReading.fromJson({
      '9405': 0,
      '6000': 0,
      '6001': 2222,
      '6004': -1,
      '6005': '0',
      '2275': double.infinity,
    });
    expect(r.percent, 0);
    expect(r.packWatts, 0);
    expect(r.state, BatteryState.unknown);
    expect(r.dailyChargeKwh, isNull);
    expect(r.dailyDischargeKwh, isNull);
    expect(r.inverterAcWatts, isNull);
    expect(
      BatteryReading.fromJson({'9405': 101, '6001': 1000}).percent,
      isNull,
    );
    for (final json in <Map<String, dynamic>>[
      {},
      {'9405': null},
      {'9405': -1},
      {'6000': double.nan},
      {'6001': 1001.5},
      {'6000': '200'},
    ]) {
      expect(
        () => BatteryReading.fromJson(json),
        throwsA(isA<BatteryFailure>()),
      );
    }
  });
  test('only allowlisted measurements survive storage roundtrip', () {
    final record = BatteryRecord(
      address: BatteryAddress('192.168.1.2'),
      reading: BatteryReading.fromJson({'9405': 0, 'serial': 'secret'}),
      receivedAt: batteryNow,
      nextAttempt: batteryNow.add(const Duration(seconds: 30)),
    );
    final encoded = jsonEncode(record.toJson());
    expect(encoded, isNot(contains('secret')));
    final restored = BatteryRecord.fromJson(jsonDecode(encoded));
    expect(restored.reading!.percent, 0);
    expect(restored.receivedAt, batteryNow);
    expect(restored.reading!.measuredAt, isNull);
    expect(
      () => BatteryRecord.fromJson({...record.toJson(), 'address': null}),
      throwsFormatException,
    );
    expect(
      () => BatteryRecord.fromJson({...record.toJson(), 'receivedAt': null}),
      throwsFormatException,
    );
    expect(
      () => BatteryRecord.fromJson({
        ...record.toJson(),
        'receivedAt': '2026-10-04T12:00:00',
      }),
      throwsFormatException,
    );
    expect(
      () => BatteryRecord.fromJson({...record.toJson(), 'failures': 5}),
      throwsFormatException,
    );
  });
  test('API sends read-only POST with exact points and no redirects', () async {
    final api = BatteryApi(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/rpc/Indevolt.GetData');
        expect(request.url.port, 8080);
        expect(request.url.scheme, 'http');
        expect(request.followRedirects, isFalse);
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.url.queryParameters['config']!), {
          't': [9405, 6001, 6000, 2275, 2278, 6004, 6005],
        });
        return http.Response('{"9405":0,"6000":-200,"6001":1001}', 200);
      }),
    );
    expect((await api.read(BatteryAddress('192.168.1.2'))).percent, 0);
  });
  test(
    'auth, redirect, status and malformed errors do not leak response data',
    () async {
      for (final response in [
        http.Response('secret', 401),
        http.Response('secret', 403),
        http.Response(
          'secret',
          302,
          headers: {'location': 'https://example.com/secret'},
        ),
        http.Response('secret', 500),
        http.Response('secret', 200),
        http.Response('[]', 200),
        http.Response('{}', 200),
      ]) {
        var requests = 0;
        final api = BatteryApi(
          MockClient((_) async {
            requests++;
            return response;
          }),
        );
        await expectLater(
          api.read(BatteryAddress('192.168.1.2')),
          throwsA(
            isA<BatteryFailure>().having(
              (e) => e.message,
              'redacted',
              isNot(contains('secret')),
            ),
          ),
        );
        expect(requests, 1);
      }
    },
  );
  test('timeout covers response body and aborts native request', () async {
    final stream = StreamController<List<int>>();
    final client = _StallingClient(stream.stream);
    final api = BatteryApi(client, timeout: const Duration(milliseconds: 10));
    await expectLater(
      api.read(BatteryAddress('192.168.1.2')),
      throwsA(isA<BatteryFailure>()),
    );
    await client.aborted.future;
    await stream.close();
  });
}

class _StallingClient extends http.BaseClient {
  _StallingClient(this.stream);
  final Stream<List<int>> stream;
  final aborted = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    (request as http.AbortableRequest).abortTrigger!.then(
      (_) => aborted.complete(),
    );
    return http.StreamedResponse(stream, 200);
  }
}
