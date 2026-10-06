import 'package:flutter/foundation.dart';

import 'credential_store.dart';
import 'reading_store.dart';
import 'solar_freshness.dart';
import 'solaredge.dart';

class ConnectionController extends ChangeNotifier {
  ConnectionController(
    this._store,
    this._source, {
    ReadingStore? readingStore,
    DateTime Function()? now,
  }) : _readingStore = readingStore ?? MemoryReadingStore(),
       _now = now ?? DateTime.now;

  static const refreshInterval = Duration(minutes: 15);
  final CredentialStore _store;
  final SolarEdgeSource _source;
  final ReadingStore _readingStore;
  final DateTime Function() _now;
  SolarEdgeCredentials? _credentials;
  ReadingCache _cache = const ReadingCache();
  bool _cacheLoaded = false;
  SolarOverview? overview;
  bool busy = false;
  bool initialized = false;
  bool storageUnavailable = false;
  bool usingSavedReading = false;
  String? error;

  String? get siteId => _credentials?.siteId;
  bool get connected => _credentials != null;
  ReadingFreshness get freshness =>
      overview?.freshness(_now()) ?? ReadingFreshness.unknown;
  double? get todayEnergyWh => overview?.todayEnergyWh(_now());
  DateTime? get fetchedAt => _cache.fetchedAt;
  bool get canRequest =>
      _cache.nextAttempt == null ||
      !_now().toUtc().isBefore(_cache.nextAttempt!);
  String? get refreshNotice {
    if (canRequest) return null;
    final minutes =
        (_cache.nextAttempt!.difference(_now().toUtc()).inSeconds / 60)
            .ceil()
            .clamp(1, 999999);
    return _cache.rateLimited
        ? 'SolarEdge request limit reached. Try again in $minutes minutes.'
        : 'Next request available in $minutes minutes.';
  }

  void updateFreshness() => notifyListeners();

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    try {
      _cache = await _readingStore.read();
      _cacheLoaded = true;
    } on SolarEdgeFailure {
      storageUnavailable = true;
      rethrow;
    }
  }

  Future<void> _persist(ReadingCache value) async {
    _cache = value;
    try {
      await _readingStore.write(value);
    } on SolarEdgeFailure {
      storageUnavailable = true;
      rethrow;
    }
  }

  Future<SolarOverview> _request(SolarEdgeCredentials credentials) async {
    await _loadCache();
    if (!canRequest) throw SolarEdgeFailure(refreshNotice!);
    await _persist(_cache.withGate(_now().toUtc().add(refreshInterval)));
    try {
      return await _source.overview(credentials);
    } on SolarEdgeFailure catch (failure) {
      if (failure.rateLimited) {
        await _persist(
          _cache.withGate(
            _now().toUtc().add(const Duration(hours: 24)),
            limited: true,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _saveReading(SolarOverview reading) async {
    overview = reading;
    usingSavedReading = false;
    await _persist(
      ReadingCache(
        siteId: siteId,
        overview: reading,
        fetchedAt: _now().toUtc(),
        nextAttempt: _cache.nextAttempt,
      ),
    );
  }

  Future<void> initialize() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      try {
        _credentials = await _store.read();
      } on SolarEdgeFailure {
        storageUnavailable = true;
        rethrow;
      }
      await _loadCache();
      if (storageUnavailable) await _persist(_cache);
      storageUnavailable = false;
      overview = _credentials != null && _cache.siteId == siteId
          ? _cache.overview
          : null;
      usingSavedReading = overview != null;
      if (_credentials != null && canRequest) {
        await _saveReading(await _request(_credentials!));
      }
    } on SolarEdgeFailure catch (failure) {
      error = failure.message;
    } finally {
      initialized = true;
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> connect(String siteId, String apiKey) async {
    if (busy || storageUnavailable) return false;
    busy = true;
    error = null;
    notifyListeners();
    var saved = false;
    try {
      final candidate = SolarEdgeCredentials(siteId, apiKey);
      final reading = await _request(candidate);
      final previousCache = _cache;
      await _persist(_cache.withoutReading());
      try {
        await _store.write(candidate);
      } on SolarEdgeFailure {
        await _persist(previousCache);
        rethrow;
      }
      _credentials = candidate;
      saved = true;
      await _saveReading(reading);
      return true;
    } on SolarEdgeFailure catch (failure) {
      error = failure.message;
      return saved;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (busy || _credentials == null || storageUnavailable) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _saveReading(await _request(_credentials!));
    } on SolarEdgeFailure catch (failure) {
      usingSavedReading = overview != null;
      error = failure.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> disconnect() async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!_cacheLoaded) {
        try {
          await _loadCache();
        } on SolarEdgeFailure {
          _cache = ReadingCache(
            nextAttempt: _now().toUtc().add(const Duration(hours: 24)),
            rateLimited: true,
          );
        }
      }
      await _persist(_cache.withoutReading());
      _cacheLoaded = true;
      await _store.delete();
      _credentials = null;
      overview = null;
      usingSavedReading = false;
      storageUnavailable = false;
      return true;
    } on SolarEdgeFailure catch (failure) {
      error = failure.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
