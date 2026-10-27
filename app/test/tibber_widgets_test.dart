import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/tibber.dart';
import 'package:solar_overview/src/tibber_controller.dart';
import 'package:solar_overview/src/tibber_store.dart';
import 'package:solar_overview/src/tibber_widgets.dart';

import 'fakes.dart';
import 'tibber_fakes.dart';

void main() {
  late TibberController controller;
  late MemoryTibberStore store;
  late FakeTibberSource source;
  setUp(() async {
    store = MemoryTibberStore();
    source = FakeTibberSource();
    controller = TibberController(store, source, now: () => tibberNow);
    await controller.initialize();
  });
  tearDown(() => controller.dispose());
  Future<void> connected() async {
    await controller.discover('synthetic', PriceResolution.quarterHourly);
    await controller.saveHome('test-home');
  }

  Widget prices() => MaterialApp(
    home: Scaffold(
      body: TibberPricesPage(controller: controller, openSettings: () {}),
    ),
  );
  Widget settings({bool active = true}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TibberSettingsCard(controller: controller, active: active),
      ),
    ),
  );

  testWidgets(
    'empty Prices opens Settings and tab navigation preserves other sources',
    (tester) async {
      final solar = ConnectionController(MemoryStore(), FakeSource());
      await solar.initialize();
      addTearDown(solar.dispose);
      await tester.pumpWidget(SolarApp(controller: solar, tibber: controller));
      await tester.tap(find.text('Prices'));
      await tester.pumpAndSettle();
      expect(find.text('Electricity prices'), findsOneWidget);
      await tester.tap(find.text('Set up Tibber'));
      await tester.pumpAndSettle();
      expect(find.text('Your connections'), findsOneWidget);
      expect(source.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'negative current price and incomplete DST schedule at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await connected();
      await tester.pumpWidget(prices());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('-0.0500 EUR/kWh'), 200);
      expect(find.text('-0.0500 EUR/kWh'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('View Today prices').hitTestable(),
        200,
      );
      expect(
        find.text('3 of 100 intervals available · incomplete coverage'),
        findsOneWidget,
      );
      await tester.tap(find.text('View Today prices'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Now · -0.0500 EUR/kWh'), 250);
      expect(find.text('Now · -0.0500 EUR/kWh'), findsOneWidget);
      expect(source.calls, 1);
    },
  );
  testWidgets(
    'unpublished tomorrow is normal and offline failure retains schedule',
    (tester) async {
      await connected();
      controller.saved = true;
      controller.error =
          'Could not reach Tibber. Check your connection and retry later.';
      await tester.pumpWidget(prices());
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved schedule'), findsOneWidget);
      expect(find.textContaining('Could not reach Tibber'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Tomorrow’s prices are not available'),
        200,
      );
      expect(
        find.textContaining('Tomorrow’s prices are not available'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('home discovery requires selection and explicit save', (
    tester,
  ) async {
    source.homes = [testHome(), testHome(id: 'second')];
    await tester.pumpWidget(settings());
    await tester.tap(find.text('Connect Tibber'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tibber-token')), 'synthetic');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tibber-token')))
          .obscureText,
      isTrue,
    );
    await tester.ensureVisible(find.text('Test token & find homes'));
    await tester.tap(find.text('Test token & find homes'));
    await tester.pumpAndSettle();
    expect(controller.connected, isFalse);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save Tibber connection'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. Test home').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Tibber connection'));
    await tester.tap(find.text('Save Tibber connection'));
    await tester.pumpAndSettle();
    expect(controller.home!.id, 'second');
    expect(find.text('Connection saved'), findsOneWidget);
    expect(source.calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'leaving Settings clears token draft without changing saved connection',
    (tester) async {
      await connected();
      await tester.pumpWidget(settings());
      await tester.tap(find.text('Replace Tibber connection'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('tibber-token')),
        'replacement',
      );
      await tester.pumpWidget(settings(active: false));
      await tester.pumpAndSettle();
      await tester.pumpWidget(settings());
      await tester.pumpAndSettle();
      expect(controller.editing, isFalse);
      expect(controller.home!.id, 'test-home');
      expect(find.text('replacement'), findsNothing);
      expect(source.calls, 1);
    },
  );
  testWidgets(
    'remove confirmation cancellation keeps token and removal keeps quota',
    (tester) async {
      await connected();
      await tester.pumpWidget(settings());
      await tester.tap(find.text('Remove Tibber'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.connected, isTrue);
      await tester.tap(find.text('Remove Tibber'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(controller.connected, isFalse);
      expect(store.record.token, isNull);
      expect(controller.wait, const Duration(minutes: 15));
    },
  );
  testWidgets(
    'ended subscription and expired cache never claim current price',
    (tester) async {
      store.record = TibberRecord(
        token: 'synthetic',
        home: testHome(status: 'ended'),
        receivedAt: tibberNow,
      );
      await controller.initialize();
      await tester.pumpWidget(prices());
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        find.text('No running Tibber electricity subscription is available.'),
        findsOneWidget,
      );
      expect(find.text('View Today prices').hitTestable(), findsNothing);
    },
  );
}
