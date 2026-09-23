import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/browser_preview.dart';
import 'package:solar_overview/src/connection_controller.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'browser preview shows sample readings without credential entry',
    (tester) async {
      const preview = BrowserPreview();
      final controller = ConnectionController(preview, preview);
      await controller.initialize();
      controller.showSample();
      await tester.pumpWidget(SolarApp(controller: controller, preview: true));
      expect(find.text('SAMPLE DATA · Example readings'), findsOneWidget);
      expect(find.text('1.85 kW'), findsOneWidget);
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
    await tester.pumpWidget(SolarApp(controller: controller));
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
    await tester.tap(find.text('Replace connection'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editable).controller.text, isEmpty);
    await tester.ensureVisible(find.text('Cancel replacement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel replacement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(store.saved, isNull);
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
      await tester.pumpWidget(SolarApp(controller: controller));
      await tester.ensureVisible(find.text('Test & save connection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test & save connection'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your numeric site ID.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
