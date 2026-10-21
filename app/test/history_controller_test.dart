import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/history.dart';
import 'package:solar_overview/src/history_controller.dart';
import 'package:solar_overview/src/history_store.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax.dart';
import 'package:solar_overview/src/solax_controller.dart';

import 'fakes.dart';
import 'history_fakes.dart';
import 'solax_fakes.dart';

class FailingHistoryStore extends MemoryHistoryStore {
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<List<SavedHistory>> read() async {
    if (failRead) throw StateError('private-storage-details');
    return super.read();
  }

  @override
  Future<void> write(List<SavedHistory> entries) async {
    if (failWrite) throw StateError('private-storage-details');
    await super.write(entries);
  }
}

void main() {
  late DateTime now;
  late HistoryEdgeSource edgeSource;
  late HistorySolaxSource solaxSource;
  late ConnectionController edge;
  late SolaxController solax;
  late MemorySolaxStore solaxStore;
  late MemoryReadingStore readingStore;
  late FailingHistoryStore store;
  late HistoryController controller;
  setUp(() async {
    now = solaxNow;
    edgeSource = HistoryEdgeSource()
      ..reading = const SolarOverview(timeZone: 'Europe/Amsterdam');
    solaxSource = HistorySolaxSource();
    readingStore = MemoryReadingStore();
    edge = ConnectionController(
      MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey),
      edgeSource,
      readingStore: readingStore,
      now: () => now,
    );
    solaxStore = MemorySolaxStore()..record = solaxRecord();
    solax = SolaxController(solaxStore, solaxSource, now: () => now);
    await edge.initialize();
    await solax.initialize();
    now = now.add(const Duration(minutes: 16));
    store = FailingHistoryStore();
    controller = HistoryController(edge, solax, store, now: () => now);
    await controller.initialize();
    controller.selectDay(DateTime.utc(2026, 9, 28));
  });
  tearDown(() {
    controller.dispose();
    edge.dispose();
    solax.dispose();
  });

  test(
    'loading the displayed default day keeps it selected across a clock change',
    () async {
      final resumed = HistoryController(edge, solax, store, now: () => now);
      await resumed.initialize();
      final displayedDay = resumed.selectedDay;
      now = now.add(const Duration(days: 2));
      await resumed.load(HistorySource.solarEdge);
      expect(resumed.selectedDay, displayedDay);
      expect(
        resumed.states[HistorySource.solarEdge]!.saved!.data.day.date,
        displayedDay,
      );
      resumed.dispose();
    },
  );

  test(
    'cache restores across controllers and day/source changes make no requests',
    () async {
      await Future.wait([
        controller.load(HistorySource.solarEdge),
        controller.load(HistorySource.solax),
      ]);
      expect(store.entries.length, 2);
      expect(
        controller.states[HistorySource.solarEdge]!.saved!.data.energyWh,
        2000,
      );
      controller.selectDay(DateTime.utc(2026, 9, 27));
      expect(controller.states[HistorySource.solarEdge]!.saved, isNull);
      expect(
        controller.dailyEnergy(HistorySource.solarEdge)['2026-09-28'],
        2000,
      );
      controller.selectDay(DateTime.utc(2026, 9, 28));
      expect(
        controller.states[HistorySource.solax]!.saved!.data.energyWh,
        1000,
      );
      final restored = HistoryController(edge, solax, store, now: () => now);
      await restored.initialize();
      restored.selectDay(DateTime.utc(2026, 9, 28));
      expect(
        restored.states[HistorySource.solarEdge]!.saved!.data.energyWh,
        2000,
      );
      expect(edgeSource.historyCalls, 1);
      expect(solaxSource.historyCalls, 1);
      restored.dispose();
    },
  );

  test('history and live refresh share a durable quota gate and reject duplicate work', () async {
    edgeSource.pending = Completer<void>();
    final pending = controller.load(HistorySource.solarEdge);
    await Future<void>.delayed(Duration.zero);
    await controller.load(HistorySource.solarEdge);
    await edge.refresh();
    expect(edgeSource.historyCalls, 1);
    expect(edgeSource.calls, 1);
    expect(
      readingStore.cache.nextAttempt,
      now.add(const Duration(minutes: 15)),
    );
    edgeSource.pending!.complete();
    await pending;
    await controller.load(HistorySource.solarEdge);
    expect(edgeSource.historyCalls, 1);
    expect(
      controller.states[HistorySource.solarEdge]!.error,
      contains('Next request'),
    );
  });

  test(
    'navigation during an in-flight request never assigns data to another day',
    () async {
      edgeSource.pending = Completer<void>();
      final pending = controller.load(HistorySource.solarEdge);
      await Future<void>.delayed(Duration.zero);
      controller.selectDay(DateTime.utc(2026, 9, 27));
      edgeSource.pending!.complete();
      await pending;
      expect(controller.states[HistorySource.solarEdge]!.saved, isNull);
      controller.selectDay(DateTime.utc(2026, 9, 28));
      expect(
        controller.states[HistorySource.solarEdge]!.saved!.data.day.date,
        DateTime.utc(2026, 9, 28),
      );
    },
  );

  test(
    'provider failures and rate limits retain healthy source and prior history',
    () async {
      await controller.load(HistorySource.solarEdge);
      now = now.add(const Duration(minutes: 16));
      edgeSource.historyFailure = const SolarEdgeFailure(
        'Request limit reached.',
        rateLimited: true,
      );
      await Future.wait([
        controller.load(HistorySource.solarEdge),
        controller.load(HistorySource.solax),
      ]);
      expect(controller.states[HistorySource.solarEdge]!.saved, isNotNull);
      expect(
        controller.states[HistorySource.solarEdge]!.error,
        'Request limit reached.',
      );
      expect(controller.states[HistorySource.solax]!.saved, isNotNull);
      expect(
        readingStore.cache.nextAttempt,
        now.add(const Duration(hours: 24)),
      );
      solaxSource.historyFailure = const SolaxFailure(
        'Token revoked.',
        kind: SolaxFailureKind.revoked,
      );
      now = now.add(const Duration(minutes: 16));
      await controller.load(HistorySource.solax);
      expect(solax.reconnectRequired, isTrue);
      expect(solaxStore.record.token, isNull);
      expect(controller.states[HistorySource.solax]!.saved, isNotNull);
      final calls = solaxSource.historyCalls;
      final deadline = solaxStore.record.nextAttempt;
      now = now.add(const Duration(minutes: 16));
      await controller.load(HistorySource.solax);
      expect(solaxSource.historyCalls, calls);
      expect(solaxStore.record.nextAttempt, deadline);
    },
  );

  test('cache storage failure keeps previous data and never exposes raw diagnostics', () async {
    await controller.load(HistorySource.solarEdge);
    final previous = controller.states[HistorySource.solarEdge]!.saved;
    store.failWrite = true;
    now = now.add(const Duration(minutes: 16));
    await controller.load(HistorySource.solarEdge);
    expect(controller.states[HistorySource.solarEdge]!.saved, same(previous));
    expect(
      controller.states[HistorySource.solarEdge]!.error,
      isNot(contains('private-storage-details')),
    );
    expect(store.entries.length, 1);
  });

  test('failed cache read requires recovery before network and never overwrites saved data', () async {
    store.failRead = true;
    await controller.initialize();
    await controller.load(HistorySource.solarEdge);
    expect(edgeSource.historyCalls, 0);
    expect(controller.storageError, isNotNull);
    store.failRead = false;
    await controller.initialize();
    await controller.load(HistorySource.solarEdge);
    expect(edgeSource.historyCalls, 1);
  });

  test('explicit cache clearing repairs corruption without changing connection or quota', () async {
    await controller.load(HistorySource.solarEdge);
    final deadline = readingStore.cache.nextAttempt;
    store.failRead = true;
    await controller.initialize();
    expect(controller.storageError, isNotNull);
    await controller.clearSavedHistory();
    expect(store.entries, isEmpty);
    expect(controller.storageError, isNull);
    expect(edge.connected, isTrue);
    expect(readingStore.cache.nextAttempt, deadline);
    expect(controller.states[HistorySource.solarEdge]!.saved, isNull);
  });

  test('disconnect and replacement isolate prior account history', () async {
    await controller.load(HistorySource.solarEdge);
    await edge.disconnect();
    expect(controller.states[HistorySource.solarEdge]!.saved, isNull);
    now = now.add(const Duration(minutes: 16));
    await edge.connect('456', fakeKey);
    expect(controller.states[HistorySource.solarEdge]!.saved, isNull);
    expect(controller.dailyEnergy(HistorySource.solarEdge), isEmpty);
  });

  test('newest monthly snapshot replaces missing revised totals and future days stay unavailable', () async {
    final day = HistoryDay(DateTime.utc(2026, 9, 28), 'Europe/Amsterdam');
    store.entries = [
      SavedHistory(
        'edge:123',
        ProductionHistory(
          day: day,
          interval: const Duration(minutes: 15),
          samples: [],
          dailyWh: {'2026-09-27': 1000, '2026-09-30': 0},
        ),
        now,
      ),
      SavedHistory(
        'edge:123',
        ProductionHistory(
          day: HistoryDay(DateTime.utc(2026, 9, 29), day.timeZone),
          interval: const Duration(minutes: 15),
          samples: [],
          dailyWh: {'2026-09-28': 2000, '2026-09-30': 0},
        ),
        now,
      ),
    ];
    await controller.initialize();
    expect(controller.dailyEnergy(HistorySource.solarEdge), {
      '2026-09-28': 2000,
    });
  });
}
