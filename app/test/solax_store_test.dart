import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solar_overview/src/solax.dart';
import 'package:solar_overview/src/solax_store.dart';
import 'package:solar_overview/src/credential_store.dart';
import 'package:solar_overview/src/reading_store.dart';

import 'solax_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'secure SolaX record round trips independently of SolarEdge keys',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureCredentialStore.connectionKey: 'edge-credentials',
        SecureReadingStore.cacheKey: 'edge-cache',
      });
      final store = SecureSolaxStore();
      await store.write(
        solaxRecord(next: solaxNow.add(const Duration(hours: 24))),
      );
      final restored = await SecureSolaxStore().read();
      expect(restored.credentials!.clientId, 'synthetic-client');
      expect(restored.token!.value, 'synthetic-token');
      expect(restored.reading!.powerWatts, 120);
      expect(restored.plant!.timeZone, 'Europe/Amsterdam');
      await store.write(restored.withoutConnection());
      final removed = await store.read();
      expect(removed.credentials, isNull);
      expect(removed.reading, isNull);
      expect(removed.nextAttempt, solaxNow.add(const Duration(hours: 24)));
      const native = FlutterSecureStorage();
      expect(
        await native.read(key: SecureCredentialStore.connectionKey),
        'edge-credentials',
      );
      expect(await native.read(key: SecureReadingStore.cacheKey), 'edge-cache');
    },
  );
  test('corrupt, mismatched and unknown-version records fail closed', () async {
    final original = solaxRecord().toJson();
    for (final value in [
      'not json',
      jsonEncode({...original, 'version': 99}),
      jsonEncode({...original, 'credentials': null}),
      jsonEncode({
        ...original,
        'plant': {'id': 'other', 'timeZone': 'Europe/Amsterdam'},
      }),
      jsonEncode({...original, 'nextAttempt': 'not-a-date'}),
    ]) {
      FlutterSecureStorage.setMockInitialValues({
        SecureSolaxStore.connectionKey: value,
      });
      await expectLater(
        SecureSolaxStore().read(),
        throwsA(isA<SolaxFailure>()),
      );
    }
  });
  test('platform errors are redacted', () async {
    final store = SecureSolaxStore(storage: FailingSecureStorage());
    for (final operation in [
      () => store.read(),
      () => store.write(solaxRecord()),
    ]) {
      await expectLater(
        operation(),
        throwsA(
          isA<SolaxFailure>().having(
            (f) => f.message,
            'redaction',
            isNot(contains('private')),
          ),
        ),
      );
    }
  });
}

class FailingSecureStorage extends FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'private-secret', message: 'private-device');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'private-secret', message: 'private-device');
  }
}
