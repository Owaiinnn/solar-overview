import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax_controller.dart';
import 'package:solar_overview/src/solax_store.dart';

import '../test/solax_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native SolaX setup, restore, replace and removal isolate SolarEdge',
    (tester) async {
      const solaxKey = 'solar_overview.integration_test.solax';
      const edgeKey = 'solar_overview.integration_test.solax_edge_isolation';
      final store = SecureSolaxStore(storageKey: solaxKey);
      final edge = SecureCredentialStore(storageKey: edgeKey);
      var now = solaxNow;
      final source = FakeSolaxSource();
      SolaxController controller = SolaxController(
        store,
        source,
        now: () => now,
      );
      Future<void> connect(String id) async {
        expect(await controller.discover(id, 'synthetic-secret'), isTrue);
        await controller.selectPlant(controller.plants.single);
        controller.selectDevice(controller.devices.single);
        expect(await controller.saveSelection(), isTrue);
      }

      try {
        await const FlutterSecureStorage().delete(key: solaxKey);
        await edge.write(SolarEdgeCredentials('123', 'a' * 32));
        await controller.initialize();
        await connect('synthetic-first');
        expect(controller.reading!.powerWatts, 120);
        controller.dispose();
        controller = SolaxController(
          SecureSolaxStore(storageKey: solaxKey),
          source,
          now: () => now,
        );
        await controller.initialize();
        expect(controller.connected, isTrue);
        expect(controller.usingSavedReading, isTrue);
        expect(source.authCalls, 1);
        expect(source.readingCalls, 1);
        expect((await store.read()).token, isNotNull);
        now = now.add(const Duration(minutes: 16));
        source.result = solaxReading(power: 33);
        await connect('synthetic-replacement');
        final replaced = await SecureSolaxStore(storageKey: solaxKey).read();
        expect(replaced.credentials!.clientId, 'synthetic-replacement');
        expect(replaced.reading!.powerWatts, 33);
        expect(await controller.disconnect(), isTrue);
        final removed = await SecureSolaxStore(storageKey: solaxKey).read();
        expect(removed.credentials, isNull);
        expect(removed.token, isNull);
        expect(removed.reading, isNull);
        expect(removed.nextAttempt, isNotNull);
        expect((await edge.read())!.siteId, '123');
        controller.dispose();
        controller = SolaxController(
          SecureSolaxStore(storageKey: solaxKey),
          source,
          now: () => now,
        );
        await controller.initialize();
        expect(controller.connected, isFalse);
        expect(controller.canRequest, isFalse);
      } finally {
        controller.dispose();
        await const FlutterSecureStorage().delete(key: solaxKey);
        await edge.delete();
      }
    },
  );
}
