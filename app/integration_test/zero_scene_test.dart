import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/production_total.dart';
import 'package:solar_overview/src/solaredge.dart';

import '../test/home_test.dart' show scene;
import '../test/overview_test.dart' show edgeController, solaxController;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('native zero, loading, positive and partial Home scenes', (
    tester,
  ) async {
    final edge = await edgeController(power: 0);
    final solax = await solaxController(power: 0);
    await tester.pumpWidget(SolarApp(controller: edge, solax: solax));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(scene(tester).production, SolarProductionState.zero);
    await binding.takeScreenshot('zero');
    await Future<void>.delayed(const Duration(seconds: 3));
    await binding.takeScreenshot('zero-twinkle');
    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Your solar readings'), findsOneWidget);
    await binding.takeScreenshot('details');
    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pump();
    expect(scene(tester).production, SolarProductionState.zero);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('settings');
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.tap(find.text('Appliances'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pump();
    await binding.takeScreenshot('home-return');
    edge.busy = true;
    edge.updateFreshness();
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(scene(tester).loading, isTrue);
    await binding.takeScreenshot('zero-loading');
    edge.busy = false;
    edge.overview = const SolarOverview(
      powerWatts: 1800,
      reportedAt: '2026-09-29 14:00:00',
      timeZone: 'Europe/Amsterdam',
    );
    edge.updateFreshness();
    await tester.pump();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(scene(tester).production, SolarProductionState.positive);
    await binding.takeScreenshot('positive');
    edge.error = 'Network unavailable';
    edge.updateFreshness();
    await tester.pump();
    expect(scene(tester).production, SolarProductionState.partialZero);
    await binding.takeScreenshot('partial-zero');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
