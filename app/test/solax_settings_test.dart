import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/solax_controller.dart';
import 'package:solar_overview/src/solax_settings.dart';

import 'solax_fakes.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    SolaxController c, {
    bool preview = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SolaxSettingsCard(controller: c, preview: preview),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('browser preview never shows SolaX credentials or calls API', (
    tester,
  ) async {
    final source = FakeSolaxSource();
    final c = SolaxController(MemorySolaxStore(), source);
    await show(tester, c, preview: true);
    expect(find.byType(TextField), findsNothing);
    expect(source.authCalls, 0);
    c.dispose();
  });
  testWidgets(
    'dedicated app required; secret hidden and cleared; selection saves',
    (tester) async {
      final store = MemorySolaxStore();
      final source = FakeSolaxSource();
      final c = SolaxController(store, source, now: () => solaxNow);
      await c.initialize();
      await show(tester, c);
      final test = find.text('Test SolaX & find plants');
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(of: test, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('solax-client-id')),
        'client',
      );
      await tester.enterText(find.byKey(const Key('solax-secret')), 'secret');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('solax-secret')))
            .obscureText,
        isTrue,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(test);
      await tester.tap(test);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('solax-secret')), findsNothing);
      await tester.tap(find.text('SolaX plant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plant 1 · …-plant').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SolaX inverter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('…device · X1-Micro 2 in 1').last);
      await tester.pumpAndSettle();
      final save = find.text('Test & save SolaX connection');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('SolaX connection saved on this phone'), findsOneWidget);
      expect(c.connected, isTrue);
      expect(find.text('AC output: 120 W'), findsOneWidget);
      final replace = find.text('Replace SolaX connection');
      await tester.ensureVisible(replace);
      await tester.tap(replace);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('solax-secret')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('solax-client-id')))
            .controller!
            .text,
        isEmpty,
      );
      c.dispose();
    },
  );
  testWidgets(
    'stale saved data, removal dialog, and narrow large text remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemorySolaxStore()
        ..record = solaxRecord(next: solaxNow.add(const Duration(hours: 2)));
      final c = SolaxController(
        store,
        FakeSolaxSource(),
        now: () => solaxNow.add(const Duration(hours: 1)),
      );
      await c.initialize();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SolaxSettingsCard(controller: c),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stale SolaX reading'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final remove = find.text('Remove SolaX connection');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.connected, isTrue);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove SolaX'));
      await tester.pumpAndSettle();
      expect(c.connected, isFalse);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
}
