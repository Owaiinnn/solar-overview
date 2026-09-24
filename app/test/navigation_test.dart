import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  testWidgets('all tabs work before connection and retain settings input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = MemoryStore();
    final source = FakeSource();
    final controller = ConnectionController(store, source);
    await controller.initialize();
    await tester.pumpWidget(SolarApp(controller: controller));

    expect(find.text('Your solar, at a glance'), findsOneWidget);
    expect(find.textContaining('kW'), findsNothing);
    await tester.ensureVisible(find.text('Connect SolarEdge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect SolarEdge'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('site-id')), '123');
    FocusManager.instance.primaryFocus?.unfocus();

    await tester.tap(find.text('Appliances'));
    await tester.pumpAndSettle();
    expect(find.text('Plan your appliance use'), findsOneWidget);
    expect(find.text('Coming later'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Your production history'), findsOneWidget);
    expect(find.text('Coming later'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
    expect(find.text('Try sample data'), findsNothing);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Connect SolarEdge'), findsOneWidget);
    expect(source.calls, 0);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved readings survive tab changes without extra API requests', (
    tester,
  ) async {
    final store = MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey);
    final source = FakeSource();
    final controller = ConnectionController(store, source);
    await controller.initialize();
    await tester.pumpWidget(SolarApp(controller: controller));
    expect(find.text('0.18 kW'), findsOneWidget);

    for (final tab in ['Appliances', 'History', 'Settings', 'Overview']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    expect(find.text('0.18 kW'), findsOneWidget);
    expect(find.text('0.15 kWh'), findsOneWidget);
    expect(find.text('Connect SolarEdge'), findsNothing);
    expect(source.calls, 1);
    expect(store.writes, 0);
  });
}
