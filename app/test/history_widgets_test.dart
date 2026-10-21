import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/history.dart';
import 'package:solar_overview/src/history_controller.dart';
import 'package:solar_overview/src/history_page.dart';
import 'package:solar_overview/src/history_store.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax_controller.dart';

import 'fakes.dart';
import 'history_fakes.dart';
import 'solax_fakes.dart';

Future<HistoryController> savedHistoryController({
  HistoryStore? historyStore,
}) async {
  final now = solaxNow.add(const Duration(minutes: 16));
  final edge = ConnectionController(
    MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey),
    HistoryEdgeSource()
      ..reading = const SolarOverview(timeZone: 'Europe/Amsterdam'),
    now: () => solaxNow,
  );
  final solax = SolaxController(
    MemorySolaxStore()..record = solaxRecord(),
    HistorySolaxSource(),
    now: () => solaxNow,
  );
  await edge.initialize();
  await solax.initialize();
  final store = historyStore ?? MemoryHistoryStore();
  final day = HistoryDay(DateTime.utc(2026, 9, 28), 'Europe/Amsterdam');
  await store.write([
    SavedHistory('edge:123', syntheticHistory(day), now),
    SavedHistory(
      solax.historyIdentity!,
      syntheticHistory(day, watts: 200, energy: 1000),
      now,
    ),
  ]);
  final controller = HistoryController(edge, solax, store, now: () => now);
  await controller.initialize();
  controller.selectDay(day.date);
  return controller;
}

void main() {
  testWidgets('a failed source is explained beside the healthy source graph', (
    tester,
  ) async {
    final store = MemoryHistoryStore();
    final controller = await savedHistoryController(historyStore: store);
    store.entries.removeWhere((entry) => entry.identity == 'edge:123');
    await controller.initialize();
    controller.states[HistorySource.solarEdge]!.error = 'SolarEdge could not load power history (HTTP 503). Please try again later.';
    addTearDown(() {
      controller.dispose();
      controller.edge.dispose();
      controller.solax!.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryPage(controller: controller, openSettings: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find
          .textContaining('SolarEdge history could not be loaded.')
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text('SolaX (AC)'), findsOneWidget);
    expect(find.text('SolarEdge (AC)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed reload keeps the saved source curve visible', (
    tester,
  ) async {
    final controller = await savedHistoryController();
    controller.states[HistorySource.solarEdge]!.error = 'SolarEdge could not load power history (HTTP 503). Please try again later.';
    addTearDown(() {
      controller.dispose();
      controller.edge.dispose();
      controller.solax!.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryPage(controller: controller, openSettings: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find
          .textContaining('SolarEdge refresh failed; showing its saved curve.')
          .hitTestable(),
      findsOneWidget,
    );
    expect(find.text('SolarEdge (AC)'), findsOneWidget);
    expect(find.text('SolaX (AC)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source filters, day browsing, DC graph and month comparison use saved data',
    (tester) async {
      final controller = await savedHistoryController();
      addTearDown(() {
        controller.dispose();
        controller.edge.dispose();
        controller.solax!.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryPage(controller: controller, openSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AC production power').hitTestable(), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'SolarEdge'));
      await tester.pumpAndSettle();
      expect(find.text('2.00 kWh'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Show SolaX DC inputs').hitTestable(),
        250,
      );
      await tester.tap(find.text('Show SolaX DC inputs'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('DC input power').hitTestable(),
        200,
      );
      expect(find.text('SolaX input 1 (DC)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Daily comparison · 2026-09').hitTestable(),
        200,
      );
      await tester.tap(find.text('Daily comparison · 2026-09'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2026-09-27').hitTestable(),
        400,
      );
      await tester.tap(find.text('2026-09-27'));
      await tester.pumpAndSettle();
      expect(controller.selectedDay, DateTime.utc(2026, 9, 27));
      expect(controller.edge.busy, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the graph area remains visible before any source history is loaded',
    (tester) async {
      final controller = await savedHistoryController();
      await controller.clearSavedHistory();
      addTearDown(() {
        controller.dispose();
        controller.edge.dispose();
        controller.solax!.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryPage(controller: controller, openSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AC production power').hitTestable(), findsOneWidget);
      expect(
        find.text('No power history loaded for this day.'),
        findsOneWidget,
      );
      expect(
        find.text('SolarEdge: Next request available in 15 minutes.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loaded graphs fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = await savedHistoryController();
    addTearDown(() {
      controller.dispose();
      controller.edge.dispose();
      controller.solax!.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryPage(controller: controller, openSettings: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('AC production power').hitTestable(),
      250,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Readings in W').hitTestable(),
      150,
    );
    await tester.tap(find.text('Readings in W'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
