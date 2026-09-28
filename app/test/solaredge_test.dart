import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  test(
    'uses only the SolarEdge HTTPS endpoint and refuses redirects',
    () async {
      final api = SolarEdgeApi(
        MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'monitoringapi.solaredge.com');
          expect(
            request.url.path,
            anyOf('/site/123/overview', '/site/123/details'),
          );
          if (request.url.path.endsWith('/details')) {
            return http.Response(
              '{"details":{"location":{"timeZone":"Europe/Amsterdam"}}}',
              200,
            );
          }
          expect(request.url.queryParameters['api_key'], fakeKey);
          expect(request.followRedirects, isFalse);
          return http.Response(
            '{"overview":{"currentPower":{"power":0},"lastDayData":{"energy":152}}}',
            200,
          );
        }),
      );
      final reading = await api.overview(SolarEdgeCredentials('123', fakeKey));
      expect(reading.powerWatts, 0);
      expect(reading.energyWh, 152);
      expect(reading.reportedAt, isNull);
    },
  );

  for (final status in [302, 401, 403, 404, 429, 500, 503]) {
    test(
      'HTTP $status responses cannot expose credentials in errors',
      () async {
        final api = SolarEdgeApi(
          MockClient((_) async => http.Response(fakeKey, status)),
        );
        try {
          await api.overview(SolarEdgeCredentials('123', fakeKey));
          fail('Expected a safe error.');
        } on SolarEdgeFailure catch (error) {
          expect(error.toString(), isNot(contains(fakeKey)));
          expect(error.rateLimited, status == 429);
        }
      },
    );
  }

  test('network exception URLs are redacted', () async {
    final api = SolarEdgeApi(
      MockClient(
        (_) async => throw http.ClientException('URL contains $fakeKey'),
      ),
    );
    await expectLater(
      api.overview(SolarEdgeCredentials('123', fakeKey)),
      throwsA(
        isA<SolarEdgeFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains(fakeKey)),
        ),
      ),
    );
  });

  test('unexpected success responses do not validate a connection', () async {
    final api = SolarEdgeApi(
      MockClient((_) async => http.Response('{"unexpected":"$fakeKey"}', 200)),
    );
    await expectLater(
      api.overview(SolarEdgeCredentials('123', fakeKey)),
      throwsA(isA<SolarEdgeFailure>()),
    );
  });

  test('missing and invalid readings remain unavailable, not zero', () {
    final value = SolarOverview.fromJson({
      'currentPower': {'power': -1},
      'lastDayData': {'energy': '42'},
      'lastUpdateTime': fakeKey,
    });
    expect(value.powerWatts, isNull);
    expect(value.energyWh, isNull);
    expect(value.reportedAt, isNull);
    expect(
      SolarEdgeCredentials('123', fakeKey).toString(),
      isNot(contains(fakeKey)),
    );
  });

  test(
    'details failure does not expose provider fields or validate credentials',
    () async {
      var calls = 0;
      final api = SolarEdgeApi(
        MockClient((request) async {
          calls++;
          if (request.url.path.endsWith('/overview')) {
            return http.Response(
              '{"overview":{"currentPower":{"power":42}}}',
              200,
            );
          }
          return http.Response(fakeKey, 403);
        }),
      );
      await expectLater(
        api.overview(SolarEdgeCredentials('123', fakeKey)),
        throwsA(
          isA<SolarEdgeFailure>().having(
            (e) => e.message,
            'message',
            contains('rejected'),
          ),
        ),
      );
      expect(calls, 2);
    },
  );

  for (final body in [
    'not json',
    '{"overview":null}',
    '[]',
    '{"overview":"$fakeKey"}',
  ]) {
    test(
      'malformed success is safely rejected: ${body.length} characters',
      () async {
        final api = SolarEdgeApi(
          MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          api.overview(SolarEdgeCredentials('123', fakeKey)),
          throwsA(
            isA<SolarEdgeFailure>().having(
              (e) => e.message,
              'message',
              isNot(contains(fakeKey)),
            ),
          ),
        );
      },
    );
  }

  test('timeout exception details are redacted', () async {
    final api = SolarEdgeApi(
      MockClient((_) async => throw TimeoutException(fakeKey)),
    );
    await expectLater(
      api.overview(SolarEdgeCredentials('123', fakeKey)),
      throwsA(
        isA<SolarEdgeFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains(fakeKey)),
        ),
      ),
    );
  });
}
