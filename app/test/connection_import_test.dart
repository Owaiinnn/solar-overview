import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/battery_controller.dart';
import 'package:solar_overview/src/battery_store.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/connection_import.dart';
import 'package:solar_overview/src/p1_controller.dart';
import 'package:solar_overview/src/p1_store.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:solar_overview/src/solax_controller.dart';
import 'package:solar_overview/src/solax_store.dart';

import 'battery_fakes.dart';
import 'fakes.dart';
import 'p1_fakes.dart';
import 'solax_fakes.dart';

Map<String, Object> setupJson() => {
  'version': 1,
  'solarEdge': {'siteId': '123', 'apiKey': fakeKey},
  'solax': {
    'clientId': 'synthetic-client',
    'clientSecret': 'synthetic-secret',
    'plantId': 'synthetic-plant',
    'serialNumber': 'synthetic-device',
    'model': 28,
    'timeZone': 'Europe/Amsterdam',
  },
  'p1': {'address': '192.168.1.10'},
  'battery': {'address': '192.168.1.11'},
};

void main() {
  test('validates all four providers and permits a subset', () {
    final setup = ConnectionImport.parse(jsonEncode(setupJson()));
    expect(setup.sources, ['SolarEdge', 'SolaX', 'P1 meter', 'Battery']);
    expect(setup.solax!.device.plantId, setup.solax!.plant.id);
    expect(setup.toString(), 'ConnectionImport(redacted)');
    final subset = ConnectionImport.parse(
      '{"version":1,"p1":{"address":"192.168.1.10"}}',
    );
    expect(subset.sources, ['P1 meter']);
  });
  test(
    'rejects malformed, unsupported and unsafe input without echoing secrets',
    () {
      for (final raw in [
        'synthetic-secret{',
        '[]',
        '{}',
        '{"version":2}',
        '{"version":1}',
        jsonEncode({...setupJson(), 'unexpected': 'synthetic-secret'}),
        jsonEncode({
          ...setupJson(),
          'solarEdge': {'siteId': 123, 'apiKey': fakeKey},
        }),
        jsonEncode({
          ...setupJson(),
          'solarEdge': {'siteId': '123', 'apiKey': 'synthetic-secret'},
        }),
        jsonEncode({
          ...setupJson(),
          'solax': {'clientId': 'synthetic-secret'},
        }),
        jsonEncode({
          ...setupJson(),
          'battery': {'address': 'https://synthetic-secret.example'},
        }),
        jsonEncode({
          ...setupJson(),
          'p1': {'address': '8.8.8.8'},
        }),
        jsonEncode({...setupJson(), 'p1': null}),
        'x' * (ConnectionImport.maxBytes + 1),
      ]) {
        try {
          ConnectionImport.parse(raw);
          fail('Invalid setup accepted');
        } on ConnectionImportFailure catch (failure) {
          expect(failure.message, isNot(contains('synthetic-secret')));
        }
      }
    },
  );
  test(
    'offline import persists all sources without requests and retains waits',
    () async {
      final now = solaxNow;
      final next = now.add(const Duration(hours: 1));
      final edgeStore = MemoryStore();
      final edgeSource = FakeSource()..reject = true;
      final cache = MemoryReadingStore()
        ..cache = ReadingCache(nextAttempt: next, rateLimited: true);
      final edge = ConnectionController(
        edgeStore,
        edgeSource,
        readingStore: cache,
        now: () => now,
      );
      final solaxStore = MemorySolaxStore()
        ..record = SolaxRecord(nextAttempt: next, rateLimited: true);
      final solaxSource = FakeSolaxSource();
      final solax = SolaxController(solaxStore, solaxSource, now: () => now);
      final p1Store = MemoryP1Store()
        ..saved = P1Record(nextAttempt: next, failures: 2);
      final p1Source = FakeP1Source()..reject = true;
      final p1 = P1Controller(p1Store, p1Source, now: () => now);
      final batteryStore = MemoryBatteryStore()
        ..saved = BatteryRecord(nextAttempt: next, failures: 2);
      final batterySource = FakeBatterySource()..reject = true;
      final battery = BatteryController(
        batteryStore,
        batterySource,
        now: () => now,
      );
      await Future.wait([
        edge.initialize(),
        solax.initialize(),
        p1.initialize(),
        battery.initialize(),
      ]);
      final result = await ConnectionImport.parse(jsonEncode(setupJson())).save(
        controller: edge,
        solaxController: solax,
        p1Controller: p1,
        batteryController: battery,
      );
      expect(result.values, everyElement(isTrue));
      expect([
        edgeSource.calls,
        solaxSource.authCalls,
        solaxSource.readingCalls,
        p1Source.calls,
        batterySource.calls,
      ], everyElement(0));
      expect(cache.cache.nextAttempt, next);
      expect(cache.cache.rateLimited, isTrue);
      expect(solaxStore.record.nextAttempt, next);
      expect(solaxStore.record.rateLimited, isTrue);
      expect(p1Store.saved.nextAttempt, next);
      expect(batteryStore.saved.nextAttempt, next);
      expect([
        edge.overview,
        solax.reading,
        p1.reading,
        battery.reading,
      ], everyElement(isNull));
      final reopenedEdge = ConnectionController(
        edgeStore,
        edgeSource,
        readingStore: cache,
        now: () => now,
      );
      final reopenedSolax = SolaxController(
        solaxStore,
        solaxSource,
        now: () => now,
      );
      final reopenedP1 = P1Controller(p1Store, p1Source, now: () => now);
      final reopenedBattery = BatteryController(
        batteryStore,
        batterySource,
        now: () => now,
      );
      await Future.wait([
        reopenedEdge.initialize(),
        reopenedSolax.initialize(),
        reopenedP1.initialize(),
        reopenedBattery.initialize(),
      ]);
      expect([
        reopenedEdge.connected,
        reopenedSolax.connected,
        reopenedP1.connected,
        reopenedBattery.connected,
      ], everyElement(isTrue));
      for (final c in [
        edge,
        solax,
        p1,
        battery,
        reopenedEdge,
        reopenedSolax,
        reopenedP1,
        reopenedBattery,
      ]) {
        c.dispose();
      }
    },
  );
  test('partial storage failure preserves successful sources and forbids replacement', () async {
    final edgeStore = MemoryStore()..failWrite = true;
    final edge = ConnectionController(edgeStore, FakeSource());
    final p1 = P1Controller(MemoryP1Store(), FakeP1Source());
    await edge.initialize();
    await p1.initialize();
    final setup = ConnectionImport.parse(
      jsonEncode({
        'version': 1,
        'solarEdge': setupJson()['solarEdge']!,
        'p1': setupJson()['p1']!,
      }),
    );
    expect(await setup.save(controller: edge, p1Controller: p1), {
      'SolarEdge': false,
      'P1 meter': true,
    });
    expect(edge.connected, isFalse);
    expect(p1.connected, isTrue);
    expect(
      () => setup.save(controller: edge, p1Controller: p1),
      throwsA(isA<ConnectionImportFailure>()),
    );
    expect(
      await p1.importConnection(
        ConnectionImport.parse('{"version":1,"p1":{"address":"192.168.1.12"}}')
            .p1!,
      ),
      isFalse,
    );
    expect(p1.address!.host, '192.168.1.10');
    edge.dispose();
    p1.dispose();
  });
  test('uninitialized and storage-blocked controllers cannot import', () async {
    final store = MemoryStore()..failRead = true;
    final edge = ConnectionController(store, FakeSource());
    final setup = ConnectionImport.parse(
      jsonEncode({'version': 1, 'solarEdge': setupJson()['solarEdge']!}),
    );
    expect(await setup.save(controller: edge), {'SolarEdge': false});
    await edge.initialize();
    expect(await setup.save(controller: edge), {'SolarEdge': false});
    expect(store.writes, 0);
    edge.dispose();
  });
}
