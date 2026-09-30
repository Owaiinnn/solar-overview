import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/solax.dart';
import 'package:solar_overview/src/solax_controller.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';
import 'solax_fakes.dart';

void main() {
  late MemorySolaxStore store;
  late FakeSolaxSource source;
  late SolaxController controller;
  late DateTime now;
  setUp(() {
    now = solaxNow;
    store = MemorySolaxStore();
    source = FakeSolaxSource();
    controller = SolaxController(store, source, now: () => now);
  });
  tearDown(() => controller.dispose());
  Future<void> connect({String id = 'client', String secret = 'secret'}) async {
    expect(await controller.discover(id, secret), isTrue);
    await controller.selectPlant(controller.plants.single);
    controller.selectDevice(controller.devices.single);
    expect(await controller.saveSelection(), isTrue);
  }

  test('test/discovery/selection/save use one token and one persistent request slot', () async {
    await controller.initialize();
    await connect();
    expect(source.authCalls, 1);
    expect(source.plantCalls, 1);
    expect(source.deviceCalls, 1);
    expect(source.readingCalls, 1);
    expect(source.tokens.toSet().length, 1);
    expect(store.record.credentials!.clientId, 'client');
    expect(store.record.reading!.powerWatts, 120);
    expect(store.record.nextAttempt, now.add(const Duration(minutes: 15)));
    expect(controller.connected, isTrue);
    expect(controller.selecting, isFalse);
    await controller.refresh();
    expect(source.readingCalls, 1);
  });
  test('restart restores cache and token without network; expired wait allows refresh', () async {
    store.record = solaxRecord(next: now.add(const Duration(minutes: 15)));
    await controller.initialize();
    expect(source.readingCalls, 0);
    expect(controller.usingSavedReading, isTrue);
    now = now.add(const Duration(minutes: 16));
    await controller.refresh();
    expect(source.readingCalls, 1);
    expect(source.authCalls, 0);
    expect(controller.usingSavedReading, isFalse);
  });
  test('expiration renews once and saves token before telemetry', () async {
    store.record = solaxRecord(expiry: now);
    await controller.initialize();
    expect(source.authCalls, 1);
    expect(source.readingCalls, 1);
    expect(store.record.token!.value, 'synthetic-new-token-1');
  });
  test('concurrent initialization, refresh and discovery cannot race token renewal', () async {
    store.record = solaxRecord(expiry: now);
    source.pending = Completer<void>();
    final initializing = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    expect(await controller.discover('other', 'secret'), isFalse);
    await controller.initialize();
    expect(source.authCalls, 1);
    source.pending!.complete();
    await initializing;
    expect(source.authCalls, 1);
    expect(source.readingCalls, 1);
  });
  test(
    'revocation requires explicit reconnection and survives restart',
    () async {
      store.record = solaxRecord();
      source.failure = const SolaxFailure(
        'Revoked.',
        kind: SolaxFailureKind.revoked,
      );
      await controller.initialize();
      expect(controller.reconnectRequired, isTrue);
      expect(store.record.token, isNull);
      expect(controller.reading, isNotNull);
      expect(source.authCalls, 0);
      now = now.add(const Duration(days: 1));
      await controller.initialize();
      await controller.refresh();
      expect(source.authCalls, 0);
      expect(source.readingCalls, 1);
      source.failure = null;
      now = now.add(const Duration(minutes: 16));
      await connect();
      expect(controller.reconnectRequired, isFalse);
      expect(source.authCalls, 1);
    },
  );
  test(
    'expired-token authentication failure never erases last good reading',
    () async {
      store.record = solaxRecord(expiry: now);
      source.authFailure = const SolaxFailure(
        'Rejected.',
        kind: SolaxFailureKind.authentication,
      );
      await controller.initialize();
      expect(controller.reading, isNotNull);
      expect(controller.reconnectRequired, isTrue);
      expect(source.readingCalls, 0);
    },
  );
  test(
    'offline refresh retains visibly stale reading and never uses fetch time',
    () async {
      store.record = solaxRecord();
      now = now.add(const Duration(hours: 1));
      source.failure = const SolaxFailure('Offline.');
      await controller.initialize();
      expect(controller.freshness, ReadingFreshness.stale);
      expect(controller.usingSavedReading, isTrue);
      expect(store.record.fetchedAt, solaxNow);
      expect(controller.error, 'Offline.');
    },
  );
  test('quota backoff persists through restart and disconnect', () async {
    store.record = solaxRecord();
    source.failure = const SolaxFailure(
      'Limited.',
      kind: SolaxFailureKind.rateLimit,
    );
    await controller.initialize();
    expect(store.record.nextAttempt, now.add(const Duration(hours: 24)));
    await controller.disconnect();
    expect(store.record.credentials, isNull);
    expect(store.record.token, isNull);
    expect(store.record.reading, isNull);
    expect(store.record.nextAttempt, now.add(const Duration(hours: 24)));
    await controller.initialize();
    expect(await controller.discover('new', 'secret'), isFalse);
    expect(source.authCalls, 0);
  });
  test('storage read or quota reservation failure blocks network', () async {
    store.failRead = true;
    await controller.initialize();
    expect(controller.storageUnavailable, isTrue);
    expect(await controller.discover('client', 'secret'), isFalse);
    expect(source.authCalls, 0);
    store.failRead = false;
    await controller.initialize();
    store.failWrite = true;
    expect(await controller.discover('client', 'secret'), isFalse);
    expect(source.authCalls, 0);
    expect(controller.storageUnavailable, isTrue);
    store.failWrite = false;
    await controller.initialize();
    expect(controller.storageUnavailable, isFalse);
    expect(controller.canRequest, isFalse);
  });
  test(
    'failed renewed token write is recovered before more requests',
    () async {
      store.record = solaxRecord(expiry: now);
      store.failAtWrite = 2;
      await controller.initialize();
      expect(source.authCalls, 1);
      expect(source.readingCalls, 0);
      expect(controller.storageUnavailable, isTrue);
      await controller.initialize();
      expect(source.authCalls, 1);
      expect(store.record.token!.value, 'synthetic-new-token-1');
      now = now.add(const Duration(minutes: 16));
      await controller.refresh();
      expect(source.authCalls, 1);
      expect(source.readingCalls, 1);
    },
  );
  test(
    'failed backoff write retains longer pause after storage recovery',
    () async {
      store.record = solaxRecord();
      store.failAtWrite = 2;
      source.failure = const SolaxFailure(
        'Limited.',
        kind: SolaxFailureKind.rateLimit,
      );
      await controller.initialize();
      expect(controller.storageUnavailable, isTrue);
      await controller.initialize();
      expect(store.record.nextAttempt, now.add(const Duration(hours: 24)));
      expect(source.readingCalls, 1);
    },
  );
  test(
    'failed replacement leaves old credentials and reading together',
    () async {
      store.record = solaxRecord(next: now.add(const Duration(minutes: 15)));
      await controller.initialize();
      now = now.add(const Duration(minutes: 16));
      await controller.discover('new-client', 'new-secret');
      await controller.selectPlant(controller.plants.single);
      controller.selectDevice(controller.devices.single);
      store.failWrite = true;
      expect(await controller.saveSelection(), isFalse);
      expect(store.record.credentials!.clientId, 'synthetic-client');
      expect(controller.reading!.powerWatts, 120);
      store.failWrite = false;
      await controller.initialize();
      expect(store.record.credentials!.clientId, 'synthetic-client');
    },
  );
  test(
    'successful account replacement atomically replaces old token and readings',
    () async {
      store.record = solaxRecord(next: now.add(const Duration(minutes: 15)));
      await controller.initialize();
      now = now.add(const Duration(minutes: 16));
      source.result = solaxReading(power: 33);
      await connect(id: 'new-client');
      expect(store.record.credentials!.clientId, 'new-client');
      expect(store.record.reading!.powerWatts, 33);
      expect(store.record.token!.value, 'synthetic-new-token-1');
    },
  );
  test('disconnect failure does not claim removal; corrupt storage recovery preserves wait', () async {
    store.record = solaxRecord(next: now.add(const Duration(minutes: 15)));
    await controller.initialize();
    store.failWrite = true;
    expect(await controller.disconnect(), isFalse);
    expect(controller.connected, isTrue);
    store.failWrite = false;
    expect(await controller.disconnect(), isTrue);
    expect(controller.connected, isFalse);
    controller.dispose();
    controller = SolaxController(store, source, now: () => now);
    store.failRead = true;
    await controller.initialize();
    expect(await controller.disconnect(), isTrue);
    expect(store.record.nextAttempt, now.add(const Duration(hours: 24)));
  });
  test(
    'cancelled or expired discovery cannot save candidate account',
    () async {
      await controller.initialize();
      await controller.discover('client', 'secret');
      controller.cancelSelection();
      expect(await controller.saveSelection(), isFalse);
      expect(store.record.credentials, isNull);
      now = now.add(const Duration(minutes: 16));
      await controller.discover('client', 'secret');
      now = now.add(const Duration(minutes: 16));
      await controller.selectPlant(controller.plants.single);
      expect(source.deviceCalls, 0);
      expect(controller.selecting, isFalse);
      expect(controller.error, contains('expired'));
    },
  );
  test('interactive discovery has a bounded device-page budget', () async {
    await controller.initialize();
    await controller.discover('client', 'secret');
    for (var i = 0; i < 6; i++) {
      await controller.selectPlant(controller.plants.single);
    }
    expect(source.deviceCalls, 5);
    expect(controller.selecting, isFalse);
    expect(controller.canRequest, isFalse);
  });
  test('SolaX lifecycle cannot change SolarEdge source or quota', () async {
    final edgeStore = MemoryStore();
    final edgeSource = FakeSource();
    final edge = ConnectionController(edgeStore, edgeSource, now: () => now);
    await edge.initialize();
    await edge.connect('123', fakeKey);
    final before = edge.overview;
    await controller.initialize();
    await connect();
    await controller.disconnect();
    expect(edge.connected, isTrue);
    expect(edge.overview, same(before));
    expect(edgeSource.calls, 1);
    expect(edge.canRequest, isFalse);
    edge.dispose();
  });
}
