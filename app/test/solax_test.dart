import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_overview/src/solax.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'solax_fakes.dart';

http.Response response(Object? result, {int code = 10000}) =>
    http.Response(jsonEncode({'code': code, 'result': result}), 200);
final testToken = SolaxToken(
  'synthetic-token',
  solaxNow.add(const Duration(days: 20)),
);
Map<String, dynamic> page(
  List<Map<String, dynamic>> records, {
  int current = 1,
  int pages = 1,
  int? total,
}) => {
  'records': records,
  'current': current,
  'pages': pages,
  'total': total ?? records.length,
};
void main() {
  test('a timeout aborts the underlying native request', () async {
    final client = StalledClient();
    await expectLater(
      SolaxApi(
        client,
        timeout: const Duration(milliseconds: 1),
      ).plants(testToken),
      throwsA(isA<SolaxFailure>()),
    );
    await client.aborted.future;
    expect(client.aborted.isCompleted, isTrue);
  });

  test('live UTC offset and vendor timezone label retain DST rules', () {
    final r = SolaxReading.fromResponse({
      'dataTime': '2026-09-29T07:25:01.000+00:00',
      'plantLocalTime': '2026-09-29 09:25:01',
      'mpptMap': {'mppt1Power': 0, 'mppt2Power': 12},
    }, '(UTC+01:00)Amsterdam,Berlin,Bern,Rome,Stockholm,Vienna');
    expect(r.timeZone, 'Europe/Amsterdam');
    expect(r.reportedAtUtc, DateTime.utc(2026, 9, 29, 7, 25, 1));
    expect(r.mpptPowerWatts(1), 0);
    expect(r.mpptPowerWatts(2), 12);
    expect(SolaxReading.fromJson(r.toJson()).reportedAtUtc, r.reportedAtUtc);
  });

  test('auth uses EU form body, lowercase bearer and no redirects', () async {
    final requests = <http.Request>[];
    final api = SolaxApi(
      MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'openapi-eu.solaxcloud.com');
        expect(request.followRedirects, isFalse);
        if (request.method == 'POST') {
          expect(request.url.query, isEmpty);
          expect(request.bodyFields, {
            'client_id': 'client',
            'client_secret': 'secret&value',
            'grant_type': 'client_credentials',
          });
          return response({
            'access_token': 'returned-token',
            'expires_in': 2591999,
          }, code: 0);
        }
        expect(request.headers['Authorization'], 'bearer returned-token');
        expect(request.url.queryParameters['businessType'], '1');
        return response(
          page([
            {'plantId': 'plant', 'plantTimeZone': 'Europe/Amsterdam'},
          ]),
        );
      }),
      now: () => solaxNow,
    );
    final token = await api.authenticate(
      SolaxCredentials(' client ', 'secret&value'),
    );
    expect(token.expiresAt, solaxNow.add(const Duration(seconds: 2591999)));
    expect((await api.plants(token)).single.timeZone, 'Europe/Amsterdam');
    expect(requests.length, 2);
  });
  test('discovery follows every page and retains distinct plants', () async {
    final pages = <String?>[];
    final api = SolaxApi(
      MockClient((r) async {
        final n = int.parse(r.url.queryParameters['pageNo']!);
        pages.add('$n');
        return response(
          page(
            [
              {'plantId': 'plant-$n', 'plantTimeZone': 'UTC'},
            ],
            current: n,
            pages: 2,
            total: 2,
          ),
        );
      }),
    );
    expect((await api.plants(testToken)).length, 2);
    expect(pages, ['1', '2']);
  });
  for (final invalid in [
    page([], pages: 20, total: 20),
    page([], current: 2),
    page([
      {'plantId': 'p'},
    ], total: 2),
    page([
      {'plantId': 'p'},
      {'plantId': 'p'},
    ]),
    {'records': [], 'total': '0'},
    page([]),
  ]) {
    test(
      'rejects incomplete, duplicate, empty or excessive inventory ${invalid.hashCode}',
      () async {
        final api = SolaxApi(MockClient((_) async => response(invalid)));
        await expectLater(api.plants(testToken), throwsA(isA<SolaxFailure>()));
      },
    );
  }
  test(
    'discovery rejects another plant and retains unsupported models',
    () async {
      var wrongPlant = true;
      final api = SolaxApi(
        MockClient((r) async {
          expect(r.url.queryParameters['deviceType'], '1');
          expect(r.url.queryParameters['plantId'], solaxPlant.id);
          return response(
            page([
              {
                'deviceSn': 'test-sn',
                'plantId': wrongPlant ? 'different' : solaxPlant.id,
                'deviceModel': 14,
              },
            ]),
          );
        }),
      );
      await expectLater(
        api.devices(testToken, solaxPlant),
        throwsA(isA<SolaxFailure>()),
      );
      wrongPlant = false;
      final devices = await api.devices(testToken, solaxPlant);
      expect(devices.single.supported, isFalse);
      await expectLater(
        api.reading(testToken, solaxPlant, devices.single),
        throwsA(isA<SolaxFailure>()),
      );
    },
  );
  test('requires a reading from the selected inverter', () async {
    final api = SolaxApi(
      MockClient(
        (r) async => response([
          {'deviceSn': 'other-device', 'acPower1': 10},
        ]),
      ),
    );
    await expectLater(
      api.reading(testToken, solaxPlant, solaxDevice),
      throwsA(isA<SolaxFailure>()),
    );
  });
  test('maps residential units and preserves explicit energy provenance', () {
    final r = SolaxReading.fromResponse({
      'acPower1': 0,
      'dailyACOutput': 0,
      'dailyYield': 4.2,
      'totalACOutput': 93,
      'acVoltage1': 230.2,
      'acCurrent1': 0,
      'acFrequency1': 49.99,
      'inverterTemperature': -2,
      'deviceStatus': 109,
      'mpptMap': {'MPPT1Power': 0, 'MPPT2Power': 62},
      'dataTime': '2026-09-29T12:00:00Z',
    }, 'Europe/Amsterdam');
    expect(r.powerWatts, 0);
    expect(r.dailyEnergyWh, 0);
    expect(r.lifetimeEnergyWh, 93000);
    expect(r.mpptPowerWatts(2), 62);
    expect(r.fields['inverterTemperature'], -2);
    expect(r.status, 'Idle');
    expect(r.fields['acPower2'], isNull);
    expect(r.provenance, '/openapi/v2/device/realtime_data');
  });
  test('missing/non-finite/string/negative energy never become zero', () {
    final r = SolaxReading.fromResponse({
      'acPower1': '42',
      'dailyACOutput': -1,
      'totalACOutput': double.infinity,
      'mpptMap': {'MPPT1Power': double.nan},
      'deviceStatus': 999,
    }, null);
    expect(r.powerWatts, isNull);
    expect(r.dailyEnergyWh, isNull);
    expect(r.lifetimeEnergyWh, isNull);
    expect(r.mpptPowerWatts(1), isNull);
    expect(r.mpptPowerWatts(2), isNull);
    expect(r.status, 'Unknown');
    expect(r.freshness(solaxNow), ReadingFreshness.unknown);
  });
  test('UTC measurement takes precedence and resolves ambiguous DST', () {
    final r = SolaxReading.fromResponse({
      'dataTime': '2026-10-25T01:30:00Z',
      'plantLocalTime': '2026-10-25 02:30:00',
    }, 'Europe/Amsterdam');
    expect(r.reportedAtUtc, DateTime.utc(2026, 10, 25, 1, 30));
    final ambiguous = SolaxReading.fromResponse({
      'plantLocalTime': '2026-10-25 02:30:00',
    }, 'Europe/Amsterdam');
    expect(ambiguous.reportedAtUtc, isNull);
    final gap = SolaxReading.fromResponse({
      'plantLocalTime': '2026-03-29 02:30:00',
    }, 'Europe/Amsterdam');
    expect(gap.reportedAtUtc, isNull);
  });
  test('unknown/future/invalid timestamps stay unknown; midnight hides daily energy', () {
    expect(
      solaxReading().freshness(solaxNow.add(const Duration(minutes: 30))),
      ReadingFreshness.stale,
    );
    expect(
      solaxReading().freshness(solaxNow.subtract(const Duration(minutes: 1))),
      ReadingFreshness.unknown,
    );
    expect(solaxReading().todayEnergyWh(DateTime.utc(2026, 9, 29, 22)), isNull);
    final r = SolaxReading.fromResponse({
      'dataTime': '2026-02-30T12:00:00Z',
    }, 'UTC');
    expect(r.reportedAtUtc, isNull);
    expect(
      solaxTimeZone(
        '(UTC+01:00)Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna',
      ),
      'Europe/Amsterdam',
    );
    expect(solaxTimeZone('GMT+1 unknown'), isNull);
  });
  test(
    'cache round trip preserves readings and excludes raw private fields',
    () {
      final r = SolaxReading.fromResponse({
        'acPower1': 12,
        'deviceSn': 'private-sn',
        'plantAddress': 'private-address',
        'dataTime': '2026-09-29 12:00:00',
        'secret': 'private-secret',
      }, 'UTC');
      final encoded = jsonEncode(r.toJson());
      expect(encoded, isNot(contains('private')));
      expect(
        SolaxReading.fromJson(jsonDecode(encoded)).reportedAtUtc,
        solaxNow,
      );
      expect(SolaxReading.fromJson(jsonDecode(encoded)).powerWatts, 12);
    },
  );
  for (final item in [
    (10402, SolaxFailureKind.revoked),
    (10403, SolaxFailureKind.denied),
    (10500, SolaxFailureKind.denied),
    (10405, SolaxFailureKind.rateLimit),
    (10406, SolaxFailureKind.rateLimit),
  ]) {
    test('handles provider code ${item.$1} without leaking response', () async {
      final api = SolaxApi(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': item.$1,
              'message': 'private-token / private-location',
            }),
            200,
          ),
        ),
      );
      try {
        await api.plants(testToken);
        fail('Expected failure');
      } on SolaxFailure catch (f) {
        expect(f.kind, item.$2);
        expect(f.message, isNot(contains('private')));
      }
    });
  }
  for (final code in [301, 302, 307, 401, 403, 429, 500]) {
    test('HTTP $code is redacted and never follows a redirect', () async {
      var calls = 0;
      final api = SolaxApi(
        MockClient((r) async {
          calls++;
          expect(r.followRedirects, isFalse);
          return http.Response(
            'private-token',
            code,
            headers: {'location': 'https://example.invalid/private-token'},
          );
        }),
      );
      await expectLater(
        api.plants(testToken),
        throwsA(
          isA<SolaxFailure>().having(
            (f) => f.message,
            'redacted',
            isNot(contains('private-token')),
          ),
        ),
      );
      expect(calls, 1);
    });
  }
  test(
    'timeout, malformed response and raw transport errors are redacted',
    () async {
      for (final client in [
        MockClient((_) async => http.Response('not-json private-token', 200)),
        MockClient((_) async => throw StateError('https://private-token')),
        MockClient((_) => Completer<http.Response>().future),
      ]) {
        await expectLater(
          SolaxApi(
            client,
            timeout: const Duration(milliseconds: 1),
          ).plants(testToken),
          throwsA(
            isA<SolaxFailure>().having(
              (f) => f.message,
              'redacted',
              isNot(contains('private-token')),
            ),
          ),
        );
      }
    },
  );
  test('invalid token response cannot be saved', () async {
    for (final expiry in [null, -1, 0, 299, '2591999', 999999999]) {
      final api = SolaxApi(
        MockClient(
          (_) async =>
              response({'access_token': 't', 'expires_in': expiry}, code: 0),
        ),
      );
      await expectLater(
        api.authenticate(SolaxCredentials('client', 'secret')),
        throwsA(isA<SolaxFailure>()),
      );
    }
  });
}

class StalledClient extends http.BaseClient {
  final aborted = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.Abortable).abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException();
  }
}
