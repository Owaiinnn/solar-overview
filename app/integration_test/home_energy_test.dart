import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/p1.dart';

import '../test/fakes.dart';
import '../test/home_energy_fakes.dart';
import '../test/home_test.dart' show scene;
import '../test/overview_test.dart' show edgeController, solaxController;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('native independent energy gallery and navigation', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final scenarios = [
      (
        name: 'positive-charge-export',
        solar: 1000.0,
        battery: BatteryState.charging,
        grid: GridDirection.exporting,
      ),
      (
        name: 'zero-charge-import',
        solar: 0.0,
        battery: BatteryState.charging,
        grid: GridDirection.importing,
      ),
      (
        name: 'zero-discharge-export',
        solar: 0.0,
        battery: BatteryState.discharging,
        grid: GridDirection.exporting,
      ),
      (
        name: 'zero-idle-balanced',
        solar: 0.0,
        battery: BatteryState.idle,
        grid: GridDirection.balanced,
      ),
      (
        name: 'positive-unavailable-import',
        solar: 1000.0,
        battery: BatteryState.unknown,
        grid: GridDirection.importing,
      ),
      (
        name: 'partial-zero-charge-import',
        solar: 0.0,
        battery: BatteryState.charging,
        grid: GridDirection.importing,
      ),
      (
        name: 'empty-solar-discharge-export',
        solar: null,
        battery: BatteryState.discharging,
        grid: GridDirection.exporting,
      ),
      (
        name: 'positive-idle-import',
        solar: 1000.0,
        battery: BatteryState.idle,
        grid: GridDirection.importing,
      ),
      (
        name: 'positive-idle-export',
        solar: 1000.0,
        battery: BatteryState.idle,
        grid: GridDirection.exporting,
      ),
      (
        name: 'saved-local-positive-solar',
        solar: 1000.0,
        battery: BatteryState.charging,
        grid: GridDirection.importing,
      ),
    ];
    for (final scenario in scenarios) {
      final edge = scenario.solar == null
          ? (ConnectionController(MemoryStore(), FakeSource())
              ..initialized = true)
          : await edgeController(power: scenario.solar);
      if (scenario.solar == null) addTearDown(edge.dispose);
      final solax = await solaxController(
        power: scenario.name.startsWith('partial') ? null : scenario.solar,
      );
      final saved = scenario.name.startsWith('saved');
      final battery = await homeBattery(state: scenario.battery, saved: saved);
      final grid = await homeGrid(direction: scenario.grid, saved: saved);
      await tester.pumpWidget(
        SolarApp(
          controller: edge,
          solax: scenario.solar == null ? null : solax,
          battery: battery,
          p1: grid,
        ),
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await binding.takeScreenshot(scenario.name);
      await tester.ensureVisible(find.text('View details'));
      await binding.takeScreenshot('${scenario.name}-labels');
      final animation = scene(tester).flow;
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      final frozen = animation.value;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(animation.value, frozen);
      await tester.tap(find.byTooltip('Back to Home'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      battery.dispose();
      grid.dispose();
    }
  });
}
