import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native storage persists across instances and supports removal', (
    tester,
  ) async {
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

  testWidgets('native reading cache preserves snapshot and request pause', (
    tester,
  ) async {
    const testKey = 'solar_overview.integration_test.readings';
    final store = SecureReadingStore(storageKey: testKey);
    try {
      final next = DateTime.utc(2026, 9, 29, 12);
      await store.write(
        ReadingCache(
          siteId: '123',
          overview: const SolarOverview(
            powerWatts: 0,
            energyWh: 1500,
            reportedAt: '2026-09-28 14:00:00',
            timeZone: 'Europe/Amsterdam',
          ),
          fetchedAt: DateTime.utc(2026, 9, 28, 12),
          nextAttempt: next,
          rateLimited: true,
        ),
      );
      final reopened = await SecureReadingStore(storageKey: testKey).read();
      expect(reopened.overview?.powerWatts, 0);
      expect(reopened.overview?.reportedAtUtc, DateTime.utc(2026, 9, 28, 12));
      expect(reopened.nextAttempt, next);
      expect(reopened.rateLimited, isTrue);
      await store.write(reopened.withoutReading());
      final removed = await SecureReadingStore(storageKey: testKey).read();
      expect(removed.siteId, isNull);
      expect(removed.overview, isNull);
      expect(removed.nextAttempt, next);
    } finally {
      await const FlutterSecureStorage().delete(key: testKey);
    }
  });
}
