import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/overview.dart';
import 'package:solar_overview/src/p1_controller.dart';
import 'package:solar_overview/src/p1_widgets.dart';
import 'package:solar_overview/src/production_total.dart';

import 'overview_test.dart' show edgeController, solaxController;
import 'p1_fakes.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget widget) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ListView(children: [widget])),
    ),
  );
  testWidgets(
    'settings validation, save, replacement cancellation and removal',
    (tester) async {
      final source = FakeP1Source();
      final c = P1Controller(MemoryP1Store(), source, now: () => p1Now);
      await c.initialize();
      await show(tester, P1SettingsCard(controller: c));
      await tester.tap(find.text('Test & save P1'));
      await tester.pump();
      expect(find.textContaining('Enter the P1 reader'), findsOneWidget);
      expect(source.calls, 0);
      await tester.enterText(
        find.byKey(const Key('p1-address')),
        '192.168.1.2',
      );
      await tester.tap(find.text('Test & save P1'));
      await tester.pumpAndSettle();
      expect(c.connected, isTrue);
      expect(
        find.text('P1 connection saved securely on this phone'),
        findsOneWidget,
      );
      await tester.tap(find.text('Replace P1 connection'));
      await tester.pump();
      expect(c.editingConnection, isTrue);
      await tester.enterText(
        find.byKey(const Key('p1-address')),
        '192.168.1.3',
      );
      await tester.ensureVisible(find.text('Cancel P1 replacement'));
      await tester.tap(find.text('Cancel P1 replacement'));
      await tester.pumpAndSettle();
      expect(c.address!.host, '192.168.1.2');
      expect(c.editingConnection, isFalse);
      await tester.tap(find.text('Remove P1 connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.connected, isTrue);
      await tester.tap(find.text('Remove P1 connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(c.connected, isFalse);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('leaving replacement resumes polling without discarding input', (
    tester,
  ) async {
    final c = P1Controller(MemoryP1Store(), FakeP1Source(), now: () => p1Now);
    await c.initialize();
    await c.connect('192.168.1.2');
    await show(tester, P1SettingsCard(controller: c));
    await tester.tap(find.text('Replace P1 connection'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('p1-address')), '192.168.1.3');
    await show(tester, P1SettingsCard(controller: c, active: false));
    expect(c.editingConnection, isFalse);
    await show(tester, P1SettingsCard(controller: c, active: true));
    expect(c.editingConnection, isTrue);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('p1-address')))
          .controller!
          .text,
      '192.168.1.3',
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final state in [
    'import',
    'export',
    'zero',
    'missing',
    'stale',
    'offline',
  ]) {
    testWidgets(
      'details show qualified $state at narrow width and large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var now = p1Now;
        final source = FakeP1Source()
          ..value = p1Reading(
            importKw: state == 'import' ? '1.200' : '0',
            exportKw: state == 'zero' || state == 'import' ? '0' : '0.520',
          );
        if (state == 'missing') {
          source.value = P1Reading.parse(
            p1Telegram().replaceFirst('1-0:1.7.0(00.000*kW)\n', ''),
          );
        }
        final c = P1Controller(MemoryP1Store(), source, now: () => now);
        await c.initialize();
        await c.connect('192.168.1.2');
        if (state == 'stale') now = now.add(const Duration(minutes: 2));
        if (state == 'offline') {
          source.reject = true;
          now = now.add(c.wait);
          await c.refresh();
        }
        await show(tester, P1DetailsCard(controller: c, openSettings: () {}));
        expect(
          find.textContaining(switch (state) {
            'import' => 'Grid exchange: Importing',
            'zero' => 'Grid exchange: No net exchange',
            'missing' => 'Grid exchange: Unavailable',
            'stale' || 'offline' => 'Last measured grid exchange: Exporting',
            _ => 'Grid exchange: Exporting',
          }),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Meter measurement details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Meter measurement details'));
        await tester.pumpAndSettle();
        expect(
          find.text('Cumulative import tariff 1: 1234.567 kWh'),
          findsOneWidget,
        );
        expect(find.textContaining('not today’s energy'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
  testWidgets(
    'P1 lifecycle and errors leave solar power and refresh waits independent',
    (tester) async {
      final edge = await edgeController();
      final solax = await solaxController();
      var now = p1Now;
      final source = FakeP1Source(now: () => now);
      final c = P1Controller(MemoryP1Store(), source, now: () => now);
      await c.initialize();
      await c.connect('192.168.1.2');
      final edgeWait = edge.refreshNotice;
      final solaxWait = solax.refreshNotice;
      await tester.pumpWidget(SolarApp(controller: edge, solax: solax, p1: c));
      expect(ProductionTotal(edge, solax).watts, 1120);
      now = now.add(c.wait);
      source.reject = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 40));
      expect(source.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(source.calls, 2);
      expect(c.current, isFalse);
      expect(ProductionTotal(edge, solax).watts, 1120);
      expect(edge.refreshNotice, edgeWait);
      expect(solax.refreshNotice, solaxWait);
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('P1 grid meter'),
        500,
        scrollable: find
            .descendant(
              of: find.byType(OverviewPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('P1 unreachable.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
