import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/solaredge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native storage persists across instances and supports removal', (
    tester,
  ) async {
    // Separate key: never overwrite or remove the user's saved connection.
    const testKey = 'solar_overview.integration_test.credentials';
    final store = SecureCredentialStore(storageKey: testKey);
    try {
      await store.write(SolarEdgeCredentials('123', 'a' * 32));
      final reopened = await SecureCredentialStore(storageKey: testKey).read();
      expect(reopened?.siteId, '123');
      expect(reopened?.apiKey, 'a' * 32);
      await store.delete();
      expect(await store.read(), isNull);
    } finally {
      await store.delete();
    }
  });
}
