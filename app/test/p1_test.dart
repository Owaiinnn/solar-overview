import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/p1_store.dart';

import 'p1_fakes.dart';

void main() {
  test(
    'raw units, precise tariff counters, phases and identity round trip',
    () {
      final r = p1Reading();
      expect(r.importWatts, 0);
      expect(r.exportWatts, 520);
      expect(r.netWatts, -520);
      expect(r.direction, GridDirection.exporting);
      expect(r.measuredAt, p1Now);
      expect(r.fields['1-0:1.8.1'], 1234567);
      expect(r.fields['1-0:32.7.0'], 230.1);
      expect(r.fields['1-0:52.7.0'], isNull);
      expect(r.fields.keys, isNot(contains('0-1:24.2.1')));
      expect(r.suitableForHouseholdBalance, isFalse);
      final restored = P1Reading.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(restored.fields, r.fields);
      expect(restored.meterId, r.meterId);
      expect(r.toString(), isNot(contains(r.meterId)));
    },
  );
  test('missing power never becomes zero; import/export net is signed', () {
    final r = P1Reading.parse(
      p1Telegram().replaceAll('1-0:1.7.0(00.000*kW)\n', ''),
    );
    expect(r.importWatts, isNull);
    expect(r.netWatts, isNull);
    expect(r.direction, GridDirection.unavailable);
    expect(p1Reading(importKw: '1.750', exportKw: '0.250').netWatts, 1500);
    expect(
      p1Reading(importKw: '0', exportKw: '0').direction,
      GridDirection.balanced,
    );
  });
  test(
    'DST suffix disambiguates autumn and rejects spring gaps and overflow',
    () {
      expect(
        p1TimestampUtc('261025023000S'),
        DateTime.utc(2026, 10, 25, 0, 30),
      );
      expect(
        p1TimestampUtc('261025023000W'),
        DateTime.utc(2026, 10, 25, 1, 30),
      );
      expect(p1TimestampUtc('260105120000W'), DateTime.utc(2026, 1, 5, 11));
      for (final stamp in [
        '260329023000S',
        '260329023000W',
        '260230120000W',
        '261005250000S',
        '261005120000W',
        '261005120000',
        '261005120060S',
      ]) {
        expect(
          () => p1TimestampUtc(stamp),
          throwsA(isA<P1Failure>()),
          reason: stamp,
        );
      }
    },
  );
  test(
    'rejects malformed units, duplicates, identity and incomplete telegrams',
    () {
      for (final text in [
        p1Telegram().replaceFirst('00.520*kW', '-00.520*kW'),
        p1Telegram().replaceFirst('00.520*kW', '520*W'),
        p1Telegram().replaceFirst('00.520*kW', 'NaN*kW'),
        p1Telegram().replaceFirst('00.520*kW', '0.5201*kW'),
        p1Telegram().replaceFirst('!\n', ''),
        p1Telegram().replaceFirst('!\n', '1-0:2.7.0(00.520*kW)\n!\n'),
        p1Telegram().replaceFirst('0-0:1.0.0(261005120000S)\n', ''),
        p1Telegram(id: 'not-hex'),
        '<html>router login</html>',
        jsonEncode({'target_power': -520, 'total_act_ret_power': 520}),
      ]) {
        expect(() => P1Reading.parse(text), throwsA(isA<P1Failure>()));
      }
    },
  );
  test('CRC is checked for a complete framed telegram', () {
    const frame =
        '/TEST\r\n0-0:1.0.0(261005120000S)\r\n0-0:96.1.1(54455354)\r\n1-0:1.7.0(00.100*kW)\r\n1-0:2.7.0(00.000*kW)\r\n!C31D';
    expect(P1Reading.parse(frame).netWatts, 100);
    expect(
      () => P1Reading.parse(frame.replaceFirst('00.100', '00.200')),
      throwsA(isA<P1Failure>()),
    );
    expect(
      () => P1Reading.parse(frame.replaceAll('\r\n', '\n')),
      throwsA(isA<P1Failure>()),
    );
  });
  test('private literal address only, without paths, ports or credentials', () {
    for (final host in ['10.0.2.15', '172.16.0.1', '192.168.1.2']) {
      expect(P1Address(host).readingUri.path, '/rpc/P1.GetData');
      expect(P1Address(host).readingUri.port, 8080);
    }
    for (final host in [
      '',
      '127.0.0.1',
      '8.8.8.8',
      '172.15.0.1',
      '192.168.01.2',
      '192.168.1.256',
      'reader.local',
      'http://192.168.1.2',
      '192.168.1.2:8080',
      'user@192.168.1.2',
    ]) {
      expect(() => P1Address(host), throwsA(isA<P1Failure>()));
    }
    expect(P1Address('192.168.1.2').toString(), isNot(contains('192.168')));
  });
  test('API uses one read-only raw GET without redirects', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.url.path, '/rpc/P1.GetData');
      expect(request.url.query, isEmpty);
      expect(request.followRedirects, isFalse);
      return http.Response(p1Telegram(), 200);
    });
    addTearDown(client.close);
    expect((await P1Api(client).read(P1Address('192.168.1.2'))).netWatts, -520);
    expect(calls, 1);
  });
  for (final code in [302, 401, 403, 404, 500]) {
    test('HTTP $code fails without leaking body or local address', () async {
      final client = MockClient(
        (_) async => http.Response('private response 192.168.1.2', code),
      );
      addTearDown(client.close);
      await expectLater(
        P1Api(client).read(P1Address('192.168.1.2')),
        throwsA(
          isA<P1Failure>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('192.168')),
          ),
        ),
      );
    });
  }
  test('oversized responses and timeouts fail safely', () async {
    final large = MockClient((_) async => http.Response('x' * 65537, 200));
    final slow = MockClient((_) => Completer<http.Response>().future);
    addTearDown(large.close);
    addTearDown(slow.close);
    await expectLater(
      P1Api(large).read(P1Address('192.168.1.2')),
      throwsA(isA<P1Failure>()),
    );
    await expectLater(
      P1Api(
        slow,
        timeout: const Duration(milliseconds: 5),
      ).read(P1Address('192.168.1.2')),
      throwsA(isA<P1Failure>()),
    );
  });
  test('cache validation rejects incompatible or corrupt records', () {
    final r = P1Record(
      address: P1Address('192.168.1.2'),
      reading: p1Reading(),
      receivedAt: p1Now,
      nextAttempt: p1Now.add(const Duration(seconds: 30)),
    );
    final restored = P1Record.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(restored.reading!.netWatts, -520);
    expect(restored.nextAttempt, r.nextAttempt);
    for (final patch in [
      {'version': 2},
      {'receivedAt': null},
      {'address': null},
      {'failures': 9},
      {'receivedAt': 'invalid'},
      {'receivedAt': '2026-02-30T00:00:00.000Z'},
    ]) {
      expect(
        () => P1Record.fromJson({...r.toJson(), ...patch}),
        throwsA(anything),
      );
    }
    final bad = p1Reading().toJson();
    bad['fields'] = {'1-0:1.7.0': -1};
    expect(() => P1Reading.fromJson(bad), throwsFormatException);
  });
}
