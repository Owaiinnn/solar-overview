import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/browser_preview.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/settings.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'replacement draft survives scrolling and tab changes; cancellation preserves connection',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()..saved = SolarEdgeCredentials('123', fakeKey);
      final source = FakeSource();
      final controller = ConnectionController(store, source);
      await controller.initialize();
      await tester.pumpWidget(SolarApp(controller: controller));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace connection'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('site-id')), '456');
      await tester.enterText(find.byKey(const Key('api-key')), fakeKey);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final scrollable = find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Coming later'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('site-id')),
        -300,
        scrollable: scrollable,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('site-id')))
            .controller!
            .text,
        '456',
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('api-key')))
            .controller!
            .text,
        fakeKey,
      );
      await tester.ensureVisible(find.text('Cancel replacement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel replacement'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Remove connection'),
        -200,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Remove connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(store.saved!.siteId, '123');
      expect(source.calls, 1);
      expect(store.writes, 0);
      expect(controller.canRequest, isFalse);
      await tester.ensureVisible(find.text('Replace connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace connection'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('api-key')))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'browser preview has empty screens without readings or credential entry',
    (tester) async {
      const preview = BrowserPreview();
      final controller = ConnectionController(preview, preview);
      await controller.initialize();
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(SolarApp(controller: controller, preview: true));
      expect(find.text('Unavailable'), findsOneWidget);
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Connect SolarEdge'), 200);
      expect(find.text('Connect SolarEdge'), findsOneWidget);
      expect(controller.overview, isNull);
      expect(find.textContaining('kW'), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Browser preview'), findsOneWidget);
      expect(find.byKey(const Key('api-key')), findsNothing);
      expect(await controller.connect('123', fakeKey), isFalse);
      expect(await preview.read(), isNull);
    },
  );
  testWidgets('key is hidden, validated, cleared after saving, and removable', (
    tester,
  ) async {
    final store = MemoryStore();
    final controller = ConnectionController(store, FakeSource());
    await controller.initialize();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(SolarApp(controller: controller));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final keyField = find.byKey(const Key('api-key'));
    final editable = find.descendant(
      of: keyField,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editable).obscureText, isTrue);
    await tester.enterText(find.byKey(const Key('site-id')), '123');
    await tester.enterText(keyField, fakeKey);
    await tester.ensureVisible(find.text('Test & save connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test & save connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection saved on this phone'), findsOneWidget);
    expect(find.text(fakeKey), findsNothing);
    expect(store.saved?.apiKey, fakeKey);
    await tester.ensureVisible(find.text('Replace connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace connection'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editable).controller.text, isEmpty);
    await tester.ensureVisible(find.text('Cancel replacement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel replacement'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Remove connection'),
      -200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(store.saved, isNull);
    await tester.scrollUntilVisible(
      keyField,
      -200,
      scrollable: find
          .descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('api-key')), findsOneWidget);
  });

  testWidgets(
    'small screen and larger text allow scrolling to the save button',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = ConnectionController(MemoryStore(), FakeSource());
      await controller.initialize();
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      await tester.pumpWidget(SolarApp(controller: controller));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Test & save connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test & save connection'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your numeric site ID.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
