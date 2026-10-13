import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/battery_controller.dart';
import 'package:solar_overview/src/battery_store.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/connection_import.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/p1_controller.dart';
import 'package:solar_overview/src/p1_store.dart';
import 'package:solar_overview/src/solax_controller.dart';
import 'package:solar_overview/src/solax_store.dart';

import '../test/battery_fakes.dart';
import '../test/connection_import_test.dart' show setupJson;
import '../test/fakes.dart';
import '../test/p1_fakes.dart';
import '../test/solax_fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native import persists every source under isolated storage keys',
    (tester) async {
      const prefix = 'solar_overview.integration_test.import';
      final edgeStore = SecureCredentialStore(storageKey: '$prefix.edge');
      final solaxStore = SecureSolaxStore(storageKey: '$prefix.solax');
      final p1Store = SecureP1Store(storageKey: '$prefix.p1');
      final batteryStore = SecureBatteryStore(storageKey: '$prefix.battery');
      final edge = ConnectionController(edgeStore, FakeSource());
      final solax = SolaxController(solaxStore, FakeSolaxSource());
      final p1 = P1Controller(p1Store, FakeP1Source());
      final battery = BatteryController(batteryStore, FakeBatterySource());
      try {
        for (final name in ['edge', 'solax', 'p1', 'battery']) {
          await const FlutterSecureStorage().delete(key: '$prefix.$name');
        }
        await Future.wait([
          edge.initialize(),
          solax.initialize(),
          p1.initialize(),
          battery.initialize(),
        ]);
        final results = await ConnectionImport.parse(jsonEncode(setupJson()))
            .save(
              controller: edge,
              solaxController: solax,
              p1Controller: p1,
              batteryController: battery,
            );
        expect(results.values, everyElement(isTrue));
        expect(
          (await SecureCredentialStore(
            storageKey: '$prefix.edge',
          ).read())?.siteId,
          '123',
        );
        expect(
          (await SecureSolaxStore(
            storageKey: '$prefix.solax',
          ).read()).device?.sn,
          'synthetic-device',
        );
        expect(
          (await SecureP1Store(storageKey: '$prefix.p1').read()).address?.host,
          '192.168.1.10',
        );
        expect(
          (await SecureBatteryStore(
            storageKey: '$prefix.battery',
          ).read()).address?.host,
          '192.168.1.11',
        );
      } finally {
        edge.dispose();
        solax.dispose();
        p1.dispose();
        battery.dispose();
        for (final name in ['edge', 'solax', 'p1', 'battery']) {
          await const FlutterSecureStorage().delete(key: '$prefix.$name');
        }
      }
    },
  );
  testWidgets(
    'native file picker imports synthetic JSON and opens configured Details',
    (tester) async {
      final edge = ConnectionController(MemoryStore(), FakeSource());
      await edge.initialize();
      await tester.pumpWidget(SolarApp(controller: edge));
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await tester.ensureVisible(find.text('View details'));
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your connections'), findsOneWidget);
      await binding.takeScreenshot('setup-empty');
      await tester.tap(find.text('Load JSON file'));
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (DateTime.now().isBefore(deadline) &&
          find.text('Ready to save: SolarEdge').evaluate().isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      expect(find.text('Ready to save: SolarEdge'), findsOneWidget);
      await binding.takeScreenshot('setup-review');
      await tester.tap(find.text('Save connections'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('setup-saved');
      await tester.tap(find.text('Continue to details'));
      await tester.pumpAndSettle();
      expect(find.text('SolarEdge panels'), findsOneWidget);
      expect(find.text('SolaX panels'), findsNothing);
      await binding.takeScreenshot('configured-details');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      edge.dispose();
    },
    skip: !const bool.fromEnvironment('TEST_NATIVE_FILE_PICKER'),
  );
}
