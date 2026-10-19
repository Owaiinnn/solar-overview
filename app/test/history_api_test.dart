import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_overview/src/history.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax.dart';

import 'fakes.dart';
import 'solax_fakes.dart';

http.Response _edgeResponse(String endpoint, Object data) =>
    http.Response(jsonEncode({endpoint: data}), 200);
http.Response _solaxResponse(Object data) =>
    http.Response(jsonEncode({'code': 10000, 'result': data}), 200);
Map<String, Object?> _power(List<Object?> rows, {String unit = 'W'}) => {
  'unit': unit,
  'timeUnit': 'QUARTER_OF_AN_HOUR',
  'values': rows,
};
Map<String, Object?> _energy(List<Object?> rows) => {
  'unit': 'Wh',
  'timeUnit': 'DAY',
  'values': rows,
};

void main() {
  test(
    'site days have 23 and 25 hours; repeated wall timestamps stay gaps',
    () async {
      final spring = HistoryDay(DateTime.utc(2026, 3, 29), 'Europe/Amsterdam');
      final fall = HistoryDay(DateTime.utc(2026, 10, 25), 'Europe/Amsterdam');
      expect(spring.end.difference(spring.start).inHours, 23);
      expect(fall.end.difference(fall.start).inHours, 25);
      expect(spring.buckets(const Duration(minutes: 5)).length, 276);
      expect(fall.buckets(const Duration(minutes: 15)).length, 100);
      final api = SolarEdgeApi(
        MockClient(
          (request) async => request.url.path.endsWith('/power')
              ? _edgeResponse(
                  'power',
                  _power([
                    {'date': '2026-10-25 02:15:00', 'value': 100},
                    {'date': '2026-10-25 03:15:00', 'value': 200},
                  ]),
                )
              : _edgeResponse('energy', _energy([])),
        ),
      );
      final result = await api.history(
        SolarEdgeCredentials('123', fakeKey),
        fall,
      );
      expect(
        result.samples.where((sample) => sample.watts != null).single.watts,
        200,
      );
    },
  );

  test('SolarEdge uses local day and month requests, validates units, preserves gaps and zero', () async {
    final requests = <http.Request>[];
    final api = SolarEdgeApi(
      MockClient((request) async {
        requests.add(request);
        expect(request.followRedirects, isFalse);
        expect(request.url.host, 'monitoringapi.solaredge.com');
        if (request.url.path.endsWith('/power')) {
          expect(
            request.url.queryParameters['startTime'],
            '2026-09-28 00:00:00',
          );
          expect(request.url.queryParameters['endTime'], '2026-09-28 23:59:59');
          return _edgeResponse(
            'power',
            _power([
              {'date': '2026-09-28 12:00:00', 'value': 0},
              {'date': '2026-09-28 12:15:00', 'value': null},
              {'date': '2026-09-28 12:45:00', 'value': 800},
              {'date': '2026-09-28 13:00:00', 'value': -10},
              {'date': '2026-09-29 00:00:00', 'value': 900},
            ]),
          );
        }
        expect(request.url.queryParameters['startDate'], '2026-09-01');
        expect(request.url.queryParameters['endDate'], '2026-09-30');
        return _edgeResponse(
          'energy',
          _energy([
            {'date': '2026-09-28 00:00:00', 'value': 1500},
            {'date': '2026-09-27 00:00:00', 'value': null},
          ]),
        );
      }),
    );
    final result = await api.history(
      SolarEdgeCredentials('123', fakeKey),
      HistoryDay(DateTime.utc(2026, 9, 28), 'Europe/Amsterdam'),
    );
    expect(requests.length, 2);
    expect(result.energyWh, 1500);
    expect(result.samples.length, 96);
    expect(result.samples[48].watts, 0);
    expect(result.samples[49].watts, isNull);
    expect(result.samples[50].watts, isNull);
    expect(result.samples[51].watts, 800);
    expect(result.samples[52].watts, isNull);
    expect(ProductionHistory.fromJson(result.toJson()).samples.length, 96);
  });

  test('unsupported units and duplicate daily totals fail safely', () async {
    for (final invalidUnit in [true, false]) {
      final api = SolarEdgeApi(
        MockClient(
          (request) async => request.url.path.endsWith('/power')
              ? _edgeResponse(
                  'power',
                  _power([], unit: invalidUnit ? 'kW' : 'W'),
                )
              : _edgeResponse(
                  'energy',
                  _energy([
                    {'date': '2026-09-28 00:00:00', 'value': 1},
                    {'date': '2026-09-28 00:00:00', 'value': 2},
                  ]),
                ),
        ),
      );
      await expectLater(
        api.history(
          SolarEdgeCredentials('123', fakeKey),
          HistoryDay(DateTime.utc(2026, 9, 28), 'UTC'),
        ),
        throwsA(isA<SolarEdgeFailure>()),
      );
    }
  });

  test('SolaX chunks a 25-hour day into at most 12-hour UTC windows and uses plant AC statistics', () async {
    final day = HistoryDay(DateTime.utc(2026, 10, 25), 'Europe/Amsterdam');
    final starts = <int>[];
    final api = SolaxApi(
      MockClient((request) async {
        expect(request.followRedirects, isFalse);
        expect(request.headers['Authorization'], 'bearer synthetic-token');
        expect(request.url.host, 'openapi-eu.solaxcloud.com');
        if (request.method == 'POST') {
          expect(request.headers['Content-Type'], contains('application/json'));
          expect(jsonDecode(request.body), {
            'plantId': solaxPlant.id,
            'businessType': 1,
            'dateType': 2,
            'date': '2026-10',
          });
          return _solaxResponse({
            'plantId': solaxPlant.id,
            'date': '2026-10',
            'plantEnergyStatDataList': [
              {
                'date': '2026-10-25',
                'inverterACOutputEnergy': 1.5,
                'pvGeneration': 0,
                'dailyACOutput': 0,
                'totalACOutput': 999,
              },
              {'date': '2026-10-24', 'inverterACOutputEnergy': null},
            ],
          });
        }
        final query = request.url.queryParameters;
        final start = int.parse(query['startTime']!);
        final end = int.parse(query['endTime']!);
        expect(end - start, lessThan(const Duration(hours: 12).inMilliseconds));
        expect(query['timeInterval'], '5');
        starts.add(start);
        return _solaxResponse([
          {
            'deviceSn': solaxDevice.sn,
            'dataTime': DateTime.fromMillisecondsSinceEpoch(
              start,
              isUtc: true,
            ).toIso8601String(),
            'acPower1': 100,
            'dailyACOutput': 0,
            'mpptMap': {'mppt1Power': 40, 'MPPT2Power': 70},
          },
          {
            'deviceSn': solaxDevice.sn,
            'dataTime': DateTime.fromMillisecondsSinceEpoch(
              start + 600000,
              isUtc: true,
            ).toIso8601String(),
            'acPower1': 0,
          },
        ]);
      }),
      now: () => DateTime.utc(2026, 11),
    );
    final result = await api.history(
      SolaxToken('synthetic-token', DateTime.utc(2027)),
      solaxPlant,
      solaxDevice,
      day,
    );
    expect(starts, [
      day.start.millisecondsSinceEpoch,
      day.start.add(const Duration(hours: 12)).millisecondsSinceEpoch,
      day.start.add(const Duration(hours: 24)).millisecondsSinceEpoch,
    ]);
    expect(result.samples.length, 300);
    expect(result.samples[0].watts, 100);
    expect(result.samples[0].mppt1, 40);
    expect(result.samples[0].mppt2, 70);
    expect(result.samples[1].watts, isNull);
    expect(result.samples[2].watts, 0);
    expect(result.energyWh, 1500);
    expect(result.dailyWh['2026-10-24'], isNull);
  });

  test(
    'SolaX rejects dates beyond retention before sending requests',
    () async {
      var calls = 0;
      final api = SolaxApi(
        MockClient((_) async {
          calls++;
          return _solaxResponse([]);
        }),
        now: () => solaxNow,
      );
      await expectLater(
        api.history(
          SolaxToken('synthetic-token', solaxNow),
          solaxPlant,
          solaxDevice,
          HistoryDay(DateTime.utc(2024), 'Europe/Amsterdam'),
        ),
        throwsA(isA<SolaxFailure>()),
      );
      expect(calls, 0);
    },
  );

  test(
    'SolaX wrong-device responses fail and provider diagnostics stay redacted',
    () async {
      for (final status in [200, 429, 500]) {
        final api = SolaxApi(
          MockClient(
            (_) async => status == 200
                ? _solaxResponse([
                    {'deviceSn': 'wrong-device'},
                  ])
                : http.Response('private-token', status),
          ),
          now: () => solaxNow,
        );
        await expectLater(
          api.history(
            SolaxToken('synthetic-token', solaxNow),
            solaxPlant,
            solaxDevice,
            HistoryDay(DateTime.utc(2026, 9, 28), 'Europe/Amsterdam'),
          ),
          throwsA(
            isA<SolaxFailure>().having(
              (failure) => failure.message,
              'message',
              isNot(contains('private-token')),
            ),
          ),
        );
      }
    },
  );
}
