import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/battery_controller.dart';
import 'package:solar_overview/src/battery_widgets.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/p1_controller.dart';
import 'package:solar_overview/src/solax_controller.dart';

import 'battery_fakes.dart';
import 'fakes.dart';
import 'p1_fakes.dart';
import 'solax_fakes.dart';

void main() {
  testWidgets('setup, failed replacement, cancellation and confirmed removal', (
    tester,
  ) async {
    final store = MemoryBatteryStore();
    final source = FakeBatterySource();
    var now = batteryNow;
    final c = BatteryController(store, source, now: () => now);
    await c.initialize();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BatterySettingsCard(controller: c),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('battery-address')), '8.8.8.8');
    await tester.tap(find.text('Test & save battery'));
    await tester.pumpAndSettle();
    expect(source.calls, 0);
    await tester.enterText(
      find.byKey(const Key('battery-address')),
      '192.168.1.2',
    );
    await tester.tap(find.text('Test & save battery'));
    await tester.pumpAndSettle();
    expect(c.connected, isTrue);
    await tester.tap(find.text('Replace battery connection'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('battery-address')),
      '192.168.1.3',
    );
    now = now.add(c.wait);
    source.reject = true;
    c.tick();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test & save battery'));
    await tester.pumpAndSettle();
    expect(c.address!.host, '192.168.1.2');
    expect(find.text('Battery unreachable.'), findsOneWidget);
    await tester.tap(find.text('Cancel battery replacement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove battery connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.connected, isTrue);
    await tester.tap(find.text('Remove battery connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(c.connected, isFalse);
    expect(store.saved.reading, isNull);
  });
  testWidgets('saved details stay qualified at large text and narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = BatteryController(
      MemoryBatteryStore(),
      FakeBatterySource(),
      now: () => batteryNow,
    );
    await c.initialize();
    await c.connect('192.168.1.2');
    c.setForeground(false);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BatteryDetailsCard(controller: c, openSettings: () {}),
          ),
        ),
      ),
    );
    expect(
      find.text('Saved reading · current state unavailable'),
      findsOneWidget,
    );
    expect(find.text('Last reported state: Charging'), findsOneWidget);
    expect(find.text('Saved pack DC power: -200 W'), findsOneWidget);
    await tester.ensureVisible(find.text('Battery measurement details'));
    await tester.tap(find.text('Battery measurement details'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('not confirmed totals for today'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'battery and P1 poll independently and pause together without solar requests',
    (tester) async {
      var now = batteryNow;
      final source = FakeBatterySource();
      final battery = BatteryController(
        MemoryBatteryStore(),
        source,
        now: () => now,
      );
      final p1Source = FakeP1Source(now: () => now);
      final p1 = P1Controller(MemoryP1Store(), p1Source, now: () => now);
      await p1.initialize();
      await p1.connect('192.168.1.3');
      final edgeSource = FakeSource();
      final edge = ConnectionController(MemoryStore(), edgeSource);
      final solaxSource = FakeSolaxSource();
      final solax = SolaxController(MemorySolaxStore(), solaxSource);
      await edge.initialize();
      await solax.initialize();
      await battery.initialize();
      await battery.connect('192.168.1.2');
      await tester.pumpWidget(
        SolarApp(controller: edge, solax: solax, battery: battery, p1: p1),
      );
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(source.calls, 2);
      expect(p1Source.calls, 2);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(source.calls, 2);
      expect(p1Source.calls, 2);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(source.calls, 3);
      expect(p1Source.calls, 3);
      expect(edgeSource.calls, 0);
      expect(solaxSource.authCalls, 0);
      expect(solaxSource.readingCalls, 0);
      await tester.pumpWidget(const SizedBox());
      battery.dispose();
      p1.dispose();
      edge.dispose();
      solax.dispose();
    },
  );
}
