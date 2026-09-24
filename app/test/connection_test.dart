import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  late MemoryStore store;
  late FakeSource source;
  late ConnectionController controller;

  setUp(() {
    store = MemoryStore();
    source = FakeSource();
    controller = ConnectionController(store, source);
  });

  test(
    'validates, saves, restores on restart, and removes credentials',
    () async {
      await controller.initialize();
      expect(await controller.connect(' 123 ', ' $fakeKey '), isTrue);
      expect(store.saved?.siteId, '123');
      expect(store.saved?.apiKey, fakeKey);
      final reopened = ConnectionController(store, source);
      await reopened.initialize();
      expect(reopened.connected, isTrue);
      expect(reopened.overview?.powerWatts, 177);
      expect(await reopened.disconnect(), isTrue);
      expect(store.saved, isNull);
      expect(reopened.overview, isNull);
    },
  );

  test(
    'rejected replacements preserve the previous saved connection',
    () async {
      await controller.connect('123', fakeKey);
      source.reject = true;
      expect(await controller.connect('456', 'b' * 32), isFalse);
      expect(store.saved?.siteId, '123');
      expect(controller.siteId, '123');
      expect(store.writes, 1);
    },
  );

  test('storage write failure is not reported as a saved connection', () async {
    store.failWrite = true;
    expect(await controller.connect('123', fakeKey), isFalse);
    expect(controller.connected, isFalse);
    expect(controller.overview, isNull);
  });

  test('delete failure keeps the connection visible for retry', () async {
    await controller.connect('123', fakeKey);
    store.failDelete = true;
    expect(await controller.disconnect(), isFalse);
    expect(controller.connected, isTrue);
    expect(store.saved, isNotNull);
  });

  test('read failure blocks replacement until storage is recovered', () async {
    store.failRead = true;
    await controller.initialize();
    expect(controller.storageUnavailable, isTrue);
    expect(await controller.connect('123', fakeKey), isFalse);
    expect(source.calls, 0);
    store.failRead = false;
    await controller.initialize();
    expect(await controller.connect('123', fakeKey), isTrue);
  });

  test('offline startup retains saved credentials for later use', () async {
    store.saved = SolarEdgeCredentials('123', fakeKey);
    source.reject = true;
    await controller.initialize();
    expect(controller.connected, isTrue);
    expect(controller.storageUnavailable, isFalse);
    expect(controller.error, isNotNull);
    expect(store.writes, 0);
  });

  test('refresh cooldown prevents repeated network calls', () async {
    var time = DateTime(2026, 9, 22, 10);
    controller = ConnectionController(store, source, now: () => time);
    await controller.connect('123', fakeKey);
    await controller.refresh();
    expect(source.calls, 1);
    time = time.add(const Duration(minutes: 5));
    await controller.refresh();
    expect(source.calls, 2);
  });

  test(
    'a fresh install has no readings and makes no SolarEdge requests',
    () async {
      await controller.initialize();
      expect(controller.connected, isFalse);
      expect(controller.overview, isNull);
      expect(store.saved, isNull);
      expect(source.calls, 0);
    },
  );
}
