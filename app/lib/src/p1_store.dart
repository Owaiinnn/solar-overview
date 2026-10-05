import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'p1.dart';

class P1Record {
  const P1Record({
    this.address,
    this.reading,
    this.receivedAt,
    this.nextAttempt,
    this.failures = 0,
    this.counterReset = false,
  });
  final P1Address? address;
  final P1Reading? reading;
  final DateTime? receivedAt;
  final DateTime? nextAttempt;
  final int failures;
  final bool counterReset;
  P1Record withGate(DateTime next, int failures) => P1Record(
    address: address,
    reading: reading,
    receivedAt: receivedAt,
    nextAttempt: next,
    failures: failures,
    counterReset: counterReset,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'address': address?.host,
    'reading': reading?.toJson(),
    'receivedAt': receivedAt?.toUtc().toIso8601String(),
    'nextAttempt': nextAttempt?.toUtc().toIso8601String(),
    'failures': failures,
    'counterReset': counterReset,
  };
  factory P1Record.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException();
    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || !value.endsWith('Z')) {
        throw const FormatException();
      }
      final parsed = DateTime.parse(value);
      if (parsed.toIso8601String() != value) throw const FormatException();
      return parsed;
    }

    final address = json['address'] == null
        ? null
        : P1Address(json['address'] as String);
    final reading = json['reading'] == null
        ? null
        : P1Reading.fromJson(json['reading'] as Map<String, dynamic>);
    final received = date('receivedAt');
    final failures = json['failures'] as int;
    if ((reading == null) != (received == null) ||
        (reading != null && address == null) ||
        failures < 0 ||
        failures > 4) {
      throw const FormatException();
    }
    return P1Record(
      address: address,
      reading: reading,
      receivedAt: received,
      nextAttempt: date('nextAttempt'),
      failures: failures,
      counterReset: json['counterReset'] as bool,
    );
  }
  @override
  String toString() => 'P1Record(redacted)';
}

abstract interface class P1Store {
  Future<P1Record> read();
  Future<void> write(P1Record record);
}

class SecureP1Store implements P1Store {
  SecureP1Store({
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
  static const connectionKey = 'solar_overview.p1.connection.v1';
  final FlutterSecureStorage storage;
  final String storageKey;
  @override
  Future<P1Record> read() async {
    final raw = await storage.read(key: storageKey);
    return raw == null
        ? const P1Record()
        : P1Record.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(P1Record record) =>
      storage.write(key: storageKey, value: jsonEncode(record.toJson()));
}
