import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'solaredge.dart';

class ReadingCache {
  const ReadingCache({
    this.siteId,
    this.overview,
    this.fetchedAt,
    this.nextAttempt,
    this.rateLimited = false,
  });

  final String? siteId;
  final SolarOverview? overview;
  final DateTime? fetchedAt;
  final DateTime? nextAttempt;
  final bool rateLimited;

  ReadingCache withGate(DateTime next, {bool limited = false}) => ReadingCache(
    siteId: siteId,
    overview: overview,
    fetchedAt: fetchedAt,
    nextAttempt: next,
    rateLimited: limited,
  );

  ReadingCache withoutReading() =>
      ReadingCache(nextAttempt: nextAttempt, rateLimited: rateLimited);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'siteId': siteId,
    'overview': overview?.toJson(),
    'timeZone': overview?.timeZone,
    'fetchedAt': fetchedAt?.toUtc().toIso8601String(),
    'nextAttempt': nextAttempt?.toUtc().toIso8601String(),
    'rateLimited': rateLimited,
  };

  factory ReadingCache.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException();
    DateTime? date(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String || !value.endsWith('Z')) {
        throw const FormatException();
      }
      return DateTime.parse(value);
    }

    final overview = json['overview'];
    return ReadingCache(
      siteId: json['siteId'] as String?,
      overview: overview == null
          ? null
          : SolarOverview.fromJson(
              overview as Map<String, dynamic>,
              timeZone: json['timeZone'] as String?,
            ),
      fetchedAt: date('fetchedAt'),
      nextAttempt: date('nextAttempt'),
      rateLimited: json['rateLimited'] as bool,
    );
  }
}

abstract interface class ReadingStore {
  Future<ReadingCache> read();
  Future<void> write(ReadingCache cache);
}

class MemoryReadingStore implements ReadingStore {
  ReadingCache cache = const ReadingCache();
  @override
  Future<ReadingCache> read() async => cache;
  @override
  Future<void> write(ReadingCache value) async => cache = value;
}

class SecureReadingStore implements ReadingStore {
  SecureReadingStore({
    FlutterSecureStorage? storage,
    this.storageKey = cacheKey,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
             aOptions: AndroidOptions(),
           );
  static const cacheKey = 'solar_overview.solaredge.readings.v1';
  final FlutterSecureStorage _storage;
  final String storageKey;

  @override
  Future<ReadingCache> read() async {
    try {
      final raw = await _storage.read(key: storageKey);
      return raw == null
          ? const ReadingCache()
          : ReadingCache.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      throw const SolarEdgeFailure(
        'Could not open saved readings and refresh limits. Unlock your phone and retry storage in Settings.',
      );
    }
  }

  @override
  Future<void> write(ReadingCache cache) async {
    try {
      await _storage.write(key: storageKey, value: jsonEncode(cache.toJson()));
    } catch (_) {
      throw const SolarEdgeFailure(
        'Could not save readings and refresh limits securely. Unlock your phone and retry storage in Settings.',
      );
    }
  }
}
