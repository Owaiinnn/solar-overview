import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'battery.dart';

class BatteryRecord {
  const BatteryRecord({
    this.address,
    this.reading,
    this.receivedAt,
    this.nextAttempt,
    this.failures = 0,
  });
  final BatteryAddress? address;
  final BatteryReading? reading;
  final DateTime? receivedAt;
  final DateTime? nextAttempt;
  final int failures;
  BatteryRecord withGate(DateTime next, int failures) => BatteryRecord(
    address: address,
    reading: reading,
    receivedAt: receivedAt,
    nextAttempt: next,
    failures: failures,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'address': address?.host,
    'reading': reading?.toJson(),
    'receivedAt': receivedAt?.toUtc().toIso8601String(),
    'nextAttempt': nextAttempt?.toUtc().toIso8601String(),
    'failures': failures,
  };
  factory BatteryRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException();
    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || !value.endsWith('Z')) {
        throw const FormatException();
      }
      return DateTime.parse(value);
    }

    final address = json['address'] == null
        ? null
        : BatteryAddress(json['address'] as String);
    final reading = json['reading'] == null
        ? null
        : BatteryReading.fromJson(json['reading'] as Map<String, dynamic>);
    final received = date('receivedAt');
    final failures = json['failures'] as int;
    if ((reading == null) != (received == null) ||
        (reading != null && address == null) ||
        failures < 0 ||
        failures > 4) {
      throw const FormatException();
    }
    return BatteryRecord(
      address: address,
      reading: reading,
      receivedAt: received,
      nextAttempt: date('nextAttempt'),
      failures: failures,
    );
  }
  @override
  String toString() => 'BatteryRecord(redacted)';
}

abstract interface class BatteryStore {
  Future<BatteryRecord> read();
  Future<void> write(BatteryRecord record);
}

class SecureBatteryStore implements BatteryStore {
  SecureBatteryStore({
    FlutterSecureStorage? storage,
    this.storageKey = connectionKey,
  }) : storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
             aOptions: AndroidOptions(),
           );
  static const connectionKey = 'solar_overview.battery.connection.v1';
  final FlutterSecureStorage storage;
  final String storageKey;
  @override
  Future<BatteryRecord> read() async {
    final raw = await storage.read(key: storageKey);
    return raw == null
        ? const BatteryRecord()
        : BatteryRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(BatteryRecord record) =>
      storage.write(key: storageKey, value: jsonEncode(record.toJson()));
}
