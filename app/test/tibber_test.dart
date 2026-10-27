import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart';
import 'package:solar_overview/src/tibber.dart';
import 'package:solar_overview/src/tibber_store.dart';

import 'tibber_fakes.dart';

void main() {
  test(
    'read-only discovery sends bearer token and one today/tomorrow query',
    () async {
      final api = TibberApi(
        MockClient((request) async {
          expect(request.url, TibberApi.endpoint);
          expect(request.method, 'POST');
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer synthetic-token');
          final body = jsonDecode(request.body) as Map;
          expect(body['variables']['resolution'], 'QUARTER_HOURLY');
          expect(body['query'], contains('today'));
          expect(body['query'], contains('tomorrow'));
          expect(body['query'], isNot(contains('mutation')));
          return http.Response(responseJson(), 200);
        }),
      );
      final home = (await api.read(
        'synthetic-token',
        PriceResolution.quarterHourly,
      )).single;
      expect(home.prices.map((p) => p.total), [-0.05, 0, 0.2]);
      expect(home.current(tibberNow)!.total, -0.05);
      expect(home.current(DateTime.utc(2026, 10, 25, 0, 15))!.total, 0);
      expect(home.current(DateTime.utc(2026, 10, 25, 0, 30)), isNull);
      expect(home.current(DateTime.utc(2026, 10, 25, 1, 5))!.total, 0.2);
      expect(home.expectedIntervals(tibberNow), 100);
    },
  );
  test(
    'selected-home refresh sends only selected home ID and supports hourly',
    () async {
      final api = TibberApi(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['variables']['homeId'], 'test-home');
          expect(body['variables']['resolution'], 'HOURLY');
          return http.Response(
            responseJson(
              home: homeJson(today: [priceJson('2026-10-25T02:00:00+02:00')]),
            ),
            200,
          );
        }),
      );
      final home = (await api.read(
        'synthetic',
        PriceResolution.hourly,
        homeId: 'test-home',
      )).single;
      expect(home.prices.single.end, DateTime.utc(2026, 10, 25, 1));
      expect(home.expectedIntervals(tibberNow), 25);
    },
  );
  for (final resolution in PriceResolution.values) {
    for (final date in [
      DateTime.utc(2026, 3, 29, 12),
      DateTime.utc(2026, 10, 25, 12),
    ]) {
      test('${resolution.name} retains all DST intervals on $date', () {
        final home = testHome(
          resolution: resolution,
          day: date,
          complete: true,
        );
        final expected = (date.month == 3 ? 23 : 25) * 60 ~/ resolution.minutes;
        expect(home.forDay(date).length, expected);
        expect(home.prices.last.end, home.day(date, 1).toUtc());
        final restored = TibberHome.fromJson(home.toJson());
        expect(restored.forDay(date).length, expected);
      });
    }
  }
  test(
    'rollover uses cached tomorrow and never old current outside coverage',
    () {
      final home = testHome(
        complete: true,
        day: DateTime.utc(2026, 10, 26, 12),
      );
      expect(home.forDay(tibberNow, 1).length, 96);
      expect(home.current(tibberNow), isNull);
      expect(home.current(DateTime.utc(2026, 10, 25, 23))!.total, -0.05);
      expect(home.current(DateTime.utc(2026, 10, 26, 23)), isNull);
    },
  );
  test('missing prices stay null rather than zero', () {
    final price = PriceInterval.fromJson(
      priceJson('2026-10-25T00:00:00Z', total: null),
      PriceResolution.quarterHourly,
    );
    expect(price.total, isNull);
    expect(price.energy, isNull);
  });
  for (final status in <String?>[null, 'ended', 'awaiting']) {
    test(
      'subscription $status does not expose a current purchase price',
      () async {
        final api = TibberApi(
          MockClient(
            (_) async => http.Response(
              responseJson(homes: [homeJson(status: status)]),
              200,
            ),
          ),
        );
        expect(
          (await api.read(
            'synthetic',
            PriceResolution.quarterHourly,
          )).single.current(tibberNow),
          isNull,
        );
      },
    );
  }
  for (final scenario in [
    'no homes',
    'duplicate',
    'bad timestamp',
    'no offset',
    'bad number',
    'mixed currency',
    'unknown zone',
    'null row',
    'wrong home',
  ]) {
    test('rejects $scenario with a safe error', () async {
      final home = homeJson();
      final rows = (home['currentSubscription']['priceInfo']['today'] as List);
      switch (scenario) {
        case 'duplicate':
          rows.add(rows.first);
        case 'bad timestamp':
          rows[0]['startsAt'] = 'private malformed timestamp';
        case 'no offset':
          rows[0]['startsAt'] = '2026-10-25T02:00:00';
        case 'bad number':
          rows[0]['total'] = 'private malformed number';
        case 'mixed currency':
          rows[0]['currency'] = 'USD';
        case 'unknown zone':
          home['timeZone'] = 'unknown';
        case 'null row':
          rows.add(null);
        default:
          break;
      }
      final api = TibberApi(
        MockClient(
          (_) async => http.Response(
            scenario == 'wrong home'
                ? responseJson(home: home)
                : responseJson(homes: scenario == 'no homes' ? [] : [home]),
            200,
          ),
        ),
      );
      await expectLater(
        api.read(
          'synthetic',
          PriceResolution.quarterHourly,
          homeId: scenario == 'wrong home' ? 'different' : null,
        ),
        throwsA(
          isA<TibberFailure>().having(
            (f) => f.message.contains('private'),
            'safe message',
            false,
          ),
        ),
      );
    });
  }
  for (final status in [401, 403, 429, 503, 302]) {
    test('HTTP $status redacts response and retains retry metadata', () async {
      final api = TibberApi(
        MockClient(
          (_) async => http.Response(
            'private response',
            status,
            headers: {'retry-after': '7200'},
          ),
        ),
      );
      await expectLater(
        api.read('synthetic', PriceResolution.quarterHourly),
        throwsA(
          isA<TibberFailure>()
              .having(
                (f) => f.authentication,
                'authentication',
                status == 401 || status == 403,
              )
              .having(
                (f) => f.retryAfter,
                'retry wait',
                status == 429 ? const Duration(hours: 2) : null,
              )
              .having((f) => f.message.contains('private'), 'safe', false),
        ),
      );
    });
  }
  for (final code in ['UNAUTHENTICATED', 'INTERNAL_SERVER_ERROR']) {
    test('HTTP 200 GraphQL $code rejects partial data', () async {
      final api = TibberApi(
        MockClient(
          (_) async => http.Response(
            responseJson(
              errors: [
                {
                  'message': 'private',
                  'extensions': {'code': code},
                },
              ],
            ),
            200,
          ),
        ),
      );
      await expectLater(
        api.read('synthetic', PriceResolution.quarterHourly),
        throwsA(
          isA<TibberFailure>().having(
            (f) => f.authentication,
            'authentication',
            code == 'UNAUTHENTICATED',
          ),
        ),
      );
    });
  }
  test('malformed JSON and network failures are sanitized', () async {
    for (final body in ['not json', '{}', '{"data":null}']) {
      final api = TibberApi(MockClient((_) async => http.Response(body, 200)));
      await expectLater(
        api.read('synthetic', PriceResolution.quarterHourly),
        throwsA(isA<TibberFailure>()),
      );
    }
    final api = TibberApi(
      MockClient((_) async => throw http.ClientException('private')),
    );
    await expectLater(
      api.read('synthetic', PriceResolution.quarterHourly),
      throwsA(
        isA<TibberFailure>().having(
          (f) => f.message.contains('private'),
          'safe',
          false,
        ),
      ),
    );
  });
  test(
    'HTTP-date Retry-After is honored and malformed values use one hour',
    () async {
      for (final header in [
        formatHttpDate(tibberNow.add(const Duration(hours: 4))),
        'invalid',
      ]) {
        final api = TibberApi(
          MockClient(
            (_) async =>
                http.Response('', 429, headers: {'retry-after': header}),
          ),
          now: () => tibberNow,
        );
        await expectLater(
          api.read('synthetic', PriceResolution.quarterHourly),
          throwsA(
            isA<TibberFailure>().having(
              (f) => f.retryAfter,
              'retry delay',
              Duration(hours: header == 'invalid' ? 1 : 4),
            ),
          ),
        );
      }
    },
  );
  test('request timeout produces a safe actionable failure', () async {
    final pending = Completer<http.Response>();
    final api = TibberApi(
      MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      api.read('synthetic', PriceResolution.quarterHourly),
      throwsA(
        isA<TibberFailure>().having(
          (f) => f.message,
          'message',
          contains('Check your connection'),
        ),
      ),
    );
    pending.complete(http.Response(responseJson(), 200));
  });
  test(
    'rejects normalized invalid dates and missing subscription structure',
    () async {
      expect(
        () => PriceInterval.fromJson(
          priceJson('2026-02-30T00:00:00Z'),
          PriceResolution.quarterHourly,
        ),
        throwsFormatException,
      );
      final home = homeJson()..remove('currentSubscription');
      final api = TibberApi(
        MockClient(
          (_) async => http.Response(responseJson(homes: [home]), 200),
        ),
      );
      await expectLater(
        api.read('synthetic', PriceResolution.quarterHourly),
        throwsA(isA<TibberFailure>()),
      );
    },
  );
  test('secure record validates paired credentials, identity, and version', () {
    final record = TibberRecord(
      token: 'synthetic',
      home: testHome(),
      receivedAt: tibberNow,
      nextAttempt: tibberNow.add(const Duration(minutes: 15)),
    );
    expect(TibberRecord.fromJson(record.toJson()).home!.id, 'test-home');
    expect(record.toString(), isNot(contains('synthetic')));
    for (final change in [
      {'version': 2},
      {'token': null},
      {'receivedAt': null},
      {'failures': -1},
      {'failures': 5},
    ]) {
      expect(
        () => TibberRecord.fromJson({...record.toJson(), ...change}),
        throwsFormatException,
      );
    }
  });
}
