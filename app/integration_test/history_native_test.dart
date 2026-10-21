import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/history_controller.dart';
import 'package:solar_overview/src/history_page.dart';
import 'package:solar_overview/src/history_store.dart';

import '../test/history_widgets_test.dart' show savedHistoryController;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native history cache restoration and visual walkthrough', (
    tester,
  ) async {
    const key = 'solar_overview.integration_test.history';
    final store = SecureHistoryStore(storageKey: key);
    final controller = await savedHistoryController(historyStore: store);
    try {
      final restored = await SecureHistoryStore(storageKey: key).read();
      expect(restored.length, 2);
      expect(restored.first.data.energyWh, 2000);
      expect(restored.first.data.samples.length, 96);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('History')),
            body: HistoryPage(controller: controller, openSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('history-saved');
      await tester.scrollUntilVisible(
        find.text('Readings in W').hitTestable(),
        250,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('history-ac-graph');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('history-plot-false')).hitTestable(),
        -150,
      );
      await tester.tap(find.byKey(const ValueKey('history-plot-false')));
      await tester.pumpAndSettle();
      expect(find.textContaining('SolarEdge (AC):'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Show SolaX DC inputs').hitTestable(),
        200,
      );
      await tester.tap(find.text('Show SolaX DC inputs'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('DC input power').hitTestable(),
        200,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('history-dc-graph');
      controller.selectDay(DateTime.utc(2026, 9, 27));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Your production history').hitTestable(),
        -500,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('history-uncached');
      expect(controller.states[HistorySource.solarEdge]!.saved, isNull);
      expect(tester.takeException(), isNull);
      await store.write(
        restored.where((entry) => entry.identity != 'edge:123').toList(),
      );
      await controller.initialize();
      controller.selectDay(DateTime.utc(2026, 9, 28));
      controller.states[HistorySource.solarEdge]!.error = 'SolarEdge could not load power history (HTTP 503). Please try again later.';
      controller.edge.updateFreshness();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find
            .textContaining('SolarEdge history could not be loaded.')
            .hitTestable(),
        150,
      );
      expect(find.text('SolaX (AC)'), findsOneWidget);
      expect(find.text('SolarEdge (AC)'), findsNothing);
      await binding.takeScreenshot('history-partial-failure');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await const FlutterSecureStorage().write(
        key: key,
        value: 'invalid cache',
      );
      await expectLater(store.read(), throwsA(isA<FormatException>()));
    } finally {
      controller.dispose();
      controller.edge.dispose();
      controller.solax!.dispose();
      await const FlutterSecureStorage().delete(key: key);
    }
  });
}
