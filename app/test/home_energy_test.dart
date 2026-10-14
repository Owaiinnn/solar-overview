import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/battery_store.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/home_energy.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/p1_store.dart';
import 'package:solar_overview/src/production_total.dart';
import 'package:solar_overview/src/solar_scene.dart';

import 'battery_fakes.dart';
import 'fakes.dart';
import 'home_energy_fakes.dart';
import 'home_test.dart' show scene;
import 'overview_test.dart' show edgeController, solaxController;
import 'p1_fakes.dart';
import 'solax_fakes.dart';

void main() {
  for (final solar in [
    'positive',
    'partial positive',
    'zero',
    'partial zero',
    'unavailable',
    'empty',
  ]) {
    testWidgets('all battery × grid states with $solar solar', (tester) async {
      final empty = solar == 'empty';
      final edge = empty
          ? (ConnectionController(MemoryStore(), FakeSource())
              ..initialized = true)
          : await edgeController(
              power: solar.contains('positive')
                  ? 1000
                  : solar.contains('zero')
                  ? 0
                  : null,
            );
      if (empty) addTearDown(edge.dispose);
      final solax = await solaxController(
        power: solar == 'positive'
            ? 120
            : solar == 'zero'
            ? 0
            : null,
      );
      for (final batteryState in [...BatteryState.values, null]) {
        for (final gridState in [...GridDirection.values, null]) {
          final battery = await homeBattery(
            state: batteryState ?? BatteryState.unknown,
            connected: batteryState != null,
          );
          final grid = await homeGrid(
            direction: gridState ?? GridDirection.unavailable,
            connected: gridState != null,
          );
          await tester.pumpWidget(
            SolarApp(
              controller: edge,
              solax: empty ? null : solax,
              battery: battery,
              p1: grid,
            ),
          );
          final painter = scene(tester);
          expect(painter.production, switch (solar) {
            'positive' || 'partial positive' => SolarProductionState.positive,
            'zero' => SolarProductionState.zero,
            'partial zero' => SolarProductionState.partialZero,
            _ => SolarProductionState.unavailable,
          });
          expect(painter.battery.visible, batteryState != null);
          expect(painter.grid.visible, gridState != null);
          expect(
            painter.battery.moving,
            batteryState == BatteryState.charging ||
                batteryState == BatteryState.discharging,
          );
          expect(
            painter.grid.moving,
            gridState == GridDirection.importing ||
                gridState == GridDirection.exporting,
          );
          if (batteryState != null) {
            expect(find.text(painter.battery.status), findsWidgets);
            expect(find.text('60%'), findsOneWidget);
          }
          if (gridState != null) {
            expect(find.text(painter.grid.status), findsWidgets);
          }
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          battery.dispose();
          grid.dispose();
        }
      }
    });
  }

  for (final source in ['battery', 'grid', 'SolarEdge', 'SolaX']) {
    for (final problem in [
      'loading',
      'refreshing',
      'saved',
      'stale',
      'missing',
      'failed',
      'storage',
      'future',
      'skew',
    ]) {
      testWidgets('$problem affects only $source', (tester) async {
        var batteryTime = solaxNow;
        var gridTime = solaxNow;
        final battery = await homeBattery(
          saved: source == 'battery' && problem == 'saved',
          now: () => batteryTime,
        );
        final grid = await homeGrid(
          saved: source == 'grid' && problem == 'saved',
          now: () => gridTime,
        );
        final edge = await edgeController(
          power: source == 'SolarEdge' && problem == 'missing' ? null : 1000,
          stamp: source == 'SolarEdge'
              ? switch (problem) {
                  'stale' => '2026-09-29 13:00:00',
                  'future' => '2026-09-29 14:00:01',
                  'skew' => '2026-09-29 13:54:59',
                  _ => '2026-09-29 14:00:00',
                }
              : '2026-09-29 14:00:00',
        );
        final solax = await solaxController(
          power: source == 'SolaX' && problem == 'missing' ? null : 120,
          stamp: source == 'SolaX'
              ? switch (problem) {
                  'stale' => '2026-09-29T11:00:00Z',
                  'future' => '2026-09-29T12:00:01Z',
                  'skew' => '2026-09-29T11:54:59Z',
                  _ => '2026-09-29T12:00:00Z',
                }
              : '2026-09-29T12:00:00Z',
        );
        if (source == 'battery') {
          if (problem == 'loading') battery.initialized = false;
          if (problem == 'refreshing') battery.busy = true;
          if (problem == 'failed') battery.error = 'Network unavailable';
          if (problem == 'storage') battery.storageUnavailable = true;
          if (problem == 'stale' || problem == 'skew') {
            batteryTime = batteryTime.add(const Duration(seconds: 90));
          }
          if (problem == 'future') {
            batteryTime = batteryTime.subtract(const Duration(seconds: 1));
          }
          if (problem == 'missing') {
            final store = battery.store as MemoryBatteryStore;
            store.saved = BatteryRecord(
              address: store.saved.address,
              nextAttempt: solaxNow.add(const Duration(minutes: 5)),
            );
            await battery.initialize();
          }
        } else if (source == 'grid') {
          if (problem == 'loading') grid.initialized = false;
          if (problem == 'refreshing') grid.busy = true;
          if (problem == 'failed') grid.error = 'Network unavailable';
          if (problem == 'storage') grid.storageUnavailable = true;
          if (problem == 'stale' || problem == 'skew') {
            gridTime = gridTime.add(const Duration(seconds: 90));
          }
          if (problem == 'future') {
            gridTime = gridTime.subtract(const Duration(seconds: 6));
          }
          if (problem == 'missing') {
            final store = grid.store as MemoryP1Store;
            store.saved = P1Record(
              address: store.saved.address,
              nextAttempt: solaxNow.add(const Duration(minutes: 5)),
            );
            await grid.initialize();
          }
        } else if (source == 'SolarEdge') {
          if (problem == 'loading') edge.initialized = false;
          if (problem == 'refreshing') edge.busy = true;
          if (problem == 'failed') edge.error = 'Network unavailable';
          if (problem == 'storage') edge.storageUnavailable = true;
        } else {
          if (problem == 'loading') solax.initialized = false;
          if (problem == 'refreshing') solax.busy = true;
          if (problem == 'failed') solax.error = 'Network unavailable';
          if (problem == 'storage') solax.storageUnavailable = true;
        }
        await tester.pumpWidget(
          SolarApp(controller: edge, solax: solax, battery: battery, p1: grid),
        );
        final painter = scene(tester);
        expect(
          painter.battery.moving,
          source != 'battery' || problem == 'refreshing',
        );
        expect(
          painter.grid.moving,
          source != 'grid' || problem == 'refreshing',
        );
        if (source == 'battery' || source == 'grid') {
          expect(find.text('1.12 kW'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        battery.dispose();
        grid.dispose();
      });
    }
  }

  for (final percent in [null, 0.0, 42.0, 100.0]) {
    for (final state in BatteryState.values) {
      test('SOC $percent never determines $state', () async {
        final controller = await homeBattery(percent: percent, state: state);
        final value = HomeBatteryState.fromController(controller);
        expect(value.percent, percent);
        expect(value.reportedState, state);
        expect(
          value.moving,
          state == BatteryState.charging || state == BatteryState.discharging,
        );
        controller.dispose();
      });
    }
  }

  test('inconsistent directions and zero power never animate', () {
    for (final state in [
      BatteryState.charging,
      BatteryState.discharging,
      BatteryState.idle,
    ]) {
      for (final power in [-100.0, 0.0, 100.0]) {
        final reading = BatteryReading.fromJson({
          '9405': 50,
          '6000': power,
          '6001': switch (state) {
            BatteryState.charging => 1001,
            BatteryState.discharging => 1002,
            _ => 1000,
          },
        });
        final battery = HomeBatteryState(
          quality: LocalReadingQuality.recent,
          state: state,
          packWatts: power,
          conflict: reading.statePowerConflict,
        );
        expect(
          battery.moving,
          state == BatteryState.charging && power < 0 ||
              state == BatteryState.discharging && power > 0,
        );
      }
    }
    for (final direction in GridDirection.values) {
      for (final watts in [null, -100, 0, 100]) {
        final grid = HomeGridState(
          quality: LocalReadingQuality.recent,
          direction: direction,
          watts: watts,
        );
        expect(
          grid.moving,
          direction == GridDirection.importing && watts == 100 ||
              direction == GridDirection.exporting && watts == -100,
        );
      }
    }
  });

  testWidgets(
    'local animation remains independent of solar loading and stops with motion policy',
    (tester) async {
      const battery = HomeBatteryState(
        quality: LocalReadingQuality.recent,
        state: BatteryState.charging,
        packWatts: -200,
        percent: 60,
      );
      const grid = HomeGridState(
        quality: LocalReadingQuality.recent,
        direction: GridDirection.importing,
        watts: 300,
      );
      for (final production in SolarProductionState.values) {
        Future<void> show({
          bool active = true,
          bool reduced = false,
          bool accessible = false,
          bool enabled = true,
          bool loading = false,
        }) => tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: reduced,
                accessibleNavigation: accessible,
              ),
              child: TickerMode(
                enabled: enabled,
                child: SolarScene(
                  active: active,
                  production: production,
                  loading: loading,
                  battery: battery,
                  grid: grid,
                ),
              ),
            ),
          ),
        );
        await show(loading: true);
        await tester.pump(const Duration(milliseconds: 750));
        expect(scene(tester).houseLift, greaterThan(9));
        expect(scene(tester).flow.value, greaterThan(0));
        await show(active: false);
        final stopped = scene(tester).flow.value;
        await tester.pump(const Duration(seconds: 1));
        expect(scene(tester).flow.value, stopped);
        await show();
        await tester.pump(const Duration(milliseconds: 400));
        expect(scene(tester).flow.value, isNot(stopped));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        final paused = scene(tester).flow.value;
        await tester.pump(const Duration(seconds: 1));
        expect(scene(tester).flow.value, paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await show(enabled: false);
        final disabled = scene(tester).flow.value;
        await tester.pump(const Duration(seconds: 1));
        expect(scene(tester).flow.value, disabled);
        for (final accessible in [false, true]) {
          await show(reduced: !accessible, accessible: accessible);
          await tester.pumpAndSettle();
          expect(scene(tester).flow.value, 0);
          expect(scene(tester).battery.status, 'Charging');
          expect(scene(tester).grid.status, 'Importing');
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'real controller refresh failure retains qualified SOC and healthy grid',
    (tester) async {
      var now = solaxNow;
      final source = FakeBatterySource();
      final battery = await homeBattery(source: source, now: () => now);
      final grid = await homeGrid();
      final edge = await edgeController();
      await tester.pumpWidget(
        SolarApp(controller: edge, battery: battery, p1: grid),
      );
      now = now.add(const Duration(seconds: 30));
      source.pending = Completer<BatteryReading>();
      final refresh = battery.refresh();
      await tester.pump();
      expect(scene(tester).battery.moving, isTrue);
      source.pending!.completeError(
        const BatteryFailure('Network unavailable'),
      );
      await refresh;
      await tester.pump();
      expect(find.text('Last known · 60%'), findsOneWidget);
      expect(scene(tester).battery.moving, isFalse);
      expect(scene(tester).grid.moving, isTrue);
      await tester.pumpWidget(const SizedBox());
      battery.dispose();
      grid.dispose();
    },
  );

  testWidgets(
    'direction changes reuse local controllers without changing solar or request gates',
    (tester) async {
      var now = solaxNow;
      final batterySource = FakeBatterySource();
      final gridSource = FakeP1Source(now: () => now);
      final battery = await homeBattery(source: batterySource, now: () => now);
      final grid = await homeGrid(source: gridSource, now: () => now);
      final edge = await edgeController(power: 0);
      final solax = await solaxController(power: 0);
      await tester.pumpWidget(
        SolarApp(controller: edge, solax: solax, battery: battery, p1: grid),
      );
      for (final state in [
        BatteryState.discharging,
        BatteryState.idle,
        BatteryState.charging,
      ]) {
        now = now.add(const Duration(seconds: 30));
        batterySource.result = batteryReading(
          state: state == BatteryState.discharging
              ? 1002
              : state == BatteryState.idle
              ? 1000
              : 1001,
          power: state == BatteryState.discharging
              ? 520
              : state == BatteryState.idle
              ? 0
              : -520,
        );
        gridSource.value = p1Reading(
          at: now,
          importKw: state == BatteryState.charging ? '01.200' : '00.000',
          exportKw: state == BatteryState.discharging ? '00.520' : '00.000',
        );
        await Future.wait([battery.refresh(), grid.refresh()]);
        await tester.pump();
        expect(scene(tester).battery.reportedState, state);
        expect(
          scene(tester).grid.direction,
          state == BatteryState.discharging
              ? GridDirection.exporting
              : state == BatteryState.idle
              ? GridDirection.balanced
              : GridDirection.importing,
        );
        expect(scene(tester).production, SolarProductionState.zero);
        expect(scene(tester).battery.moving, state != BatteryState.idle);
        expect(scene(tester).grid.moving, state != BatteryState.idle);
      }
      final requests = (batterySource.calls, gridSource.calls);
      final waits = (battery.wait, grid.wait);
      final flow = scene(tester).flow;
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      final stopped = flow.value;
      await tester.pump(const Duration(seconds: 3));
      expect(flow.value, stopped);
      await tester.tap(find.byTooltip('Back to Home'));
      await tester.pump();
      expect((batterySource.calls, gridSource.calls), requests);
      expect((battery.wait, grid.wait), waits);
      await tester.pumpWidget(const SizedBox());
      battery.dispose();
      grid.dispose();
    },
  );

  for (final production in [0.0, 1000.0]) {
    testWidgets(
      'local labels and Details are accessible on a small phone at large text, power $production',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final edge = await edgeController(power: production);
        final solax = await solaxController(power: production);
        final battery = await homeBattery();
        final grid = await homeGrid();
        await tester.pumpWidget(
          SolarApp(controller: edge, solax: solax, battery: battery, p1: grid),
        );
        await tester.ensureVisible(find.text('Charging'));
        expect(
          find.bySemanticsLabel(RegExp('Battery. 60%. Charging.')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Importing'));
        expect(
          find.bySemanticsLabel(RegExp('Grid. Importing. 1.20 kW.')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('View details'));
        await tester.tap(find.text('View details'));
        await tester.pumpAndSettle();
        expect(find.text('Your solar readings'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        battery.dispose();
        grid.dispose();
        semantics.dispose();
      },
    );
  }
}
