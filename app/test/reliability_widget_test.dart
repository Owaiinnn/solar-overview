import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'visible freshness and today energy age while open without polling',
    (tester) async {
      var now = DateTime.utc(2026, 9, 28, 21, 59);
      final source = FakeSource()
        ..reading = const SolarOverview(
          powerWatts: 0,
          energyWh: 1200,
          reportedAt: '2026-09-28 23:30:00',
          timeZone: 'Europe/Amsterdam',
        );
      final controller = ConnectionController(
        MemoryStore(),
        source,
        now: () => now,
      );
      await controller.initialize();
      await controller.connect('123', fakeKey);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(SolarApp(controller: controller));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      expect(find.text('Recent SolarEdge reading'), findsOneWidget);
      expect(find.text('1.20 kWh'), findsOneWidget);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.textContaining('Stale SolarEdge'), findsOneWidget);
      expect(find.text('1.20 kWh'), findsNothing);
      expect(find.text('0.00 kW'), findsOneWidget);
      expect(source.calls, 1);
    },
  );

  testWidgets(
    'offline cache and errors remain readable on small screens with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      final credentials = MemoryStore()
        ..saved = SolarEdgeCredentials('123', fakeKey);
      final cache = MemoryReadingStore()
        ..cache = ReadingCache(
          siteId: '123',
          overview: const SolarOverview(
            powerWatts: 5,
            energyWh: 1200,
            reportedAt: '2026-09-27 12:00:00',
            timeZone: 'Europe/Amsterdam',
          ),
          fetchedAt: DateTime.utc(2026, 9, 27, 10),
        );
      final source = FakeSource()..reject = true;
      final controller = ConnectionController(
        credentials,
        source,
        readingStore: cache,
        now: () => DateTime.utc(2026, 9, 28, 12),
      );
      await controller.initialize();
      await tester.pumpWidget(SolarApp(controller: controller));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Connection rejected.'), 200);
      expect(find.text('Connection rejected.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Showing saved readings'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Showing saved readings'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Refresh readings'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Refresh readings'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resuming recalculates freshness without fetching', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 28, 12);
    final source = FakeSource()
      ..reading = const SolarOverview(
        powerWatts: 1,
        reportedAt: '2026-09-28 14:00:00',
        timeZone: 'Europe/Amsterdam',
      );
    final controller = ConnectionController(
      MemoryStore(),
      source,
      now: () => now,
    );
    await controller.initialize();
    await controller.connect('123', fakeKey);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(SolarApp(controller: controller));
    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.textContaining('Stale SolarEdge'), findsOneWidget);
    expect(source.calls, 1);
  });
}
