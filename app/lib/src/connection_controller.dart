import 'package:flutter/foundation.dart';

import 'credential_store.dart';
import 'solaredge.dart';

class ConnectionController extends ChangeNotifier {
  ConnectionController(this._store, this._source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final CredentialStore _store;
  final SolarEdgeSource _source;
  final DateTime Function() _now;
  SolarEdgeCredentials? _credentials;
  DateTime? _lastAttempt;
  SolarOverview? overview;
  bool busy = false;
  bool initialized = false;
  bool storageUnavailable = false;
  String? error;

  String? get siteId => _credentials?.siteId;
  bool get connected => _credentials != null;

  Future<void> initialize() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    var storageRead = false;
    try {
      _credentials = await _store.read();
      storageRead = true;
      storageUnavailable = false;
      if (_credentials != null) {
        _lastAttempt = _now();
        overview = await _source.overview(_credentials!);
      }
    } on SolarEdgeFailure catch (failure) {
      storageUnavailable = !storageRead;
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
    try {
      final candidate = SolarEdgeCredentials(siteId, apiKey);
      final reading = await _source.overview(candidate);
      // Validate first. Invalid replacement credentials never overwrite the
      // existing connection. Do not claim success until secure storage succeeds.
      await _store.write(candidate);
      _credentials = candidate;
      overview = reading;
      _lastAttempt = _now();
      return true;
    } on SolarEdgeFailure catch (failure) {
      error = failure.message;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (busy || _credentials == null) return;
    if (_lastAttempt != null &&
        _now().difference(_lastAttempt!) < const Duration(minutes: 5)) {
      error = 'Please wait five minutes between refreshes. SolarEdge readings are cloud updates.';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    _lastAttempt = _now();
    notifyListeners();
    try {
      overview = await _source.overview(_credentials!);
    } on SolarEdgeFailure catch (failure) {
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
      await _store.delete();
      _credentials = null;
      overview = null;
      _lastAttempt = null;
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
