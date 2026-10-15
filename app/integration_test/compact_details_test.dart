import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/overview.dart';

import '../test/home_energy_fakes.dart';
import '../test/overview_test.dart' show edgeController, solaxController;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('compact source cards and tappable information on Android', (
    tester,
  ) async {
    final edge = await edgeController();
    final solax = await solaxController();
    final battery = await homeBattery();
    final grid = await homeGrid();
    await tester.pumpWidget(
      SolarApp(controller: edge, solax: solax, battery: battery, p1: grid),
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    expect(find.textContaining('%'), findsNothing);
    await binding.takeScreenshot('home');
    await tester.tap(find.byTooltip('About this scene'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(AlertDialog), findsOneWidget);
    await binding.takeScreenshot('scene-info');
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    for (final title in [
      'Combined solar production',
      'SolarEdge panels',
      'SolaX panels',
      'P1 grid meter',
      'INDEVOLT PowerFlex battery',
    ]) {
      final button = find.byTooltip('About $title');
      await tester.scrollUntilVisible(
        button,
        220,
        scrollable: find
            .descendant(
              of: find.byType(OverviewPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot(title);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await binding.takeScreenshot('$title-info');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Reported battery level: 60 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    battery.dispose();
    grid.dispose();
  });
}
