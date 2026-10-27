import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tibber.dart';

class TibberRecord {
  const TibberRecord({
    this.token,
    this.home,
    this.receivedAt,
    this.nextAttempt,
    this.nextRefresh,
    this.failures = 0,
    this.authorizationRequired = false,
  });
  final String? token;
  final TibberHome? home;
  final DateTime? receivedAt;
  final DateTime? nextAttempt;
  final DateTime? nextRefresh;
  final int failures;
  final bool authorizationRequired;
  TibberRecord withGate(
    DateTime next, {
    int? failures,
    bool? authorizationRequired,
    DateTime? nextRefresh,
  }) => TibberRecord(
    token: token,
    home: home,
    receivedAt: receivedAt,
    nextAttempt: next,
    nextRefresh: nextRefresh ?? this.nextRefresh,
    failures: failures ?? this.failures,
    authorizationRequired: authorizationRequired ?? this.authorizationRequired,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'token': token,
    'home': home?.toJson(),
    'receivedAt': receivedAt?.toUtc().toIso8601String(),
    'nextAttempt': nextAttempt?.toUtc().toIso8601String(),
    'nextRefresh': nextRefresh?.toUtc().toIso8601String(),
    'failures': failures,
    'authorizationRequired': authorizationRequired,
  };
  factory TibberRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException();
    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || !value.endsWith('Z')) {
        throw const FormatException();
      }
      return DateTime.parse(value);
    }

    final token = json['token'] as String?;
    final home = json['home'] == null
        ? null
        : TibberHome.fromJson(json['home'] as Map<String, dynamic>);
    final received = date('receivedAt');
    final failures = json['failures'] as int;
    if ((token == null) != (home == null) ||
        (home == null) != (received == null) ||
        (token != null &&
            (token.isEmpty ||
                token.length > 4096 ||
                RegExp(r'\s').hasMatch(token))) ||
        failures < 0 ||
        failures > 4) {
      throw const FormatException();
    }
    return TibberRecord(
      token: token,
      home: home,
      receivedAt: received,
      nextAttempt: date('nextAttempt'),
      nextRefresh: date('nextRefresh'),
      failures: failures,
      authorizationRequired: json['authorizationRequired'] as bool,
    );
  }
  @override
  String toString() => 'TibberRecord(redacted)';
}

abstract interface class TibberStore {
  Future<TibberRecord> read();
  Future<void> write(TibberRecord record);
}

class SecureTibberStore implements TibberStore {
  SecureTibberStore({
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
  static const connectionKey = 'solar_overview.tibber.connection.v1';
  final FlutterSecureStorage storage;
  final String storageKey;
  @override
  Future<TibberRecord> read() async {
    final raw = await storage.read(key: storageKey);
    return raw == null
        ? const TibberRecord()
        : TibberRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(TibberRecord record) =>
      storage.write(key: storageKey, value: jsonEncode(record.toJson()));
}
