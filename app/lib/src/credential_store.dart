import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'solaredge.dart';

abstract interface class CredentialStore {
  Future<SolarEdgeCredentials?> read();
  Future<void> write(SolarEdgeCredentials credentials);
  Future<void> delete();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({
    FlutterSecureStorage? storage,
    this.storageKey = connectionKey,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
             aOptions: AndroidOptions(),
           );

  static const connectionKey = 'solar_overview.solaredge.connection.v1';
  final String storageKey;
  final FlutterSecureStorage _storage;

  @override
  Future<SolarEdgeCredentials?> read() async {
    try {
      final encoded = await _storage.read(key: storageKey);
      if (encoded == null) return null;
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      return SolarEdgeCredentials(
        data['siteId'] as String,
        data['apiKey'] as String,
      );
    } catch (_) {
      throw const SolarEdgeFailure(
        'Could not read the saved connection. Unlock your phone and retry, or remove the saved connection.',
      );
    }
  }

  @override
  Future<void> write(SolarEdgeCredentials credentials) async {
    try {
      // One entry prevents mixing a new site ID with an old API key.
      await _storage.write(
        key: storageKey,
        value: jsonEncode({
          'siteId': credentials.siteId,
          'apiKey': credentials.apiKey,
        }),
      );
    } catch (_) {
      throw const SolarEdgeFailure(
        'The connection worked, but your phone could not save it securely. Please retry.',
      );
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      throw const SolarEdgeFailure(
        'Could not remove the saved connection. Unlock your phone and retry.',
      );
    }
  }
}
