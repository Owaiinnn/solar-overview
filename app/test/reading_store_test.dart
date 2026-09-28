import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/reading_store.dart';
import 'package:solar_overview/src/solaredge.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('normalized snapshot and quota survive storage round trip without credentials', () async {
    FlutterSecureStorage.setMockInitialValues({'unrelated': 'keep'});
    final store = SecureReadingStore();
    await store.write(
      ReadingCache(
        siteId: '123',
        overview: const SolarOverview(
          powerWatts: 0,
          energyWh: 42,
          reportedAt: '2026-09-28 14:00:00',
          timeZone: 'Europe/Amsterdam',
        ),
        fetchedAt: DateTime.utc(2026, 9, 28, 12),
        nextAttempt: DateTime.utc(2026, 9, 29, 12),
        rateLimited: true,
      ),
    );
    final restored = await SecureReadingStore().read();
    expect(restored.overview?.powerWatts, 0);
    expect(restored.overview?.reportedAtUtc, DateTime.utc(2026, 9, 28, 12));
    expect(restored.rateLimited, isTrue);
    expect(restored.nextAttempt, DateTime.utc(2026, 9, 29, 12));
    final raw = await const FlutterSecureStorage().read(
      key: SecureReadingStore.cacheKey,
    );
    expect(raw, isNot(contains(fakeKey)));
    await store.write(restored.withoutReading());
    final removed = await store.read();
    expect(removed.overview, isNull);
    expect(removed.siteId, isNull);
    expect(removed.nextAttempt, restored.nextAttempt);
    expect(await const FlutterSecureStorage().read(key: 'unrelated'), 'keep');
  });
  test(
    'corrupt storage returns a safe error instead of resetting the quota',
    () async {
      for (final raw in [
        fakeKey,
        '{"version":99}',
        '{"version":1,"nextAttempt":"bad"}',
      ]) {
        FlutterSecureStorage.setMockInitialValues({
          SecureReadingStore.cacheKey: raw,
        });
        await expectLater(
          SecureReadingStore().read(),
          throwsA(
            isA<SolarEdgeFailure>().having(
              (e) => e.message,
              'message',
              isNot(contains(fakeKey)),
            ),
          ),
        );
      }
    },
  );
}
