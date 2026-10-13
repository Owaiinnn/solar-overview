import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/production_total.dart';
import 'package:solar_overview/src/solar_scene.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax.dart';

import 'home_test.dart' show scene;
import 'overview_test.dart' show edgeController, solaxController;
import 'solax_fakes.dart';

void main() {
  testWidgets(
    'shooting stars repeat every thirty active seconds and respect motion state',
    (tester) async {
      Future<void> show({
        bool active = true,
        bool reduced = false,
        bool loading = false,
        SolarProductionState production = SolarProductionState.zero,
      }) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: SolarScene(
              active: active,
              production: production,
              loading: loading,
            ),
          ),
        ),
      );
      await show();
      await tester.pump(const Duration(seconds: 28));
      expect(scene(tester).shootingStarProgress, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(scene(tester).shootingStarProgress, closeTo(1 / 3, .001));
      await show(active: false);
      await tester.pump(const Duration(seconds: 31));
      expect(scene(tester).shootingStarProgress, closeTo(1 / 3, .001));
      await show();
      await tester.pump(const Duration(seconds: 1));
      expect(scene(tester).shootingStarProgress, isNull);
      await tester.pump(const Duration(seconds: 29));
      expect(scene(tester).shootingStarProgress, closeTo(1 / 3, .001));
      await tester.pump(const Duration(seconds: 1));
      expect(scene(tester).shootingStarProgress, isNull);
      await show(reduced: true);
      await tester.pump(const Duration(seconds: 59));
      expect(scene(tester).shootingStarProgress, isNull);
      expect(scene(tester).phase.value, 0);
      await show(loading: true);
      await tester.pump(const Duration(seconds: 29));
      expect(scene(tester).shootingStarProgress, isNull);
      await show(production: SolarProductionState.positive);
      await tester.pump(const Duration(seconds: 29));
      expect(scene(tester).shootingStarProgress, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('six sky paths alternate at thirty second intervals', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SolarScene(active: true, production: SolarProductionState.zero),
      ),
    );
    final paths = <({Offset start, Offset end})>{};
    await tester.pump(const Duration(seconds: 29));
    final first = scene(tester).shootingStarPath;
    for (var i = 0; i < 6; i++) {
      final painter = scene(tester);
      expect(painter.shootingStarProgress, closeTo(1 / 3, .001));
      expect(paths.add(painter.shootingStarPath), isTrue);
      for (final point in [
        painter.shootingStarPath.start,
        painter.shootingStarPath.end,
      ]) {
        expect(point.dx, inInclusiveRange(6, 354));
        expect(point.dy, inInclusiveRange(6, 169));
      }
      await tester.pump(const Duration(seconds: 1));
      expect(scene(tester).shootingStarProgress, isNull);
      await tester.pump(const Duration(seconds: 29));
    }
    expect(scene(tester).shootingStarPath, first);
    expect(scene(tester).shootingStarProgress, closeTo(1 / 3, .001));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Home theme follows both sources and stays scoped to Home', (
    tester,
  ) async {
    final edge = await edgeController(power: 0);
    final solax = await solaxController(power: 0);
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(NavigationBar))).brightness;
    await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
    expect(brightness(), Brightness.dark);
    expect(find.byType(AppBar), findsNothing);
    solax.error = 'Network unavailable';
    solax.updateFreshness();
    await tester.pump();
    expect(brightness(), Brightness.light);
    expect(scene(tester).production, SolarProductionState.partialZero);
    solax.error = null;
    solax.updateFreshness();
    await tester.pump();
    expect(brightness(), Brightness.dark);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(brightness(), Brightness.dark);
    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(find.byTooltip('Back to Home'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pump();
    expect(brightness(), Brightness.dark);
    expect(find.byType(AppBar), findsNothing);
    await tester.tap(find.text('Appliances'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pump();
    final label = find.text('View details');
    final expectedColor = Theme.of(tester.element(label)).colorScheme.onPrimary;
    for (final elapsed in [
      Duration.zero,
      const Duration(milliseconds: 16),
      const Duration(milliseconds: 100),
    ]) {
      await tester.pump(elapsed);
      final rendered = tester.widget<RichText>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect(rendered.text.style?.color, expectedColor);
      final coverage = find.text('SolarEdge + SolaX · 2 of 2 sources');
      final renderedCoverage = tester.widget<RichText>(
        find.descendant(of: coverage, matching: find.byType(RichText)),
      );
      expect(
        renderedCoverage.text.style?.color,
        Theme.of(tester.element(coverage)).colorScheme.onSurface,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  for (final problem in [
    'missing',
    'stale',
    'unknown time',
    'future',
    'skew',
    'failure',
    'storage',
    'removed',
    'disconnected',
  ]) {
    testWidgets('zero plus $problem never implies complete zero', (
      tester,
    ) async {
      final edge = await edgeController(power: 0);
      final solax = await solaxController(
        power: problem == 'missing' ? null : 0,
        stamp: switch (problem) {
          'stale' => '2026-09-29T11:30:00Z',
          'unknown time' => null,
          'future' => '2026-09-29T12:00:01Z',
          'skew' => '2026-09-29T11:54:59Z',
          _ => '2026-09-29T12:00:00Z',
        },
      );
      if (problem == 'failure') solax.error = 'Network unavailable';
      if (problem == 'storage') solax.storageUnavailable = true;
      if (problem == 'removed') {
        await solax.disconnect();
      }
      await tester.pumpWidget(
        SolarApp(
          controller: edge,
          solax: problem == 'disconnected' ? null : solax,
        ),
      );
      expect(
        scene(tester).production,
        problem == 'skew'
            ? SolarProductionState.unavailable
            : SolarProductionState.partialZero,
      );
      expect(
        find.bySemanticsLabel(RegExp('Decorative zero-production')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'positive, complete zero, loading and refresh failure transition',
    (tester) async {
      var now = solaxNow;
      final source = FakeSolaxSource()
        ..failure = const SolaxFailure('Network unavailable');
      final edge = await edgeController(power: 1000, now: () => now);
      final solax = await solaxController(
        power: 0,
        source: source,
        now: () => now,
      );
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      expect(scene(tester).production, SolarProductionState.positive);
      edge.overview = const SolarOverview(
        powerWatts: 0,
        reportedAt: '2026-09-29 14:00:00',
        timeZone: 'Europe/Amsterdam',
      );
      edge.updateFreshness();
      await tester.pump();
      expect(find.text('0.00 kW'), findsOneWidget);
      expect(scene(tester).production, SolarProductionState.zero);
      edge.busy = true;
      edge.updateFreshness();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(scene(tester).production, SolarProductionState.zero);
      expect(scene(tester).houseLift, greaterThan(9));
      edge.busy = false;
      edge.updateFreshness();
      now = now.add(const Duration(minutes: 15));
      await solax.refresh();
      await tester.pump();
      expect(source.readingCalls, 1);
      expect(solax.reading?.powerWatts, 0);
      expect(scene(tester).production, SolarProductionState.partialZero);
      expect(scene(tester).houseLift, 0);
      expect(
        find.text('No production reported by this source.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'zero scene stays still for either accessibility motion preference',
    (tester) async {
      for (final accessible in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: !accessible,
                accessibleNavigation: accessible,
              ),
              child: const SolarScene(
                active: true,
                production: SolarProductionState.zero,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(scene(tester).phase.value, 0);
        await tester.pump(const Duration(seconds: 13));
        expect(scene(tester).phase.value, 0);
        expect(scene(tester).production, SolarProductionState.zero);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'zero scene pauses in Details and background, resumes without requests',
    (tester) async {
      final edge = await edgeController(power: 0);
      final source = FakeSolaxSource();
      final solax = await solaxController(power: 0, source: source);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      expect(
        find.bySemanticsLabel(RegExp('Decorative zero-production scene')),
        findsOneWidget,
      );
      final phase = scene(tester).phase;
      await tester.pump(const Duration(seconds: 3));
      expect(phase.value, closeTo(3 / 180, .001));
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      final paused = phase.value;
      await tester.pump(const Duration(seconds: 2));
      expect(phase.value, paused);
      await tester.tap(find.byTooltip('Back to Home'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(phase.value, isNot(paused));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final background = phase.value;
      await tester.pump(const Duration(seconds: 2));
      expect(phase.value, background);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(phase.value, isNot(background));
      expect(source.readingCalls, 0);
      expect(source.authCalls, 0);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'zero scene and source labels fit a small phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final edge = await edgeController(power: 0);
      final solax = await solaxController(power: 0);
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
      expect(find.text('No production reported.'), findsOneWidget);
      expect(scene(tester).production, SolarProductionState.zero);
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Your solar readings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
