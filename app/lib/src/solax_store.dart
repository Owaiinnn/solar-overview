import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'solax.dart';

// One atomic record prevents credentials, token and reading from being mixed
// across accounts. Disconnect retains only the device-local request deadline.
class SolaxRecord {
  const SolaxRecord({
    this.credentials,
    this.token,
    this.plant,
    this.device,
    this.reading,
    this.fetchedAt,
    this.nextAttempt,
    this.rateLimited = false,
    this.reconnectRequired = false,
  });
  final SolaxCredentials? credentials;
  final SolaxToken? token;
  final SolaxPlant? plant;
  final SolaxDevice? device;
  final SolaxReading? reading;
  final DateTime? fetchedAt;
  final DateTime? nextAttempt;
  final bool rateLimited;
  final bool reconnectRequired;
  SolaxRecord withGate(DateTime next, {bool limited = false}) => SolaxRecord(
    credentials: credentials,
    token: token,
    plant: plant,
    device: device,
    reading: reading,
    fetchedAt: fetchedAt,
    nextAttempt: next,
    rateLimited: limited,
    reconnectRequired: reconnectRequired,
  );
  SolaxRecord withToken(SolaxToken? value, {bool revoked = false}) =>
      SolaxRecord(
        credentials: credentials,
        token: value,
        plant: plant,
        device: device,
        reading: reading,
        fetchedAt: fetchedAt,
        nextAttempt: nextAttempt,
        rateLimited: rateLimited,
        reconnectRequired: revoked,
      );
  SolaxRecord withoutConnection() =>
      SolaxRecord(nextAttempt: nextAttempt, rateLimited: rateLimited);
  Map<String, dynamic> toJson() => {
    'version': 1,
    'credentials': credentials?.toJson(),
    'token': token?.toJson(),
    'plant': plant?.toJson(),
    'device': device?.toJson(),
    'reading': reading?.toJson(),
    'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
    'nextAttempt': nextAttempt?.toUtc().toIso8601String(),
    'rateLimited': rateLimited,
    'reconnectRequired': reconnectRequired,
  };
  factory SolaxRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException();
    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || !value.endsWith('Z')) {
        throw const FormatException();
      }
      return DateTime.parse(value);
    }

    final credentials = json['credentials'] == null
        ? null
        : SolaxCredentials.fromJson(
            json['credentials'] as Map<String, dynamic>,
          );
    final plant = json['plant'] == null
        ? null
        : SolaxPlant.fromJson(json['plant'] as Map<String, dynamic>);
    final device = json['device'] == null
        ? null
        : SolaxDevice.fromJson(json['device'] as Map<String, dynamic>);
    final token = json['token'] == null
        ? null
        : SolaxToken.fromJson(json['token'] as Map<String, dynamic>);
    final reading = json['reading'] == null
        ? null
        : SolaxReading.fromJson(json['reading'] as Map<String, dynamic>);
    if ((plant == null) != (device == null) ||
        (device != null &&
            (device.plantId != plant!.id || !device.supported)) ||
        (credentials == null &&
            (token != null || plant != null || reading != null)) ||
        (reading != null &&
            (device == null || reading.timeZone != plant!.timeZone))) {
      throw const FormatException();
    }
    return SolaxRecord(
      credentials: credentials,
      token: token,
      plant: plant,
      device: device,
      reading: reading,
      fetchedAt: date('fetchedAt'),
      nextAttempt: date('nextAttempt'),
      rateLimited: json['rateLimited'] as bool,
      reconnectRequired: json['reconnectRequired'] as bool,
    );
  }
  @override
  String toString() => 'SolaxRecord(redacted)';
}

abstract interface class SolaxStore {
  Future<SolaxRecord> read();
  Future<void> write(SolaxRecord record);
}

class SecureSolaxStore implements SolaxStore {
  SecureSolaxStore({
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
  static const connectionKey = 'solar_overview.solax.connection.v1';
  final String storageKey;
  final FlutterSecureStorage _storage;
  @override
  Future<SolaxRecord> read() async {
    try {
      final raw = await _storage.read(key: storageKey);
      return raw == null
          ? const SolaxRecord()
          : SolaxRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const SolaxFailure(
        'Could not open SolaX secure storage. Unlock your phone and retry storage.',
        kind: SolaxFailureKind.storage,
      );
    }
  }

  @override
  Future<void> write(SolaxRecord record) async {
    try {
      await _storage.write(key: storageKey, value: jsonEncode(record.toJson()));
    } catch (_) {
      throw const SolaxFailure(
        'Could not save SolaX securely. Unlock your phone and retry storage.',
        kind: SolaxFailureKind.storage,
      );
    }
  }
}
