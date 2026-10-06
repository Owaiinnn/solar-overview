import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/p1_controller.dart';
import 'package:solar_overview/src/p1_store.dart';
import 'package:solar_overview/src/p1_widgets.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax_store.dart';

import '../test/p1_fakes.dart';
import '../test/solax_fakes.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native P1 HTTP, secure restart/isolation and visible states', (
    tester,
  ) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final host = interfaces
        .expand((i) => i.addresses)
        .map((a) => a.address)
        .firstWhere((host) {
          try {
            P1Address(host);
            return true;
          } catch (_) {
            return false;
          }
        });
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    final client = http.Client();
    var now = p1Now;
    var status = 200;
    var calls = 0;
    final requests = <String>[];
    var importKw = '0.000';
    var exportKw = '0.520';
    final subscription = server.listen((request) async {
      calls++;
      requests.add('${request.method} ${request.uri.path}');
      request.response.statusCode = status;
      if (status == 302) {
        request.response.headers.set(
          'location',
          'http://$host:8080/not-allowed',
        );
      }
      request.response.write(
        p1Telegram(at: now, importKw: importKw, exportKw: exportKw),
      );
      await request.response.close();
    });
    const p1Key = 'solar_overview.integration_test.p1';
    const edgeKey = 'solar_overview.integration_test.p1_edge';
    const solaxKey = 'solar_overview.integration_test.p1_solax';
    final store = SecureP1Store(storageKey: p1Key);
    final edge = SecureCredentialStore(storageKey: edgeKey);
    final solax = SecureSolaxStore(storageKey: solaxKey);
    var c = P1Controller(store, P1Api(client), now: () => now);
    try {
      await const FlutterSecureStorage().delete(key: p1Key);
      await edge.write(SolarEdgeCredentials('123', 'a' * 32));
      await solax.write(solaxRecord(next: now.add(const Duration(hours: 1))));
      await c.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [P1SettingsCard(controller: c)]),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('p1-address')), host);
      await tester.ensureVisible(find.text('Test & save P1'));
      await tester.tap(find.text('Test & save P1'));
      for (var i = 0; i < 100 && !c.connected; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(c.connected, isTrue);
      expect(c.current, isTrue);
      expect(c.reading!.netWatts, -520);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('p1-settings-connected');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      c = P1Controller(
        SecureP1Store(storageKey: p1Key),
        P1Api(client),
        now: () => now,
      );
      await c.initialize();
      expect(c.connected, isTrue);
      expect(c.reading!.measuredAt, p1Now);
      expect(c.current, isFalse);
      expect(c.wait.inSeconds, 30);
      expect(calls, 1);
      Future<void> details(String name) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [P1DetailsCard(controller: c, openSettings: () {})],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      await details('p1-saved-after-restart');
      now = now.add(c.wait);
      await c.refresh();
      await details('p1-exporting');
      expect(find.text('Grid exchange: Exporting'), findsOneWidget);
      importKw = '1.750';
      exportKw = '0.000';
      now = now.add(c.wait);
      await c.refresh();
      await details('p1-importing');
      expect(find.text('Grid exchange: Importing'), findsOneWidget);
      status = 503;
      now = now.add(c.wait);
      await c.refresh();
      expect(c.current, isFalse);
      expect(c.wait.inSeconds, 60);
      await details('p1-offline-saved');
      status = 200;
      importKw = '0.000';
      now = now.add(c.wait);
      await c.refresh();
      expect(c.current, isTrue);
      await details('p1-zero-after-recovery');
      expect(find.text('Grid exchange: No net exchange'), findsOneWidget);
      final priorCalls = calls;
      status = 302;
      await expectLater(
        P1Api(client).read(P1Address(host)),
        throwsA(isA<P1Failure>()),
      );
      expect(calls, priorCalls + 1);
      status = 401;
      await expectLater(
        P1Api(client).read(P1Address(host)),
        throwsA(isA<P1Failure>()),
      );
      expect(calls, priorCalls + 2);
      expect(
        requests.every((request) => request == 'GET /rpc/P1.GetData'),
        isTrue,
      );
      now = now.add(c.wait);
      expect(await c.connect(host), isFalse);
      expect(c.address!.host, host);
      status = 200;
      now = now.add(c.wait);
      expect(await c.connect(host), isTrue);
      expect(await c.disconnect(), isTrue);
      final removed = await store.read();
      expect(removed.address, isNull);
      expect(removed.reading, isNull);
      expect(removed.nextAttempt, isNotNull);
      expect((await edge.read())!.siteId, '123');
      expect(
        (await solax.read()).nextAttempt,
        p1Now.add(const Duration(hours: 1)),
      );
      expect((await solax.read()).reading!.powerWatts, 120);
      await tester.pumpWidget(const SizedBox());
    } finally {
      c.dispose();
      client.close();
      await subscription.cancel();
      await server.close(force: true);
      await const FlutterSecureStorage().delete(key: p1Key);
      await const FlutterSecureStorage().delete(key: solaxKey);
      await edge.delete();
    }
  });
}
