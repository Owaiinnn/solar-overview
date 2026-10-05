import 'dart:async';

import 'package:flutter/foundation.dart';

import 'p1.dart';
import 'p1_store.dart';

class P1Controller extends ChangeNotifier {
  P1Controller(this.store, this.source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final P1Store store;
  final P1Source source;
  final DateTime Function() _now;
  static const interval = Duration(seconds: 30);
  static const freshnessWindow = Duration(seconds: 90);
  static const clockTolerance = Duration(seconds: 5);
  P1Record _record = const P1Record();
  bool initialized = false;
  bool busy = false;
  bool storageUnavailable = false;
  bool _foreground = true;
  bool editingConnection = false;
  bool _saved = true;
  bool _disposed = false;
  String? error;
  P1Reading? get reading => _record.reading;
  P1Address? get address => _record.address;
  DateTime? get receivedAt => _record.receivedAt;
  bool get connected => address != null;
  DateTime get now => _now().toUtc();
  Duration? get receiptAge =>
      receivedAt == null ? null : now.difference(receivedAt!);
  bool get counterReset => _record.counterReset;
  Duration? get measurementAge =>
      reading == null ? null : now.difference(reading!.measuredAt);
  bool get current =>
      !_saved &&
      _foreground &&
      !storageUnavailable &&
      receiptAge != null &&
      !receiptAge!.isNegative &&
      receiptAge! < freshnessWindow &&
      measurementAge != null &&
      measurementAge! >= -clockTolerance &&
      measurementAge! < freshnessWindow;
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
  String get status => current
      ? 'Recent meter reading'
      : reading != null
      ? 'Saved meter reading · current grid exchange unavailable'
      : 'No meter reading available';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _write(P1Record next) async {
    if (_disposed) return false;
    try {
      await store.write(next);
      _record = next;
      return true;
    } catch (_) {
      storageUnavailable = true;
      _saved = true;
      error = 'Could not save P1 data securely. Unlock your phone and retry P1 storage.';
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
      error = 'Could not open P1 secure storage. Unlock your phone and retry P1 storage.';
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
      return await _fetch(P1Address(input), replacing: true);
    } on P1Failure catch (failure) {
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

  Future<bool> _fetch(P1Address target, {required bool replacing}) async {
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
      if (_disposed) return false;
      final received = now;
      if (value.measuredAt.isAfter(received.add(clockTolerance))) {
        throw const P1Failure(
          'The meter clock is ahead of this phone. Check the meter time before using current readings.',
        );
      }
      final previous = reading;
      if (!replacing && previous != null) {
        if (value.meterId != previous.meterId) {
          throw const P1Failure(
            'The meter identity changed. Test and replace the P1 connection in Settings to confirm the new meter.',
          );
        }
        if (value.measuredAt.isBefore(previous.measuredAt)) {
          throw const P1Failure(
            'The meter returned an older timestamp. Keeping the previous saved reading.',
          );
        }
        if (value.measuredAt == previous.measuredAt &&
            !mapEquals(value.fields, previous.fields)) {
          throw const P1Failure(
            'The meter changed readings without a new timestamp. Keeping the previous saved reading.',
          );
        }
      }
      final reset =
          !replacing &&
          previous != null &&
          value.countersDecreasedFrom(previous);
      final next = P1Record(
        address: target,
        reading: value,
        receivedAt: received,
        nextAttempt: received.add(interval),
        counterReset: reset || (!replacing && _record.counterReset),
      );
      if (!await _write(next)) return false;
      _saved = !_foreground;
      return true;
    } catch (failure) {
      final message = failure is P1Failure
          ? failure.message
          : 'Could not read the P1 meter. Check your home network and reader address.';
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
      P1Record(nextAttempt: _record.nextAttempt, failures: _record.failures),
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
