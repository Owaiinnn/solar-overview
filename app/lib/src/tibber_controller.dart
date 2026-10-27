import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tibber.dart';
import 'tibber_store.dart';

class TibberController extends ChangeNotifier {
  TibberController(this.store, this.source, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final TibberStore store;
  final TibberSource source;
  final DateTime Function() _now;
  static const requestWait = Duration(minutes: 15);
  TibberRecord _record = const TibberRecord();
  String? _draftToken;
  DateTime? _draftReceived;
  List<TibberHome> candidates = const [];
  bool initialized = false;
  bool busy = false;
  bool storageUnavailable = false;
  bool editing = false;
  bool _foreground = true;
  bool _disposed = false;
  int _draftRevision = 0;
  bool saved = true;
  String? error;
  DateTime get now => _now().toUtc();
  TibberHome? get home => _record.home;
  DateTime? get receivedAt => _record.receivedAt;
  bool get connected => home != null;
  bool get authorizationRequired => _record.authorizationRequired;
  Duration get wait {
    final value = _record.nextAttempt?.difference(now) ?? Duration.zero;
    return value.isNegative ? Duration.zero : value;
  }

  bool get canRequest =>
      initialized &&
      !busy &&
      !storageUnavailable &&
      _foreground &&
      !_disposed &&
      wait == Duration.zero;
  PriceInterval? get current => home?.current(now);
  Duration get nextTick {
    final time = now;
    var delay = const Duration(seconds: 30);
    for (final price in home?.prices ?? <PriceInterval>[]) {
      for (final boundary in [price.start, price.end]) {
        final remaining = boundary.difference(time);
        if (remaining > Duration.zero && remaining < delay) delay = remaining;
      }
    }
    return delay;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> _write(TibberRecord record) async {
    try {
      await store.write(record);
      _record = record;
      return true;
    } catch (_) {
      storageUnavailable = true;
      saved = true;
      error = 'Could not save Tibber securely. Unlock your phone and retry Tibber storage.';
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
      saved = true;
    } catch (_) {
      storageUnavailable = true;
      error = 'Could not open Tibber secure storage. Unlock your phone and retry Tibber storage.';
    }
    initialized = true;
    busy = false;
    _notify();
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) saved = true;
    if (value) tick();
  }

  void tick() {
    if (_disposed) return;
    _notify();
    final due = _record.nextRefresh;
    if (connected &&
        canRequest &&
        !editing &&
        !authorizationRequired &&
        (due == null || !now.isBefore(due))) {
      unawaited(refresh());
    }
  }

  void beginEditing() {
    editing = true;
    cancelDraft();
  }

  void cancelDraft() {
    _draftRevision++;
    _draftToken = null;
    _draftReceived = null;
    candidates = const [];
    _notify();
  }

  void finishEditing() {
    cancelDraft();
    editing = false;
    _notify();
  }

  Future<bool> discover(String input, PriceResolution resolution) async {
    if (!canRequest) return false;
    final token = input.trim();
    if (token.isEmpty || token.length > 4096 || RegExp(r'\s').hasMatch(token)) {
      error = 'Enter a valid Tibber personal token.';
      _notify();
      return false;
    }
    editing = true;
    cancelDraft();
    return _request(token, resolution, replacing: true);
  }

  DateTime _nextRefresh(TibberHome home, DateTime time) {
    final local = home.local(time);
    final hours = home.forDay(time, 1).isEmpty && local.hour >= 13 ? 1 : 6;
    final next = time.add(Duration(hours: hours));
    final midnight = home.day(time, 1).toUtc();
    return midnight.isBefore(next) ? midnight : next;
  }

  Future<bool> saveHome(String id) async {
    if (busy ||
        _disposed ||
        storageUnavailable ||
        !editing ||
        _draftToken == null) {
      return false;
    }
    final matches = candidates.where((h) => h.id == id);
    if (matches.length != 1) return false;
    final selected = matches.single;
    busy = true;
    _notify();
    final success = await _write(
      TibberRecord(
        token: _draftToken,
        home: selected,
        receivedAt: _draftReceived,
        nextAttempt: _record.nextAttempt,
        nextRefresh: _nextRefresh(selected, now),
      ),
    );
    if (success) {
      saved = !_foreground;
      error = null;
      finishEditing();
    }
    busy = false;
    _notify();
    return success;
  }

  Future<void> refresh() async {
    if (!connected || !canRequest || authorizationRequired || editing) return;
    await _request(_record.token!, home!.resolution, replacing: false);
  }

  Future<bool> _request(
    String token,
    PriceResolution resolution, {
    required bool replacing,
  }) async {
    final revision = _draftRevision;
    busy = true;
    error = null;
    _notify();
    try {
      if (!await _write(_record.withGate(now.add(requestWait)))) return false;
      if (!_foreground || _disposed) return false;
      final values = await source.read(
        token,
        resolution,
        homeId: replacing ? null : home!.id,
      );
      if (_disposed || (replacing && revision != _draftRevision)) return false;
      if (values.isEmpty) {
        throw const TibberFailure(
          'No homes were found for this Tibber account.',
        );
      }
      if (replacing) {
        _draftToken = token;
        _draftReceived = now;
        candidates = List.unmodifiable(values);
      } else {
        if (values.length != 1 || values.single.id != home!.id) {
          throw const TibberFailure(
            'Tibber returned a different home. Review your connection in Settings.',
          );
        }
        if (!await _write(
          TibberRecord(
            token: token,
            home: values.single,
            receivedAt: now,
            nextAttempt: _record.nextAttempt,
            nextRefresh: _nextRefresh(values.single, now),
          ),
        )) {
          return false;
        }
        saved = !_foreground;
      }
      return true;
    } catch (failure) {
      if (_disposed) return false;
      final failures = (_record.failures + 1).clamp(1, 4);
      final retry = failure is TibberFailure ? failure.retryAfter : null;
      final backoff = Duration(minutes: [15, 30, 60, 120][failures - 1]);
      final next = now.add(retry != null && retry > backoff ? retry : backoff);
      if (!replacing) saved = true;
      if (await _write(
        _record.withGate(
          next,
          failures: failures,
          authorizationRequired: replacing
              ? _record.authorizationRequired
              : failure is TibberFailure && failure.authentication,
          nextRefresh: next,
        ),
      )) {
        error = failure is TibberFailure
            ? failure.message
            : 'Could not load Tibber prices. Saved prices remain available.';
      }
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> disconnect() async {
    if (busy || _disposed || storageUnavailable) return false;
    busy = true;
    _notify();
    final result = await _write(
      TibberRecord(
        nextAttempt: _record.nextAttempt,
        failures: _record.failures,
      ),
    );
    if (result) {
      finishEditing();
      saved = true;
      error = null;
    }
    busy = false;
    _notify();
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _draftToken = null;
    candidates = const [];
    super.dispose();
  }
}
