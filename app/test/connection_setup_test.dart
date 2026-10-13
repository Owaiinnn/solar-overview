import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/connection_setup.dart';

import 'fakes.dart';

void main() {
  testWidgets(
    'empty Details offers import and manual setup; saved Details hides unused sources',
    (tester) async {
      final edge = ConnectionController(MemoryStore(), FakeSource());
      await edge.initialize();
      await tester.pumpWidget(SolarApp(controller: edge));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your connections'), findsOneWidget);
      await tester.ensureVisible(find.text('Manual setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual setup'));
      await tester.pumpAndSettle();
      expect(find.text('Your connections'), findsOneWidget);
      expect(find.byKey(const Key('site-id')), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('connection-json')),
        jsonEncode({
          'version': 1,
          'solarEdge': {'siteId': '123', 'apiKey': fakeKey},
        }),
      );
      await tester.tap(find.text('Review JSON'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ready to save: SolarEdge'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ready to save: SolarEdge'), findsOneWidget);
      await tester.tap(find.text('Save connections'));
      await tester.pumpAndSettle();
      expect(find.text('Saved · readings not checked yet'), findsOneWidget);
      await tester.tap(find.text('Continue to details'));
      await tester.pumpAndSettle();
      expect(find.text('SolarEdge panels'), findsOneWidget);
      expect(find.text('SolaX panels'), findsNothing);
      expect(find.text('Set up your connections'), findsNothing);
      expect(find.text('Connect SolarEdge'), findsNothing);
      expect(edge.overview, isNull);
      await tester.pumpWidget(const SizedBox());
      edge.dispose();
    },
  );
  testWidgets(
    'storage failure stays on recovery details instead of offering import',
    (tester) async {
      final edge = ConnectionController(
        MemoryStore()..failRead = true,
        FakeSource(),
      );
      await edge.initialize();
      await tester.pumpWidget(SolarApp(controller: edge));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Retry storage'), findsOneWidget);
      expect(find.text('Load JSON file'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      edge.dispose();
    },
  );
  testWidgets(
    'file cancel and malformed JSON preserve empty connections at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final edge = ConnectionController(MemoryStore(), FakeSource());
      await edge.initialize();
      XFile? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionSetupPage(
              controller: edge,
              onStarted: () {},
              onFinished: () {},
              openSettings: () {},
              chooseFile: () async => selected,
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Load JSON file'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load JSON file'));
      await tester.pumpAndSettle();
      expect(edge.connected, isFalse);
      selected = XFile.fromData(
        utf8.encode('private-broken-json'),
        name: 'setup.json',
      );
      await tester.tap(find.text('Load JSON file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not read the JSON'), findsOneWidget);
      expect(find.text('private-broken-json'), findsNothing);
      selected = XFile.fromData(
        utf8.encode(
          jsonEncode({
            'version': 1,
            'solarEdge': {'siteId': '123', 'apiKey': fakeKey},
          }),
        ),
        name: 'setup.json',
      );
      await tester.scrollUntilVisible(
        find.text('Load JSON file'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Load JSON file'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ready to save: SolarEdge'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ready to save: SolarEdge'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Save connections'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save connections'));
      await tester.pumpAndSettle();
      expect(edge.connected, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      edge.dispose();
    },
  );
}
