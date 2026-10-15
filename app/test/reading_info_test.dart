import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/overview.dart';

import 'home_energy_fakes.dart';
import 'overview_test.dart' show edgeController, solaxController;

void main() {
  testWidgets(
    'each Details card keeps explanations behind accessible info buttons',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final edge = await edgeController();
      final solax = await solaxController();
      final battery = await homeBattery(saved: true);
      final grid = await homeGrid(saved: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              controller: edge,
              solax: solax,
              battery: battery,
              p1: grid,
              openSettings: () {},
              configuredOnly: true,
            ),
          ),
        ),
      );
      for (final entry in {
        'Combined solar production': 'Uses reported solar-only AC output',
        'SolarEdge panels': 'Cloud readings may lag',
        'SolaX panels': 'Device energy counters may reset',
        'P1 grid meter': 'Grid exchange is not household consumption',
        'INDEVOLT PowerFlex battery': 'Measurement time is unavailable',
      }.entries) {
        expect(find.textContaining(entry.value), findsNothing);
        final button = find.byTooltip('About ${entry.key}');
        await tester.scrollUntilVisible(button, 250);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
      expect(find.text('Saved battery level: 60 %'), findsOneWidget);
      expect(
        find.text('Saved reading · current state unavailable'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      battery.dispose();
      grid.dispose();
    },
  );
}
