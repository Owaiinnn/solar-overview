import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/production_total.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax.dart';
import 'package:solar_overview/src/solax_controller.dart';
import 'package:solar_overview/src/solax_store.dart';

import 'fakes.dart';
import 'solax_fakes.dart';

Future<ConnectionController> edgeController({
  double? power = 1000,
  String? stamp = '2026-09-29 14:00:00',
  DateTime Function()? now,
}) async {
  final controller = ConnectionController(
    MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey),
    FakeSource(),
    readingStore: MemoryReadingStore()
      ..cache = ReadingCache(
        siteId: '123',
        overview: SolarOverview(
          powerWatts: power,
          energyWh: 3200,
          reportedAt: stamp,
          timeZone: 'Europe/Amsterdam',
        ),
        fetchedAt: solaxNow,
        nextAttempt: solaxNow.add(const Duration(minutes: 15)),
      ),
    now: now ?? () => solaxNow,
  );
  await controller.initialize();
  addTearDown(controller.dispose);
  return controller;
}

Future<SolaxController> solaxController({
  double? power = 120,
  String? stamp = '2026-09-29T12:00:00Z',
  DateTime Function()? now,
  FakeSolaxSource? source,
}) async {
  final controller = SolaxController(
    MemorySolaxStore()
      ..record = SolaxRecord(
        credentials: SolaxCredentials('synthetic-client', 'synthetic-secret'),
        token: SolaxToken(
          'synthetic-token',
          solaxNow.add(const Duration(days: 20)),
        ),
        plant: solaxPlant,
        device: solaxDevice,
        reading: SolaxReading.fromResponse({
          'dataTime': stamp,
          'acPower1': power,
          'dailyACOutput': 1.2,
          'totalACOutput': 95.5,
          'dailyYield': 99,
          'deviceStatus': 102,
          'inverterTemperature': 32.5,
          'mpptMap': {
            'MPPT1Power': 50,
            'MPPT1Voltage': 35,
            'MPPT1Current': 1.4,
            'MPPT2Power': 75,
            'MPPT2Voltage': 36,
            'MPPT2Current': 2.1,
          },
        }, 'Europe/Amsterdam'),
        fetchedAt: solaxNow,
        nextAttempt: solaxNow.add(const Duration(minutes: 15)),
      ),
    source ?? FakeSolaxSource(),
    now: now ?? () => solaxNow,
  );
  await controller.initialize();
  addTearDown(controller.dispose);
  return controller;
}

class PendingCredentialStore extends MemoryStore {
  final pending = Completer<SolarEdgeCredentials?>();
  @override
  Future<SolarEdgeCredentials?> read() => pending.future;
}

