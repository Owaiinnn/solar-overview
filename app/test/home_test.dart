import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';

import 'package:solar_overview/src/solar_scene.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';
import 'reliability_test.dart' show PendingSource;

import 'overview_test.dart' show edgeController, solaxController;
import 'solax_fakes.dart';

SolarScenePainter scene(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(SolarScene),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as SolarScenePainter;

void main() {
  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home is readable at $size and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final edge = await edgeController();
        final solax = await solaxController();
        await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
        expect(find.text('1.12 kW'), findsOneWidget);
        expect(find.text('SolarEdge + SolaX · 2 of 2 sources'), findsOneWidget);
        if (scale == 1) {
          final button = tester.getRect(find.text('View details'));
          final nav = tester.getRect(find.byType(NavigationBar));
          expect(button.bottom, lessThan(nav.top));
        }
        await tester.ensureVisible(find.text('View details'));
        await tester.tap(find.text('View details'));
        await tester.pumpAndSettle();
        expect(find.text('Your solar readings'), findsOneWidget);
        await tester.tap(find.byTooltip('Back to Home'));
        await tester.pump();
        expect(find.text('1.12 kW'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
    'Home shares guarded totals for zero, missing, skew, stale and offline',
    (tester) async {
      for (final state in ['zero', 'missing', 'skew', 'stale', 'offline']) {
        final edge = await edgeController(power: state == 'zero' ? 0 : 1000);
        final solax = await solaxController(
          power: state == 'zero'
              ? 0
              : state == 'missing'
              ? null
              : 120,
          stamp: state == 'skew'
              ? '2026-09-29T11:54:00Z'
              : state == 'stale'
              ? '2026-09-29T11:00:00Z'
              : '2026-09-29T12:00:00Z',
        );
        if (state == 'offline') solax.error = 'Network unavailable';
        await tester.pumpWidget(
          SolarApp(key: ValueKey(state), controller: edge, solax: solax),
        );
        if (state == 'zero') {
          expect(find.text('0.00 kW'), findsOneWidget);
          expect(find.text('No production reported.'), findsOneWidget);
          expect(scene(tester).producing, isFalse);
        } else if (state == 'skew') {
          expect(find.text('Unavailable'), findsOneWidget);
          expect(
            find.textContaining('Source times are over 5 minutes'),
            findsOneWidget,
          );
          expect(scene(tester).producing, isFalse);
        } else {
          expect(find.text('1.00 kW'), findsOneWidget);
          expect(find.text('SolarEdge only · 1 of 2 sources'), findsOneWidget);
          if (state == 'stale') {
            expect(find.text('SolaX · Stale'), findsOneWidget);
          }
          if (state == 'offline') {
            expect(find.text('SolaX · Needs attention'), findsOneWidget);
          }
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'loop repeats, pauses offscreen/background, and navigation never fetches',
    (tester) async {
      var now = solaxNow;
      final edge = await edgeController(now: () => now);
      final source = FakeSolaxSource();
      final solax = await solaxController(source: source, now: () => now);
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      final animation = scene(tester).phase;
      await tester.pump(const Duration(milliseconds: 700));
      expect(animation.value, greaterThan(0));
      await tester.pump(const Duration(seconds: 6));
      expect(animation.value, greaterThan(0));
      expect(animation.value, lessThan(1));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      final paused = animation.value;
      await tester.pump(const Duration(seconds: 2));
      expect(animation.value, paused);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Your solar home'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(animation.value, isNot(paused));
      for (final tab in ['Settings', 'History', 'Appliances']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        final offscreen = animation.value;
        await tester.pump(const Duration(seconds: 1));
        expect(animation.value, offscreen);
      }
      await tester.tap(find.text('Home'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final background = animation.value;
      await tester.pump(const Duration(seconds: 2));
      expect(animation.value, background);
      now = now.add(const Duration(minutes: 31));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(animation.value, isNot(background));
      expect(find.text('Unavailable'), findsOneWidget);
      expect(scene(tester).producing, isFalse);
      expect(source.readingCalls, 0);
      expect(source.authCalls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion is static and resumes when preference changes', (
    tester,
  ) async {
    Future<void> show(bool reduced) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const SolarScene(active: true, producing: true),
        ),
      ),
    );
    await show(true);
    await tester.pumpAndSettle();
    final animation = scene(tester).phase;
    expect(animation.value, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(animation.value, 0);
    await show(false);
    await tester.pump(const Duration(seconds: 1));
    expect(animation.value, greaterThan(0));
    await show(true);
    await tester.pumpAndSettle();
    expect(animation.value, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('loading and empty connections do not invent production', (
    tester,
  ) async {
    final source = FakeSource();
    final edge = ConnectionController(MemoryStore(), source);
    await tester.pumpWidget(SolarApp(controller: edge));
    expect(find.text('Fetching your solar readings…'), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    expect(scene(tester).loading, isTrue);
    expect(scene(tester).producing, isFalse);
    await edge.initialize();
    await tester.pump();
    expect(find.text('SolarEdge · Not connected'), findsOneWidget);
    expect(scene(tester).loading, isFalse);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('SolaX · Not connected'), findsOneWidget);
    expect(find.textContaining('0.00'), findsNothing);
    expect(source.calls, 0);
    await tester.pumpWidget(const SizedBox());
    edge.dispose();
  });

  testWidgets('ancestor ticker mode suspends the scene', (tester) async {
    Future<void> show(bool enabled) => tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: enabled,
          child: const SolarScene(active: true, producing: false),
        ),
      ),
    );
    await show(true);
    final animation = scene(tester).phase;
    await tester.pump(const Duration(seconds: 1));
    expect(animation.value, greaterThan(0));
    await show(false);
    final stopped = animation.value;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(animation.value, stopped);
    await show(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(animation.value, isNot(stopped));
    await tester.pumpWidget(const SizedBox());
  });
  for (final fails in [false, true]) {
    testWidgets(
      'startup bounce ends when the request ${fails ? 'fails' : 'succeeds'}',
      (tester) async {
        final source = PendingSource();
        final edge = ConnectionController(
          MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey),
          source,
          now: () => solaxNow,
        );
        final opening = edge.initialize();
        await tester.pumpWidget(SolarApp(controller: edge));
        expect(find.text('Loading…'), findsOneWidget);
        expect(find.text('Checking your solar sources'), findsOneWidget);
        expect(find.text('Unavailable'), findsNothing);
        expect(scene(tester).loading, isTrue);
        await tester.pump(const Duration(milliseconds: 750));
        expect(scene(tester).houseLift, greaterThan(9));
        await tester.pump(const Duration(milliseconds: 750));
        expect(scene(tester).houseLift, closeTo(0, .01));
        if (fails) {
          source.result.completeError(
            const SolarEdgeFailure('Network unavailable.'),
          );
        } else {
          source.result.complete(
            const SolarOverview(
              powerWatts: 1000,
              reportedAt: '2026-09-29 12:00:00',
              timeZone: 'UTC',
            ),
          );
        }
        await opening;
        await tester.pump();
        expect(find.text('Loading…'), findsNothing);
        expect(find.text(fails ? 'Unavailable' : '1.00 kW'), findsOneWidget);
        expect(scene(tester).loading, isFalse);
        expect(scene(tester).houseLift, 0);
        expect(source.calls, 1);
        await tester.pumpWidget(const SizedBox());
        edge.dispose();
      },
    );
  }

  testWidgets('an eligible source stays visible while the other opens', (
    tester,
  ) async {
    final pending = PendingSource();
    final edge = ConnectionController(
      MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey),
      pending,
    );
    final opening = edge.initialize();
    final solax = await solaxController();
    await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
    expect(find.text('0.12 kW'), findsOneWidget);
    expect(find.text('SolaX only · 1 of 2 sources'), findsOneWidget);
    expect(find.text('Fetching your solar readings…'), findsOneWidget);
    expect(scene(tester).loading, isTrue);
    pending.result.completeError(
      const SolarEdgeFailure('Network unavailable.'),
    );
    await opening;
    await tester.pump();
    expect(find.text('0.12 kW'), findsOneWidget);
    expect(scene(tester).loading, isFalse);
    await tester.pumpWidget(const SizedBox());
    edge.dispose();
  });

  testWidgets('loading bounce respects reduced motion and backgrounding', (
    tester,
  ) async {
    Future<void> show(bool reduced) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const SolarScene(
            active: true,
            producing: false,
            loading: true,
          ),
        ),
      ),
    );
    await show(true);
    await tester.pumpAndSettle();
    expect(scene(tester).houseLift, 0);
    await show(false);
    await tester.pump(const Duration(milliseconds: 750));
    expect(scene(tester).houseLift, greaterThan(9));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final frozen = scene(tester).houseLift;
    await tester.pump(const Duration(milliseconds: 750));
    expect(scene(tester).houseLift, frozen);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(scene(tester).houseLift, isNot(frozen));
    await tester.pumpWidget(const SizedBox());
  });
}
