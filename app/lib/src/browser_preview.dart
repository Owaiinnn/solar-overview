import 'credential_store.dart';
import 'solaredge.dart';

/// Browser UI preview: no device credential storage or live API requests.
class BrowserPreview implements CredentialStore, SolarEdgeSource {
  const BrowserPreview();

  @override
  Future<SolarEdgeCredentials?> read() async => null;

  @override
  Future<void> delete() async {}

  @override
  Future<void> write(SolarEdgeCredentials credentials) async {
    throw const SolarEdgeFailure(
      'Real connections are available in the Android and iPhone app.',
    );
  }

  @override
  Future<SolarOverview> overview(SolarEdgeCredentials credentials) async {
    throw const SolarEdgeFailure(
      'Live readings are available in the Android and iPhone app.',
    );
  }
}