void main() {
  for (final scenario in [
    'empty',
    'SolarEdge',
    'SolaX',
    'combined',
    'mismatch',
  ]) {
    testWidgets('Home and Details agree on production coverage: $scenario', (
      tester,
    ) async {
      final edge = await edgeController(
        power: scenario == 'empty' || scenario == 'SolaX' ? null : 1000,
      );
      final solax = await solaxController(
        power: scenario == 'empty' || scenario == 'SolarEdge' ? null : 120,
        stamp: scenario == 'mismatch'
            ? '2026-09-29T11:54:59Z'
            : '2026-09-29T12:00:00Z',
      );
      final partial = scenario == 'SolarEdge' || scenario == 'SolaX';
      final title = partial
          ? 'Partial solar production'
          : 'Combined solar production';
      final coverage = partial
          ? '$scenario only · 1 of 2 sources'
          : 'SolarEdge + SolaX · ${scenario == 'empty' ? 0 : 2} of 2 sources';
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      expect(find.text(title), findsOneWidget);
      expect(find.text(coverage), findsOneWidget);
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      expect(find.text(title), findsOneWidget);
      expect(find.text(coverage), findsOneWidget);
      if (scenario == 'mismatch') {
        expect(
          find.textContaining('A combined reading is unavailable.'),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
    'combines only AC output, including valid zero and recent saved readings',
    () async {
      final edge = await edgeController();
      final solax = await solaxController();
      expect(edge.usingSavedReading, isTrue);
      expect(solax.usingSavedReading, isTrue);
      expect(ProductionTotal(edge, solax).watts, 1120);
      expect(
        ProductionTotal(
          await edgeController(power: 0),
          await solaxController(power: 0),
        ).watts,
        0,
      );
    },
  );

  test(
    'five-minute skew is allowed; larger skew withholds the total',
    () async {
      final edge = await edgeController();
      expect(
        ProductionTotal(
          edge,
          await solaxController(stamp: '2026-09-29T11:55:00Z'),
        ).watts,
        1120,
      );
      final mismatch = ProductionTotal(
        edge,
        await solaxController(stamp: '2026-09-29T11:54:59Z'),
      );
      expect(mismatch.timeMismatch, isTrue);
      expect(mismatch.watts, isNull);
      final reverse = ProductionTotal(
        await edgeController(stamp: '2026-09-29 13:54:59'),
        await solaxController(),
      );
      expect(reverse.watts, isNull);
    },
  );

  test('missing, stale, unknown and future readings produce explicit partial coverage', () async {
    final edge = await edgeController();
    for (final solax in [
      await solaxController(power: null),
      await solaxController(stamp: '2026-09-29T11:30:00Z'),
      await solaxController(stamp: null),
      await solaxController(stamp: '2026-09-29T12:00:01Z'),
    ]) {
      final total = ProductionTotal(edge, solax);
      expect(total.sources.keys, ['SolarEdge']);
      expect(total.watts, 1000);
    }
    final onlySolax = ProductionTotal(
      await edgeController(power: null),
      await solaxController(),
    );
    expect(onlySolax.sources.keys, ['SolaX']);
    expect(onlySolax.watts, 120);
    expect(
      ProductionTotal(await edgeController(stamp: null), null).watts,
      isNull,
    );
  });

  test('failed and storage-blocked sources are excluded despite recent cached values', () async {
    final edge = await edgeController();
    final solax = await solaxController();
    solax.error = 'SolaX is unavailable.';
    expect(ProductionTotal(edge, solax).sources.keys, ['SolarEdge']);
    solax.error = null;
    edge.storageUnavailable = true;
    expect(ProductionTotal(edge, solax).sources.keys, ['SolaX']);
    solax.storageUnavailable = true;
    expect(ProductionTotal(edge, solax).watts, isNull);
  });

  testWidgets(
    'SolaX remains usable while SolarEdge opens; navigation stays available',
    (tester) async {
      final store = PendingCredentialStore();
      final edge = ConnectionController(store, FakeSource());
      final opening = edge.initialize();
      final solax = await solaxController();
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      expect(find.text('Opening SolarEdge connection…'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recent SolaX reading'), 200);
      expect(find.text('Recent SolaX reading'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(find.text('Your production history'), findsOneWidget);
      store.pending.complete(null);
      await opening;
      await tester.pumpWidget(const SizedBox());
      edge.dispose();
    },
  );

  testWidgets(
    'source updates age the total without polling and midnight hides SolaX energy',
    (tester) async {
      var now = solaxNow;
      final edge = await edgeController(now: () => now);
      final source = FakeSolaxSource();
      final solax = await solaxController(now: () => now, source: source);
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Combined solar production'),
        300,
      );
      expect(find.text('1.12 kW'), findsOneWidget);
      now = now.add(const Duration(minutes: 30));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('1.12 kW'), findsNothing);
      now = DateTime.utc(2026, 9, 29, 22);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('SolaX panels'), 300);
      expect(find.text('1.20 kWh'), findsNothing);
      expect(
        find.textContaining('Today’s counter is unavailable'),
        findsOneWidget,
      );
      expect(source.readingCalls, 0);
      expect(source.authCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'SolaX refresh failure retains its reading and isolates SolarEdge',
    (tester) async {
      var now = solaxNow;
      final edge = await edgeController(now: () => now);
      final source = FakeSolaxSource()
        ..failure = const SolaxFailure('SolaX network unavailable.');
      final solax = await solaxController(now: () => now, source: source);
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      now = now.add(const Duration(minutes: 15));
      solax.updateFreshness();
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Refresh SolaX'), 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Refresh SolaX'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh SolaX'));
      await tester.pumpAndSettle();
      expect(source.readingCalls, 1);
      expect(source.authCalls, 0);
      expect(solax.reading?.powerWatts, 120);
      expect(edge.error, isNull);
      expect(edge.overview?.powerWatts, 1000);
      expect(solax.canRequest, isFalse);
      await tester.scrollUntilVisible(find.text('SolaX panels'), -200);
      expect(find.text('SolaX network unavailable.'), findsOneWidget);
      expect(find.text('Showing the saved SolaX reading.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Partial solar production'),
        -300,
      );
      expect(find.text('SolarEdge only · 1 of 2 sources'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    testWidgets('source details and partial total fit $size with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final edge = await edgeController();
      final solax = await solaxController();
      edge.error = 'SolarEdge connection failed.';
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('SolarEdge connection failed.'),
        200,
      );
      expect(find.text('SolarEdge connection failed.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('SolaX source details'), 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('SolaX source details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SolaX source details'));
      await tester.pumpAndSettle();
      for (final label in [
        'MPPT 1 (DC)',
        'Power: 50.0 W',
        'Voltage: 35.0 V',
        'Current: 1.4 A',
        'MPPT 2 (DC)',
        'Power: 75.0 W',
        'Inverter temperature: 32.5 °C',
        'Lifetime inverter AC energy: 95.50 kWh',
      ]) {
        await tester.scrollUntilVisible(find.text(label), 100);
        expect(find.text(label), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.text('Partial solar production'),
        -200,
      );
      expect(find.text('SolaX only · 1 of 2 sources'), findsOneWidget);
      expect(find.text('Combined solar production'), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Household consumption: unavailable'),
        200,
      );
      expect(
        find.textContaining('Household consumption: unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('PowerFlex solar'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
