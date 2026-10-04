import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/battery_controller.dart';
import 'package:solar_overview/src/battery_store.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax_store.dart';

import '../test/battery_fakes.dart';
import '../test/solax_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native battery lifecycle keeps solar storage and waits isolated',
    (tester) async {
      const batteryKey = 'solar_overview.integration_test.battery';
      const edgeKey = 'solar_overview.integration_test.battery_edge';
      const solaxKey = 'solar_overview.integration_test.battery_solax';
      final store = SecureBatteryStore(storageKey: batteryKey);
      final edge = SecureCredentialStore(storageKey: edgeKey);
      final solax = SecureSolaxStore(storageKey: solaxKey);
      var now = batteryNow;
      final source = FakeBatterySource();
      var c = BatteryController(store, source, now: () => now);
      try {
        await const FlutterSecureStorage().delete(key: batteryKey);
        await edge.write(SolarEdgeCredentials('123', 'a' * 32));
        await solax.write(solaxRecord(next: now.add(const Duration(hours: 1))));
        await c.initialize();
        expect(await c.connect('192.168.1.2'), isTrue);
        c.dispose();
        c = BatteryController(
          SecureBatteryStore(storageKey: batteryKey),
          source,
          now: () => now,
        );
        await c.initialize();
        expect(c.connected, isTrue);
        expect(c.reading!.percent, 60);
        expect(c.recentlyReceived, isFalse);
        expect(source.calls, 1);
        now = now.add(c.wait);
        source.reject = true;
        expect(await c.connect('192.168.1.3'), isFalse);
        expect((await store.read()).address!.host, '192.168.1.2');
        now = now.add(c.wait);
        source.reject = false;
        expect(await c.connect('192.168.1.3'), isTrue);
        expect((await store.read()).address!.host, '192.168.1.3');
        expect(await c.disconnect(), isTrue);
        final removed = await store.read();
        expect(removed.address, isNull);
        expect(removed.reading, isNull);
        expect(removed.nextAttempt, isNotNull);
        expect((await edge.read())!.siteId, '123');
        expect(
          (await solax.read()).nextAttempt,
          batteryNow.add(const Duration(hours: 1)),
        );
        expect((await solax.read()).reading!.powerWatts, 120);
      } finally {
        c.dispose();
        await const FlutterSecureStorage().delete(key: batteryKey);
        await const FlutterSecureStorage().delete(key: solaxKey);
        await edge.delete();
      }
    },
  );
}
