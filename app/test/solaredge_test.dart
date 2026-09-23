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
          expect(request.url.path, '/site/123/overview');
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

  for (final status in [302, 403, 429, 500]) {
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
}
