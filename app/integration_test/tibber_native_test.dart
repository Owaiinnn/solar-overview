import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/tibber.dart';
import 'package:solar_overview/src/tibber_controller.dart';
import 'package:solar_overview/src/tibber_store.dart';
import 'package:solar_overview/src/tibber_widgets.dart';

import '../test/tibber_fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Tibber native secure storage and price/settings walkthrough', (
    tester,
  ) async {
    const key = 'solar_overview.integration_test.tibber';
    const otherKey = 'solar_overview.integration_test.tibber.other';
    const storage = FlutterSecureStorage();
    final store = SecureTibberStore(storageKey: key);
    final source = FakeTibberSource();
    var now = tibberNow;
    var controller = TibberController(store, source, now: () => now);
    try {
      await storage.delete(key: key);
      await storage.write(
        key: otherKey,
        value: 'synthetic unrelated connection',
      );
      await controller.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: SingleChildScrollView(
              child: TibberSettingsCard(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect Tibber'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tibber-token')),
        'synthetic-native-token',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.text('Test token & find homes'));
      await tester.tap(find.text('Test token & find homes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Tibber connection'));
      await tester.tap(find.text('Save Tibber connection'));
      await tester.pumpAndSettle();
      expect(controller.connected, isTrue);
      expect(
        (await SecureTibberStore(storageKey: key).read()).token,
        'synthetic-native-token',
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('tibber-saved-settings');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      controller = TibberController(
        SecureTibberStore(storageKey: key),
        source,
        now: () => now,
      );
      await controller.initialize();
      expect(controller.wait, const Duration(minutes: 15));
      expect(controller.saved, isTrue);
      expect(controller.current!.total, -0.05);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Prices')),
            body: TibberPricesPage(controller: controller, openSettings: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('tibber-current-negative');
      await tester.scrollUntilVisible(
        find.text('View Today prices').hitTestable(),
        180,
      );
      await tester.tap(find.text('View Today prices'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Now · -0.0500 EUR/kWh').hitTestable(),
        180,
      );
      await binding.takeScreenshot('tibber-intervals-and-gaps');
      now = tibberNow.add(const Duration(minutes: 16));
      source.failure = const TibberFailure(
        'Could not reach Tibber. Check your connection and retry later.',
      );
      await controller.refresh();
      expect(controller.home!.prices.length, 3);
      expect(controller.wait, const Duration(minutes: 15));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Electricity prices'), -500);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('tibber-offline-schedule');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(await controller.disconnect(), isTrue);
      final removed = await SecureTibberStore(storageKey: key).read();
      expect(removed.token, isNull);
      expect(removed.home, isNull);
      expect(removed.nextAttempt, now.add(const Duration(minutes: 15)));
      expect(
        await storage.read(key: otherKey),
        'synthetic unrelated connection',
      );
      await storage.write(key: key, value: 'invalid');
      await controller.initialize();
      expect(controller.storageUnavailable, isTrue);
      expect(controller.canRequest, isFalse);
    } finally {
      controller.dispose();
      await storage.delete(key: key);
      await storage.delete(key: otherKey);
    }
  });
}
