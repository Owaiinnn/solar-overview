import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/tibber.dart';
import 'package:solar_overview/src/tibber_controller.dart';
import 'package:solar_overview/src/tibber_store.dart';

import 'tibber_fakes.dart';

void main() {
  late MemoryTibberStore store;
  late FakeTibberSource source;
  late TibberController controller;
  late DateTime now;
  setUp(() async {
    store = MemoryTibberStore();
    source = FakeTibberSource();
    now = tibberNow;
    controller = TibberController(store, source, now: () => now);
    await controller.initialize();
  });
  tearDown(() => controller.dispose());
  Future<void> connect() async {
    expect(
      await controller.discover(
        'synthetic-token',
        PriceResolution.quarterHourly,
      ),
      isTrue,
    );
    expect(await controller.saveHome('test-home'), isTrue);
  }

  test(
    'discovery is a draft and saving is atomic without another request',
    () async {
      await controller.discover(
        'synthetic-token',
        PriceResolution.quarterHourly,
      );
      expect(controller.connected, isFalse);
      expect(store.record.token, isNull);
      expect(controller.candidates.length, 1);
      expect(await controller.saveHome('wrong'), isFalse);
      expect(await controller.saveHome('test-home'), isTrue);
      expect(source.calls, 1);
      expect(controller.connected, isTrue);
      expect(controller.candidates, isEmpty);
      expect(controller.wait, const Duration(minutes: 15));
    },
  );
  test('clock advances current interval without requests', () async {
    await connect();
    expect(controller.current!.total, -0.05);
    now = DateTime.utc(2026, 10, 25, 0, 15);
    controller.tick();
    expect(controller.current!.total, 0);
    now = DateTime.utc(2026, 10, 25, 1);
    controller.tick();
    expect(controller.current, isNull);
    expect(source.calls, 1);
  });
  test(
    'display tick lands on interval boundary without a network fetch',
    () async {
      await connect();
      now = DateTime.utc(2026, 10, 25, 0, 14, 58);
      expect(controller.nextTick, const Duration(seconds: 2));
      now = now.add(controller.nextTick);
      controller.tick();
      expect(controller.current!.total, 0);
      expect(source.calls, 1);
    },
  );
  test('restart restores schedule and manual and automatic waits', () async {
    await connect();
    final next = store.record.nextRefresh;
    final restored = TibberController(store, source, now: () => now);
    addTearDown(restored.dispose);
    await restored.initialize();
    restored.tick();
    expect(restored.saved, isTrue);
    expect(restored.current!.total, -0.05);
    expect(restored.wait, const Duration(minutes: 15));
    expect(store.record.nextRefresh, next);
    expect(source.calls, 1);
  });
  test(
    'failed replacement and cancellation retain original connection',
    () async {
      await connect();
      now = now.add(const Duration(minutes: 16));
      source.failure = const TibberFailure('Rejected', authentication: true);
      expect(
        await controller.discover('bad-token', PriceResolution.hourly),
        isFalse,
      );
      expect(store.record.token, 'synthetic-token');
      expect(controller.authorizationRequired, isFalse);
      expect(controller.home!.resolution, PriceResolution.quarterHourly);
      controller.finishEditing();
      expect(controller.editing, isFalse);
      expect(controller.wait, const Duration(minutes: 15));
    },
  );
  test('successful replacement separates homes and snapshots', () async {
    await connect();
    now = now.add(const Duration(minutes: 16));
    source.homes = [testHome(id: 'second-home')];
    await controller.discover(
      'replacement-token',
      PriceResolution.quarterHourly,
    );
    expect(controller.home!.id, 'test-home');
    await controller.saveHome('second-home');
    expect(controller.home!.id, 'second-home');
    expect(store.record.token, 'replacement-token');
    expect(controller.candidates, isEmpty);
  });
  test(
    'write failure before network prevents request and keeps saved data',
    () async {
      await connect();
      now = now.add(const Duration(minutes: 16));
      store.failWrite = true;
      await controller.refresh();
      expect(source.calls, 1);
      expect(controller.storageUnavailable, isTrue);
      expect(controller.home!.id, 'test-home');
      expect(controller.busy, isFalse);
    },
  );
  test('save failure never replaces working token or home', () async {
    await connect();
    now = now.add(const Duration(minutes: 16));
    source.homes = [testHome(id: 'replacement')];
    await controller.discover(
      'replacement-token',
      PriceResolution.quarterHourly,
    );
    store.failWrite = true;
    expect(await controller.saveHome('replacement'), isFalse);
    expect(store.record.token, 'synthetic-token');
    expect(controller.home!.id, 'test-home');
    expect(controller.busy, isFalse);
  });
  test('corrupt storage blocks network until retry succeeds', () async {
    store.failRead = true;
    await controller.initialize();
    expect(controller.storageUnavailable, isTrue);
    expect(
      await controller.discover('synthetic', PriceResolution.quarterHourly),
      isFalse,
    );
    expect(source.calls, 0);
    store.failRead = false;
    await controller.initialize();
    await connect();
  });
  test(
    'offline failure retains intervals and persists bounded backoff',
    () async {
      await connect();
      source.failure = const TibberFailure('Offline');
      for (final minutes in [15, 30, 60, 120, 120]) {
        now = store.record.nextAttempt!;
        await controller.refresh();
        expect(controller.wait, Duration(minutes: minutes));
        expect(controller.saved, isTrue);
        expect(controller.home!.prices.length, 3);
        expect(controller.busy, isFalse);
      }
      source.failure = null;
      now = store.record.nextAttempt!;
      await controller.refresh();
      expect(store.record.failures, 0);
      expect(controller.error, isNull);
      expect(controller.saved, isFalse);
      expect(source.requestedHome, 'test-home');
    },
  );
  test(
    'rate limit survives removal and restart without affecting other stores',
    () async {
      await connect();
      now = store.record.nextAttempt!;
      source.failure = const TibberFailure(
        'Wait',
        retryAfter: Duration(hours: 8),
      );
      await controller.refresh();
      expect(controller.wait, const Duration(hours: 8));
      await controller.disconnect();
      expect(controller.connected, isFalse);
      expect(store.record.token, isNull);
      expect(store.record.home, isNull);
      expect(controller.wait, const Duration(hours: 8));
      await controller.initialize();
      expect(controller.wait, const Duration(hours: 8));
    },
  );
  test(
    'authorization errors stop automatic requests until replacement',
    () async {
      await connect();
      now = store.record.nextAttempt!;
      source.failure = const TibberFailure('Reconnect', authentication: true);
      await controller.refresh();
      now = now.add(const Duration(days: 2));
      controller.tick();
      await controller.refresh();
      expect(source.calls, 2);
      expect(controller.authorizationRequired, isTrue);
      source.failure = null;
      await connect();
      expect(controller.authorizationRequired, isFalse);
    },
  );
  test('background and editing suspend automatic refresh', () async {
    await connect();
    controller.setForeground(false);
    now = now.add(const Duration(days: 1));
    controller.tick();
    expect(source.calls, 1);
    controller.beginEditing();
    controller.setForeground(true);
    expect(source.calls, 1);
    controller.finishEditing();
    controller.tick();
    await Future<void>.delayed(Duration.zero);
    expect(source.calls, 2);
  });
  test('simultaneous refreshes cannot duplicate network requests', () async {
    await connect();
    now = store.record.nextAttempt!;
    source.pending = Completer<List<TibberHome>>();
    final request = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    expect(source.calls, 2);
    expect(await controller.disconnect(), isFalse);
    source.pending!.complete([testHome()]);
    await request;
    expect(controller.busy, isFalse);
  });
  test('cancelled discovery cannot revive a draft after response', () async {
    source.pending = Completer<List<TibberHome>>();
    final request = controller.discover(
      'synthetic',
      PriceResolution.quarterHourly,
    );
    await Future<void>.delayed(Duration.zero);
    controller.finishEditing();
    source.pending!.complete([testHome()]);
    expect(await request, isFalse);
    expect(controller.candidates, isEmpty);
    expect(await controller.saveHome('test-home'), isFalse);
  });
  test(
    'publication retries hourly after 13 and refreshes at site midnight',
    () async {
      now = DateTime.utc(2026, 10, 25, 12);
      await connect();
      expect(store.record.nextRefresh, now.add(const Duration(hours: 1)));
      now = DateTime.utc(2026, 10, 25, 22, 50);
      await controller.refresh();
      expect(store.record.nextRefresh, DateTime.utc(2026, 10, 25, 23));
      expect(store.record.nextAttempt, DateTime.utc(2026, 10, 25, 23, 5));
    },
  );
  test('saved schedule with no active subscription is explicit', () async {
    source.homes = [testHome(status: null)];
    await connect();
    expect(controller.connected, isTrue);
    expect(controller.current, isNull);
  });
  test('record stores gates separately from schedule refresh', () {
    final record = TibberRecord(
      token: 'synthetic',
      home: testHome(),
      receivedAt: now,
      nextRefresh: now.add(const Duration(hours: 6)),
    );
    expect(
      record.withGate(now.add(const Duration(minutes: 15))).nextRefresh,
      record.nextRefresh,
    );
  });
}
