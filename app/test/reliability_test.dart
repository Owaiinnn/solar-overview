import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:solar_overview/src/solar_freshness.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

class FailingReadingStore extends MemoryReadingStore {
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  int? failAtWrite;
  @override
  Future<ReadingCache> read() async {
    if (failRead) throw const SolarEdgeFailure('Cannot read cache.');
    return super.read();
  }

  @override
  Future<void> write(ReadingCache cache) async {
    writes++;
    if (failWrite || writes == failAtWrite) {
      throw const SolarEdgeFailure('Cannot save cache.');
    }
    await super.write(cache);
  }
}

class PendingSource implements SolarEdgeSource {
  final result = Completer<SolarOverview>();
  int calls = 0;
  @override
  Future<SolarOverview> overview(SolarEdgeCredentials credentials) {
    calls++;
    return result.future;
  }
}

void main() {
  late MemoryStore credentials;
  late FailingReadingStore cache;
  late FakeSource source;
  late DateTime now;
  ConnectionController controller() => ConnectionController(
    credentials,
    source,
    readingStore: cache,
    now: () => now,
  );
  setUp(() {
    credentials = MemoryStore();
    cache = FailingReadingStore();
    source = FakeSource()
      ..reading = const SolarOverview(
        powerWatts: 0,
        energyWh: 1200,
        reportedAt: '2026-09-28 14:00:00',
        timeZone: 'Europe/Amsterdam',
      );
    now = DateTime.utc(2026, 9, 28, 12);
  });

  test(
    'restart restores saved readings and gate without an API request',
    () async {
      final first = controller();
      expect(await first.connect('123', fakeKey), isTrue);
      now = now.add(const Duration(minutes: 5));
      final reopened = controller();
      await reopened.initialize();
      expect(reopened.overview?.powerWatts, 0);
      expect(reopened.todayEnergyWh, 1200);
      expect(reopened.usingSavedReading, isTrue);
      expect(reopened.freshness, ReadingFreshness.recent);
      await reopened.refresh();
      expect(await reopened.connect('456', 'b' * 32), isFalse);
      expect(source.calls, 1);
      now = now.add(const Duration(minutes: 10));
      await reopened.refresh();
      expect(source.calls, 2);
      expect(reopened.usingSavedReading, isFalse);
    },
  );

  test(
    'offline startup keeps last success, exposes error, and limits retries',
    () async {
      await controller().connect('123', fakeKey);
      now = now.add(const Duration(minutes: 40));
      source.reject = true;
      final reopened = controller();
      await reopened.initialize();
      expect(reopened.error, 'Connection rejected.');
      expect(reopened.storageUnavailable, isFalse);
      expect(reopened.overview?.powerWatts, 0);
      expect(reopened.usingSavedReading, isTrue);
      expect(reopened.freshness, ReadingFreshness.stale);
      expect(cache.cache.fetchedAt, DateTime.utc(2026, 9, 28, 12));
      await controller().initialize();
      expect(source.calls, 2);
    },
  );

  test(
    '429 backoff survives restart, removal and attempted reconnect',
    () async {
      final first = controller();
      await first.connect('123', fakeKey);
      now = now.add(ConnectionController.refreshInterval);
      source.rateLimit = true;
      await first.refresh();
      expect(first.refreshNotice, contains('request limit'));
      expect(first.overview?.energyWh, 1200);
      now = now.add(const Duration(hours: 1));
      final reopened = controller();
      await reopened.initialize();
      expect(reopened.refreshNotice, contains('request limit'));
      await reopened.disconnect();
      expect(cache.cache.overview, isNull);
      expect(cache.cache.siteId, isNull);
      expect(await controller().connect('123', fakeKey), isFalse);
      expect(source.calls, 2);
      now = now.add(const Duration(hours: 23));
      source.rateLimit = false;
      expect(await controller().connect('123', fakeKey), isTrue);
      expect(source.calls, 3);
    },
  );

  test(
    'invalid local input uses no request slot; rejected API tests do',
    () async {
      final first = controller();
      expect(await first.connect('bad', fakeKey), isFalse);
      expect(cache.cache.nextAttempt, isNull);
      source.reject = true;
      expect(await first.connect('123', fakeKey), isFalse);
      expect(await controller().connect('123', fakeKey), isFalse);
      expect(source.calls, 1);
    },
  );

  test('cached readings never attach to a different saved site', () async {
    await controller().connect('123', fakeKey);
    credentials.saved = SolarEdgeCredentials('456', 'b' * 32);
    final reopened = controller();
    await reopened.initialize();
    expect(reopened.siteId, '456');
    expect(reopened.overview, isNull);
    expect(source.calls, 1);
  });

  test(
    'successful replacement and disconnect discard the old snapshot',
    () async {
      final first = controller();
      await first.connect('123', fakeKey);
      now = now.add(ConnectionController.refreshInterval);
      source.reading = const SolarOverview(powerWatts: 500);
      expect(await first.connect('456', 'b' * 32), isTrue);
      final reopened = controller();
      await reopened.initialize();
      expect(reopened.overview?.powerWatts, 500);
      expect(cache.cache.siteId, '456');
      await reopened.disconnect();
      await controller().initialize();
      expect(credentials.saved, isNull);
      expect(cache.cache.overview, isNull);
      expect(source.calls, 2);
    },
  );

  test('storage failures block requests and can be retried safely', () async {
    cache.failRead = true;
    final first = controller();
    await first.initialize();
    expect(first.storageUnavailable, isTrue);
    expect(await first.connect('123', fakeKey), isFalse);
    expect(source.calls, 0);
    cache.failRead = false;
    await first.initialize();
    cache.failWrite = true;
    expect(await first.connect('123', fakeKey), isFalse);
    expect(source.calls, 0);
    expect(first.storageUnavailable, isTrue);
    cache.failWrite = false;
    await first.initialize();
    expect(first.storageUnavailable, isFalse);
    expect(first.canRequest, isFalse);
    now = now.add(ConnectionController.refreshInterval);
    expect(await first.connect('123', fakeKey), isTrue);
  });

  test(
    'removing a corrupt cache preserves a conservative request pause',
    () async {
      credentials.saved = SolarEdgeCredentials('123', fakeKey);
      cache.failRead = true;
      final first = controller();
      await first.initialize();
      expect(await first.disconnect(), isTrue);
      expect(credentials.saved, isNull);
      expect(cache.cache.overview, isNull);
      expect(cache.cache.nextAttempt, now.add(const Duration(hours: 24)));
      expect(source.calls, 0);
    },
  );

  test(
    'simultaneous initialization and actions cannot issue duplicate calls',
    () async {
      final pending = PendingSource();
      credentials.saved = SolarEdgeCredentials('123', fakeKey);
      final first = ConnectionController(
        credentials,
        pending,
        readingStore: cache,
        now: () => now,
      );
      final opening = first.initialize();
      await Future<void>.delayed(Duration.zero);
      await first.initialize();
      await first.refresh();
      expect(await first.connect('456', 'b' * 32), isFalse);
      expect(pending.calls, 1);
      pending.result.complete(source.reading!);
      await opening;
      expect(first.busy, isFalse);
    },
  );

  test('failed replacement save restores previous cache and retains the request gate', () async {
    final first = controller();
    await first.connect('123', fakeKey);
    now = now.add(ConnectionController.refreshInterval);
    credentials.failWrite = true;
    expect(await first.connect('456', 'b' * 32), isFalse);
    final reopened = controller();
    await reopened.initialize();
    expect(reopened.siteId, '123');
    expect(reopened.overview?.energyWh, 1200);
    expect(reopened.canRequest, isFalse);
    expect(source.calls, 2);
  });

  test('snapshot save failure preserves saved credentials and recovers without another request', () async {
    cache.failAtWrite = 3;
    final first = controller();
    expect(await first.connect('123', fakeKey), isTrue);
    expect(first.connected, isTrue);
    expect(first.storageUnavailable, isTrue);
    expect(first.overview?.energyWh, 1200);
    expect(first.error, 'Cannot save cache.');
    await first.initialize();
    expect(first.storageUnavailable, isFalse);
    expect(cache.cache.overview?.energyWh, 1200);
    expect(source.calls, 1);
  });

  test('failed 429 persistence keeps the extended gate in memory for storage retry', () async {
    final first = controller();
    await first.connect('123', fakeKey);
    now = now.add(ConnectionController.refreshInterval);
    source.rateLimit = true;
    cache.failAtWrite = cache.writes + 2;
    await first.refresh();
    expect(first.storageUnavailable, isTrue);
    expect(first.refreshNotice, contains('request limit'));
    await first.initialize();
    expect(cache.cache.nextAttempt, now.add(const Duration(hours: 24)));
    expect(first.storageUnavailable, isFalse);
    expect(source.calls, 2);
  });
}
