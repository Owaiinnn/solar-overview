import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/battery_controller.dart';
import 'package:solar_overview/src/battery_store.dart';

import 'battery_fakes.dart';

void main() {
  late MemoryBatteryStore store;
  late FakeBatterySource source;
  late BatteryController c;
  late DateTime now;
  setUp(() async {
    store = MemoryBatteryStore();
    source = FakeBatterySource();
    now = batteryNow;
    c = BatteryController(store, source, now: () => now);
    await c.initialize();
  });
  tearDown(() => c.dispose());
  test(
    'successful setup, restart, receipt expiry and independent wait',
    () async {
      expect(await c.connect('192.168.1.2'), isTrue);
      expect(c.recentlyReceived, isTrue);
      expect(c.reading!.percent, 60);
      await c.refresh();
      expect(source.calls, 1);
      final restarted = BatteryController(store, source, now: () => now);
      await restarted.initialize();
      expect(restarted.connected, isTrue);
      expect(restarted.recentlyReceived, isFalse);
      expect(restarted.wait.inSeconds, 30);
      expect(source.calls, 1);
      restarted.dispose();
      now = now.add(const Duration(seconds: 90));
      expect(c.recentlyReceived, isFalse);
      await c.refresh();
      expect(c.recentlyReceived, isTrue);
    },
  );
  test('failed replacement retains good address and cached reading', () async {
    await c.connect('192.168.1.2');
    now = now.add(const Duration(seconds: 30));
    source.reject = true;
    expect(await c.connect('192.168.1.3'), isFalse);
    expect(store.saved.address!.host, '192.168.1.2');
    expect(c.reading!.packWatts, -200);
    expect(c.wait.inSeconds, 60);
    expect(c.error, 'Battery unreachable.');
  });
  test('offline backoff persists, caps at 5m, and recovery resets', () async {
    await c.connect('192.168.1.2');
    source.reject = true;
    for (final seconds in [60, 120, 240, 300, 300]) {
      now = now.add(c.wait);
      await c.refresh();
      expect(c.wait.inSeconds, seconds);
      expect(c.recentlyReceived, isFalse);
      expect(c.reading!.percent, 60);
    }
    source.reject = false;
    now = now.add(c.wait);
    await c.refresh();
    expect(c.recentlyReceived, isTrue);
    expect(store.saved.failures, 0);
    expect(c.wait.inSeconds, 30);
  });
  test(
    'background stops requests and a pending response stays saved',
    () async {
      await c.connect('192.168.1.2');
      now = now.add(c.wait);
      source.pending = Completer<BatteryReading>();
      final request = c.refresh();
      await Future<void>.delayed(Duration.zero);
      c.setForeground(false);
      source.pending!.complete(batteryReading());
      await request;
      expect(c.recentlyReceived, isFalse);
      now = now.add(const Duration(minutes: 10));
      c.tick();
      await c.refresh();
      expect(source.calls, 2);
      source.pending = null;
      c.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      expect(source.calls, 3);
      expect(c.recentlyReceived, isTrue);
    },
  );
  test('concurrent refresh and removal cannot race in-flight fetch', () async {
    source.pending = Completer<BatteryReading>();
    final request = c.connect('192.168.1.2');
    await Future<void>.delayed(Duration.zero);
    expect(await c.connect('192.168.1.3'), isFalse);
    expect(await c.disconnect(), isFalse);
    c.tick();
    expect(source.calls, 1);
    source.pending!.complete(batteryReading());
    expect(await request, isTrue);
  });
  test(
    'storage failure blocks network and preserves saved connection',
    () async {
      await c.connect('192.168.1.2');
      now = now.add(c.wait);
      store.failWrite = true;
      expect(await c.connect('192.168.1.3'), isFalse);
      expect(source.calls, 1);
      expect(c.storageUnavailable, isTrue);
      expect(c.error, isNot(contains('private')));
      expect(await c.disconnect(), isFalse);
      expect(c.connected, isTrue);
      store.failWrite = false;
      await c.initialize();
      expect(c.storageUnavailable, isFalse);
      expect(c.address!.host, '192.168.1.2');
    },
  );
  test('failed final save cannot replace connection in memory', () async {
    await c.connect('192.168.1.2');
    now = now.add(c.wait);
    source.pending = Completer<BatteryReading>();
    final request = c.connect('192.168.1.3');
    await Future<void>.delayed(Duration.zero);
    store.failWrite = true;
    source.pending!.complete(batteryReading(power: 700, state: 1002));
    expect(await request, isFalse);
    expect(c.address!.host, '192.168.1.2');
    expect(c.reading!.packWatts, -200);
    expect(c.storageUnavailable, isTrue);
  });
  test('removal clears address/readings but retains local backoff', () async {
    await c.connect('192.168.1.2');
    expect(await c.disconnect(), isTrue);
    expect(store.saved.address, isNull);
    expect(store.saved.reading, isNull);
    expect(store.saved.receivedAt, isNull);
    expect(c.canRequest, isFalse);
    now = now.add(const Duration(seconds: 30));
    expect(c.canRequest, isTrue);
  });
  test(
    'future receipt never appears recent and bad storage cannot poll',
    () async {
      await c.connect('192.168.1.2');
      now = now.subtract(const Duration(minutes: 1));
      expect(c.recentlyReceived, isFalse);
      store.failRead = true;
      await c.initialize();
      now = now.add(const Duration(hours: 1));
      c.tick();
      expect(c.storageUnavailable, isTrue);
      expect(source.calls, 1);
    },
  );
  test('disposal during request suppresses notifications safely', () async {
    final other = BatteryController(
      MemoryBatteryStore(),
      source,
      now: () => now,
    );
    await other.initialize();
    source.pending = Completer<BatteryReading>();
    final request = other.connect('192.168.1.2');
    await Future<void>.delayed(Duration.zero);
    other.dispose();
    source.pending!.complete(batteryReading());
    await request;
  });
  test('record with no battery keeps polling disabled', () async {
    store.saved = const BatteryRecord();
    await c.initialize();
    c.tick();
    expect(source.calls, 0);
  });
}
