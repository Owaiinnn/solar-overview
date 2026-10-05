import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/p1_controller.dart';

import 'p1_fakes.dart';

void main() {
  late MemoryP1Store store;
  late FakeP1Source source;
  late P1Controller c;
  late DateTime now;
  setUp(() async {
    now = p1Now;
    store = MemoryP1Store();
    source = FakeP1Source(now: () => now);
    c = P1Controller(store, source, now: () => now);
    await c.initialize();
  });
  tearDown(() => c.dispose());
  test(
    'setup and restart preserve connection, source time and request wait',
    () async {
      expect(await c.connect('192.168.1.2'), isTrue);
      expect(c.current, isTrue);
      await c.refresh();
      expect(source.calls, 1);
      final restarted = P1Controller(store, source, now: () => now);
      await restarted.initialize();
      expect(restarted.connected, isTrue);
      expect(restarted.reading!.measuredAt, p1Now);
      expect(restarted.current, isFalse);
      expect(restarted.wait.inSeconds, 30);
      expect(source.calls, 1);
      restarted.dispose();
    },
  );
  test(
    'repeated timestamp cannot extend measured freshness through new receipts',
    () async {
      source.value = p1Reading();
      await c.connect('192.168.1.2');
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 30));
        await c.refresh();
      }
      expect(c.receivedAt, now);
      expect(c.reading!.measuredAt, p1Now);
      expect(c.current, isFalse);
      source.value = null;
      now = now.add(c.wait);
      await c.refresh();
      expect(c.current, isTrue);
    },
  );
  test(
    'missing net power remains unavailable even on a recent response',
    () async {
      source.value = P1Reading.parse(
        p1Telegram().replaceFirst('1-0:2.7.0(00.520*kW)\n', ''),
      );
      await c.connect('192.168.1.2');
      expect(c.reading!.netWatts, isNull);
      expect(c.reading!.direction, GridDirection.unavailable);
    },
  );
  test('old or changed same-time readings and a future clock retain the good cache', () async {
    await c.connect('192.168.1.2');
    for (final reading in [
      p1Reading(at: p1Now.subtract(const Duration(seconds: 1))),
      p1Reading(importKw: '1.000'),
      p1Reading(at: p1Now.add(const Duration(days: 1))),
    ]) {
      now = now.add(c.wait);
      source.value = reading;
      await c.refresh();
      expect(c.current, isFalse);
      expect(c.reading!.netWatts, -520);
      expect(c.reading!.measuredAt, p1Now);
      expect(c.error, isNotNull);
    }
  });
  test(
    'meter replacement requires explicit confirmation, not address reuse',
    () async {
      await c.connect('192.168.1.2');
      now = now.add(c.wait);
      source.value = P1Reading.parse(p1Telegram(at: now, id: '4E4557'));
      await c.refresh();
      expect(c.reading!.meterId, '544553542D4D45544552');
      expect(c.error, contains('identity changed'));
      expect(c.current, isFalse);
      now = now.add(c.wait);
      expect(await c.connect('192.168.1.2'), isTrue);
      expect(c.reading!.meterId, '4E4557');
    },
  );
  test('counter reset is flagged persistently without hiding independent grid power', () async {
    await c.connect('192.168.1.2');
    now = now.add(c.wait);
    source.value = P1Reading.parse(p1Telegram(at: now, counter: '000000.001'));
    await c.refresh();
    expect(c.counterReset, isTrue);
    expect(c.reading!.fields['1-0:1.8.1'], 1);
    expect(c.current, isTrue);
    expect(c.reading!.suitableForHouseholdBalance, isFalse);
    final restarted = P1Controller(store, source, now: () => now);
    await restarted.initialize();
    expect(restarted.counterReset, isTrue);
    restarted.dispose();
    now = now.add(c.wait);
    source.value = P1Reading.parse(p1Telegram(at: now, counter: '000000.002'));
    await c.refresh();
    expect(c.counterReset, isTrue);
  });
  test(
    'off-network backoff persists, caps at five minutes and recovers',
    () async {
      await c.connect('192.168.1.2');
      source.reject = true;
      for (final wait in [60, 120, 240, 300, 300]) {
        now = now.add(c.wait);
        await c.refresh();
        expect(c.wait.inSeconds, wait);
        expect(c.current, isFalse);
        expect(c.reading!.netWatts, -520);
      }
      final restarted = P1Controller(store, source, now: () => now);
      await restarted.initialize();
      expect(restarted.wait.inSeconds, 300);
      restarted.dispose();
      now = now.add(c.wait);
      source.reject = false;
      await c.refresh();
      expect(c.current, isTrue);
      expect(c.wait.inSeconds, 30);
      expect(store.saved.failures, 0);
    },
  );
  test(
    'failed address replacement preserves old address and measurements',
    () async {
      await c.connect('192.168.1.2');
      now = now.add(c.wait);
      source.reject = true;
      expect(await c.connect('192.168.1.3'), isFalse);
      expect(c.address!.host, '192.168.1.2');
      expect(c.reading!.netWatts, -520);
      expect(c.wait.inSeconds, 60);
    },
  );
  test('background and connection editing pause automatic requests', () async {
    await c.connect('192.168.1.2');
    now = now.add(c.wait);
    c.editingConnection = true;
    c.tick();
    expect(source.calls, 1);
    c.editingConnection = false;
    c.setForeground(false);
    c.tick();
    await c.refresh();
    expect(source.calls, 1);
    expect(c.current, isFalse);
    c.setForeground(true);
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 2);
    expect(c.current, isTrue);
  });
  test(
    'pending request cannot race another fetch, remove or initialization',
    () async {
      source.pending = Completer<P1Reading>();
      final request = c.connect('192.168.1.2');
      await Future<void>.delayed(Duration.zero);
      expect(await c.connect('192.168.1.3'), isFalse);
      expect(await c.disconnect(), isFalse);
      await c.initialize();
      c.tick();
      expect(source.calls, 1);
      c.setForeground(false);
      source.pending!.complete(p1Reading());
      expect(await request, isTrue);
      expect(c.current, isFalse);
    },
  );
  test('storage failure prevents network and final-save failure cannot replace good data', () async {
    await c.connect('192.168.1.2');
    now = now.add(c.wait);
    store.failWrite = true;
    expect(await c.connect('192.168.1.3'), isFalse);
    expect(source.calls, 1);
    expect(c.storageUnavailable, isTrue);
    expect(c.error, isNot(contains('private')));
    store.failWrite = false;
    await c.initialize();
    now = now.add(c.wait);
    source.pending = Completer<P1Reading>();
    final request = c.connect('192.168.1.3');
    await Future<void>.delayed(Duration.zero);
    store.failWrite = true;
    source.pending!.complete(p1Reading(at: now, importKw: '2.000'));
    expect(await request, isFalse);
    expect(c.address!.host, '192.168.1.2');
    expect(c.reading!.netWatts, -520);
  });
  test(
    'removal clears measurements and identity but preserves backoff',
    () async {
      await c.connect('192.168.1.2');
      expect(await c.disconnect(), isTrue);
      expect(c.connected, isFalse);
      expect(store.saved.reading, isNull);
      expect(store.saved.receivedAt, isNull);
      expect(c.canRequest, isFalse);
      now = now.add(c.wait);
      c.tick();
      expect(source.calls, 1);
    },
  );
  test('corrupt storage blocks polling until recovered', () async {
    await c.connect('192.168.1.2');
    store.failRead = true;
    await c.initialize();
    now = now.add(const Duration(hours: 1));
    c.tick();
    expect(c.storageUnavailable, isTrue);
    expect(c.current, isFalse);
    expect(source.calls, 1);
  });
  test('disposal during I/O does not commit a new connection', () async {
    final other = P1Controller(store, source, now: () => now);
    await other.initialize();
    source.pending = Completer<P1Reading>();
    final request = other.connect('192.168.1.2');
    await Future<void>.delayed(Duration.zero);
    other.dispose();
    source.pending!.complete(p1Reading());
    expect(await request, isFalse);
    expect(store.saved.address, isNull);
  });
}
