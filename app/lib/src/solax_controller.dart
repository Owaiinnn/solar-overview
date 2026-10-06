import 'package:flutter/foundation.dart';

import 'solax.dart';
import 'solax_store.dart';
import 'solaredge.dart' show ReadingFreshness;

class SolaxController extends ChangeNotifier {
  SolaxController(this._store, this._source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final SolaxStore _store;
  final SolaxSource _source;
  final DateTime Function() _now;
  static const refreshInterval = Duration(minutes: 15);
  SolaxRecord _record = const SolaxRecord();
  SolaxRecord? _recovery;
  bool _loaded = false;
  bool busy = false;
  bool initialized = false;
  bool storageUnavailable = false;
  bool usingSavedReading = false;
  String? error;
  SolaxCredentials? _candidate;
  SolaxToken? _candidateToken;
  DateTime? _discoveryDeadline;
  int _plantQueries = 0;
  List<SolaxPlant> plants = [];
  List<SolaxDevice> devices = [];
  SolaxPlant? selectedPlant;
  SolaxDevice? selectedDevice;
  SolaxReading? get reading => _record.reading;
  bool get connected => _record.credentials != null && _record.device != null;
  bool get reconnectRequired => _record.reconnectRequired;
  bool get selecting => _candidate != null;
  bool get canRequest =>
      !busy &&
      !storageUnavailable &&
      (_record.nextAttempt == null ||
          !_now().toUtc().isBefore(_record.nextAttempt!));
  ReadingFreshness get freshness =>
      reading?.freshness(_now()) ?? ReadingFreshness.unknown;
  double? get todayEnergyWh => reading?.todayEnergyWh(_now());
  String? get refreshNotice {
    final next = (_recovery ?? _record).nextAttempt;
    if (next == null || !next.isAfter(_now().toUtc())) return null;
    final minutes = (next.difference(_now().toUtc()).inSeconds / 60)
        .ceil()
        .clamp(1, 999999);
    return (_recovery ?? _record).rateLimited
        ? 'SolaX request limit reached. Try again in $minutes minutes.'
        : 'Next SolaX request available in $minutes minutes.';
  }

  void updateFreshness() => notifyListeners();

  Future<void> _persist(SolaxRecord value, {bool recoverValue = false}) async {
    try {
      await _store.write(value);
      _record = value;
      _recovery = null;
    } catch (_) {
      _recovery = recoverValue ? value : _record;
      storageUnavailable = true;
      throw const SolaxFailure(
        'Could not save SolaX securely. Unlock your phone and retry storage.',
        kind: SolaxFailureKind.storage,
      );
    }
  }

  Future<void> _reserve() async {
    if (refreshNotice != null) throw SolaxFailure(refreshNotice!);
    await _persist(
      _record.withGate(_now().toUtc().add(refreshInterval)),
      recoverValue: true,
    );
  }

  Future<SolaxToken> _token() async {
    if (_record.reconnectRequired) {
      throw const SolaxFailure(
        'SolaX access needs attention. Use a dedicated application for this phone, then replace the connection.',
      );
    }
    final existing = _record.token;
    if (existing != null && existing.usable(_now())) return existing;
    final token = await _source.authenticate(_record.credentials!);
    await _persist(_record.withToken(token), recoverValue: true);
    return token;
  }

  Future<void> _failure(Object failure, {bool savedAccount = false}) async {
    final safe = failure is SolaxFailure
        ? failure
        : const SolaxFailure(
            'SolaX could not complete the request. Retry later.',
          );
    error = safe.message;
    usingSavedReading = reading != null;
    try {
      if (safe.kind == SolaxFailureKind.rateLimit) {
        await _persist(
          _record.withGate(
            _now().toUtc().add(const Duration(hours: 24)),
            limited: true,
          ),
          recoverValue: true,
        );
      } else if (savedAccount &&
          (safe.kind == SolaxFailureKind.revoked ||
              safe.kind == SolaxFailureKind.authentication)) {
        await _persist(
          _record.withToken(null, revoked: true),
          recoverValue: true,
        );
      }
    } on SolaxFailure catch (storage) {
      error = '${safe.message} ${storage.message}';
    }
  }

  Future<void> initialize() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!_loaded) {
        try {
          _record = await _store.read();
          _loaded = true;
        } catch (_) {
          storageUnavailable = true;
          throw const SolaxFailure(
            'Could not open SolaX secure storage. Unlock your phone and retry storage.',
            kind: SolaxFailureKind.storage,
          );
        }
      }
      if (_recovery != null) await _persist(_recovery!, recoverValue: true);
      storageUnavailable = false;
      usingSavedReading = reading != null;
      if (connected && !reconnectRequired && refreshNotice == null) {
        await _reserve();
        await _refreshReading();
      }
    } catch (failure) {
      await _failure(failure, savedAccount: true);
    } finally {
      initialized = true;
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _refreshReading() async {
    final token = await _token();
    final result = await _source.reading(
      token,
      _record.plant!,
      _record.device!,
    );
    await _persist(
      SolaxRecord(
        credentials: _record.credentials,
        token: token,
        plant: _record.plant,
        device: _record.device,
        reading: result,
        fetchedAt: _now().toUtc(),
        nextAttempt: _record.nextAttempt,
      ),
    );
    usingSavedReading = false;
  }

  Future<void> refresh() async {
    if (busy || storageUnavailable || !connected || selecting) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _reserve();
      await _refreshReading();
    } catch (failure) {
      await _failure(failure, savedAccount: true);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> discover(String clientId, String secret) async {
    if (busy || storageUnavailable || !initialized) return false;
    busy = true;
    error = null;
    _clearSelection();
    notifyListeners();
    var sameAccount = false;
    try {
      final candidate = SolaxCredentials(clientId, secret);
      sameAccount = _record.credentials?.sameAccount(candidate) ?? false;
      await _reserve();
      var token = sameAccount && !reconnectRequired ? _record.token : null;
      if (token == null || !token.usable(_now())) {
        token = await _source.authenticate(candidate);
        if (sameAccount) {
          await _persist(_record.withToken(token), recoverValue: true);
        }
      }
      final found = await _source.plants(token);
      _candidate = candidate;
      _candidateToken = token;
      _discoveryDeadline = _now().toUtc().add(refreshInterval);
      plants = List.unmodifiable(found);
      return true;
    } catch (failure) {
      await _failure(failure, savedAccount: sameAccount);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _checkSelectionSession() {
    if (_candidate == null ||
        _candidateToken == null ||
        _discoveryDeadline == null ||
        !_now().toUtc().isBefore(_discoveryDeadline!) ||
        !_candidateToken!.usable(_now())) {
      throw const SolaxFailure(
        'SolaX selection expired. Test the connection again.',
      );
    }
  }

  Future<void> selectPlant(SolaxPlant plant) async {
    if (busy || storageUnavailable || !plants.contains(plant)) return;
    busy = true;
    error = null;
    devices = [];
    selectedDevice = null;
    selectedPlant = null;
    notifyListeners();
    try {
      _checkSelectionSession();
      if (++_plantQueries > 5) {
        throw const SolaxFailure(
          'SolaX selection request limit reached. Test again after the wait.',
        );
      }
      devices = List.unmodifiable(
        await _source.devices(_candidateToken!, plant),
      );
      selectedPlant = plant;
    } catch (failure) {
      await _failure(
        failure,
        savedAccount:
            _candidate != null &&
            (_record.credentials?.sameAccount(_candidate!) ?? false),
      );
      _clearSelection();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void selectDevice(SolaxDevice device) {
    if (busy || !devices.contains(device) || !device.supported) return;
    selectedDevice = device;
    notifyListeners();
  }

  Future<bool> saveSelection() async {
    if (busy ||
        storageUnavailable ||
        selectedPlant == null ||
        selectedDevice == null) {
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      _checkSelectionSession();
      final result = await _source.reading(
        _candidateToken!,
        selectedPlant!,
        selectedDevice!,
      );
      await _persist(
        SolaxRecord(
          credentials: _candidate,
          token: _candidateToken,
          plant: selectedPlant,
          device: selectedDevice,
          reading: result,
          fetchedAt: _now().toUtc(),
          nextAttempt: _record.nextAttempt,
        ),
      );
      usingSavedReading = false;
      _clearSelection();
      return true;
    } catch (failure) {
      await _failure(
        failure,
        savedAccount:
            _candidate != null &&
            (_record.credentials?.sameAccount(_candidate!) ?? false),
      );
      _clearSelection();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _clearSelection() {
    _candidate = null;
    _candidateToken = null;
    _discoveryDeadline = null;
    plants = [];
    devices = [];
    selectedPlant = null;
    selectedDevice = null;
    _plantQueries = 0;
  }

  void cancelSelection() {
    if (!busy) {
      _clearSelection();
      notifyListeners();
    }
  }

  Future<bool> disconnect() async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!_loaded) {
        try {
          _record = await _store.read();
        } catch (_) {
          _record = SolaxRecord(
            nextAttempt: _now().toUtc().add(const Duration(hours: 24)),
            rateLimited: true,
          );
        }
      }
      await _persist(
        (_recovery ?? _record).withoutConnection(),
        recoverValue: true,
      );
      _loaded = true;
      storageUnavailable = false;
      usingSavedReading = false;
      _clearSelection();
      return true;
    } catch (failure) {
      await _failure(failure);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
