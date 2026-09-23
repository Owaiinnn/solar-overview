import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/solaredge.dart';

// Deliberately synthetic fixtures; never use a real site or API key in tests.
const fakeKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class MemoryStore implements CredentialStore {
  SolarEdgeCredentials? saved;
  bool failWrite = false;
  bool failRead = false;
  bool failDelete = false;
  int writes = 0;

  @override
  Future<SolarEdgeCredentials?> read() async {
    if (failRead) throw const SolarEdgeFailure('Storage unavailable.');
    return saved;
  }

  @override
  Future<void> write(SolarEdgeCredentials credentials) async {
    if (failWrite) throw const SolarEdgeFailure('Could not save securely.');
    writes++;
    saved = credentials;
  }

  @override
  Future<void> delete() async {
    if (failDelete) {
      throw const SolarEdgeFailure('Could not remove connection.');
    }
    saved = null;
  }
}

class FakeSource implements SolarEdgeSource {
  bool reject = false;
  int calls = 0;

  @override
  Future<SolarOverview> overview(SolarEdgeCredentials credentials) async {
    calls++;
    if (reject) throw const SolarEdgeFailure('Connection rejected.');
    return const SolarOverview(
      powerWatts: 177,
      energyWh: 152,
      reportedAt: '2026-09-22 10:35:16',
    );
  }
}
