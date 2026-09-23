import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'credential pair round-trips and deletion leaves unrelated values alone',
    () async {
      FlutterSecureStorage.setMockInitialValues({'unrelated': 'keep'});
      final store = SecureCredentialStore();
      await store.write(SolarEdgeCredentials('123', fakeKey));
      final restored = await SecureCredentialStore().read();
      expect(restored?.siteId, '123');
      expect(restored?.apiKey, fakeKey);
      await store.delete();
      expect(await store.read(), isNull);
      expect(await const FlutterSecureStorage().read(key: 'unrelated'), 'keep');
    },
  );

  test('corrupt stored data produces a safe, actionable error', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureCredentialStore.connectionKey: fakeKey,
    });
    await expectLater(
      SecureCredentialStore().read(),
      throwsA(
        isA<SolarEdgeFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains(fakeKey)),
        ),
      ),
    );
  });
}
