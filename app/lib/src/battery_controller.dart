import 'dart:async';

import 'package:flutter/foundation.dart';

import 'battery.dart';
import 'battery_store.dart';

class BatteryController extends ChangeNotifier {
  BatteryController(this.store, this.source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final BatteryStore store;
  final BatterySource source;
  final DateTime Function() _now;
  static const interval = Duration(seconds: 30);
  static const receiptWindow = Duration(seconds: 90);
  BatteryRecord _record = const BatteryRecord();
  bool initialized = false;
  bool busy = false;
  bool storageUnavailable = false;
  bool _foreground = true;
  bool editingConnection = false;
  bool _saved = true;
  bool _disposed = false;
  String? error;
  BatteryReading? get reading => _record.reading;
  BatteryAddress? get address => _record.address;
  DateTime? get receivedAt => _record.receivedAt;
  bool get connected => address != null;
  DateTime get now => _now().toUtc();
  Duration? get receiptAge =>
      receivedAt == null ? null : now.difference(receivedAt!);
  bool get recentlyReceived =>
      !_saved &&
      _foreground &&
      !storageUnavailable &&
      receiptAge != null &&
      !receiptAge!.isNegative &&
      receiptAge! < receiptWindow;
  Duration get wait {
    final remaining = _record.nextAttempt?.difference(now) ?? Duration.zero;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get canRequest =>
      initialized &&
      !busy &&
      !storageUnavailable &&
      _foreground &&
      wait == Duration.zero;
  String get status => recentlyReceived
      ? 'Recently received · source time unknown'
      : reading != null
      ? 'Saved reading · current state unavailable'
      : 'No battery reading available';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _write(BatteryRecord next) async {
    try {
      await store.write(next);
      _record = next;
      return true;
    } catch (_) {
      storageUnavailable = true;
      _saved = true;
      error = 'Could not save battery data securely. Unlock your phone and retry battery storage.';
      return false;
    }
  }

  Future<void> initialize() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      _record = await store.read();
      storageUnavailable = false;
      _saved = true;
    } catch (_) {
      storageUnavailable = true;
      error = 'Could not open battery secure storage. Unlock your phone and retry battery storage.';
    }
    initialized = true;
    busy = false;
    _notify();
    if (connected && canRequest) await refresh();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground) _saved = true;
    _notify();
    if (foreground) tick();
  }

  void tick() {
    if (_disposed) return;
    _notify();
    if (connected && canRequest && !editingConnection) unawaited(refresh());
  }

  Future<bool> connect(String input) async {
    if (!canRequest || _disposed) return false;
    try {
      return await _fetch(BatteryAddress(input), replacing: true);
    } on BatteryFailure catch (failure) {
      error = failure.message;
      _notify();
      return false;
    }
  }

  Future<void> refresh() async {
    if (connected && canRequest && !_disposed) {
      await _fetch(address!, replacing: false);
    }
  }

  Future<bool> _fetch(BatteryAddress target, {required bool replacing}) async {
    busy = true;
    error = null;
    _notify();
    try {
      // Reserve the next attempt before network I/O. Restart cannot bypass waits.
      if (!await _write(
        _record.withGate(now.add(interval), _record.failures),
      )) {
        return false;
      }
      if (!_foreground || _disposed) return false;
      final value = await source.read(target);
      final received = now;
      final next = BatteryRecord(
        address: target,
        reading: value,
        receivedAt: received,
        nextAttempt: received.add(interval),
      );
      if (!await _write(next)) return false;
      _saved = !_foreground;
      return true;
    } catch (failure) {
      final message = failure is BatteryFailure
          ? failure.message
          : 'Could not read the battery. Check your home network and battery address.';
      if (!replacing) _saved = true;
      final failures = (_record.failures + 1).clamp(1, 4);
      final seconds = [60, 120, 240, 300][failures - 1];
      if (await _write(
        _record.withGate(now.add(Duration(seconds: seconds)), failures),
      )) {
        error = message;
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> disconnect() async {
    if (busy || _disposed) return false;
    busy = true;
    _notify();
    final success = await _write(
      BatteryRecord(
        nextAttempt: _record.nextAttempt,
        failures: _record.failures,
      ),
    );
    if (success) {
      error = null;
      storageUnavailable = false;
      _saved = true;
    }
    busy = false;
    _notify();
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
