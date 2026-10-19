import 'package:flutter/foundation.dart';

import 'connection_controller.dart';
import 'history.dart';
import 'history_store.dart';
import 'site_time.dart';
import 'solaredge.dart';
import 'solax.dart';
import 'solax_controller.dart';

enum HistorySource { solarEdge, solax }

class HistorySourceState {
  bool loading = false;
  String? error;
  SavedHistory? saved;
}

class HistoryController extends ChangeNotifier {
  HistoryController(
    this.edge,
    this.solax,
    this._store, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    selectedDay = DateTime.utc(_now().year, _now().month, _now().day);
    edge.addListener(_connectionsChanged);
    solax?.addListener(_connectionsChanged);
  }
  final ConnectionController edge;
  final SolaxController? solax;
  final HistoryStore _store;
  final DateTime Function() _now;
  late DateTime selectedDay;
  final states = {
    for (final source in HistorySource.values) source: HistorySourceState(),
  };
  List<SavedHistory> _entries = [];
  bool initialized = false;
  bool _selectionChosen = false;
  bool _disposed = false;
  String? storageError;
  Future<void> _writes = Future.value();

  String? identity(HistorySource source) => switch (source) {
    HistorySource.solarEdge =>
      edge.historyIdentity == null ? null : 'edge:${edge.historyIdentity}',
    HistorySource.solax => solax?.historyIdentity,
  };
  String? timeZone(HistorySource source) => switch (source) {
    HistorySource.solarEdge => edge.historyTimeZone,
    HistorySource.solax => solax?.historyTimeZone,
  };
  bool busy(HistorySource source) => switch (source) {
    HistorySource.solarEdge => edge.busy || edge.storageUnavailable,
    HistorySource.solax =>
      solax == null ||
          solax!.busy ||
          solax!.storageUnavailable ||
          solax!.selecting,
  };
  String? waitNotice(HistorySource source) => switch (source) {
    HistorySource.solarEdge => edge.refreshNotice,
    HistorySource.solax => solax?.refreshNotice,
  };
  DateTime today(HistorySource source) {
    final zone = siteToday(timeZone(source), _now());
    return zone ?? DateTime.utc(_now().year, _now().month, _now().day);
  }

  Future<void> initialize() async {
    try {
      _entries = await _store.read();
      storageError = null;
    } catch (_) {
      storageError = 'Saved history could not be opened. Retry saved history before loading new data.';
    }
    initialized = true;
    _selectSaved();
    _notify();
  }

  Future<void> clearSavedHistory() async {
    if (states.values.any((state) => state.loading)) return;
    try {
      final write = _writes.then((_) => _store.write([]));
      _writes = write.catchError((Object _) {});
      await write;
      _entries = [];
      storageError = null;
      initialized = true;
      _selectSaved();
    } catch (_) {
      storageError =
          'Saved history could not be cleared. Unlock your phone and retry.';
    }
    _notify();
  }

  void _connectionsChanged() {
    _selectSaved();
    _notify();
  }

  void _selectSaved() {
    if (!_selectionChosen) {
      final localDay = siteToday(
        edge.historyTimeZone ?? solax?.historyTimeZone,
        _now(),
      );
      if (localDay != null) selectedDay = localDay;
    }
    for (final source in HistorySource.values) {
      final matches = _entries.where(
        (entry) =>
            entry.identity == identity(source) &&
            entry.data.day.timeZone == timeZone(source) &&
            historyDate(entry.data.day.date) == historyDate(selectedDay),
      );
      states[source]!.saved = matches.isEmpty ? null : matches.last;
    }
  }

  void selectDay(DateTime date) {
    _selectionChosen = true;
    selectedDay = DateTime.utc(date.year, date.month, date.day);
    for (final state in states.values) {
      state.error = null;
    }
    _selectSaved();
    _notify();
  }

  Map<String, double?> dailyEnergy(HistorySource source) {
    final matches = _entries.where(
      (entry) =>
          entry.identity == identity(source) &&
          entry.data.day.timeZone == timeZone(source) &&
          historyMonth(entry.data.day.date) == historyMonth(selectedDay),
    );
    if (matches.isEmpty) return {};
    final lastDay = historyDate(today(source));
    return Map.fromEntries(
      matches.last.data.dailyWh.entries.where(
        (entry) => entry.key.compareTo(lastDay) <= 0,
      ),
    );
  }

  Future<void> load(HistorySource source) async {
    final state = states[source]!;
    final account = identity(source);
    final zone = timeZone(source);
    if (!initialized ||
        storageError != null ||
        state.loading ||
        busy(source) ||
        account == null ||
        siteLocation(zone) == null ||
        selectedDay.isAfter(today(source))) {
      return;
    }
    final day = HistoryDay(selectedDay, zone!);
    state.loading = true;
    state.error = null;
    _notify();
    try {
      final data = await switch (source) {
        HistorySource.solarEdge => edge.loadHistory(day),
        HistorySource.solax => solax!.loadHistory(day),
      };
      if (account != identity(source) || zone != timeZone(source)) return;
      final entry = SavedHistory(account, data, _now().toUtc());
      final write = _writes.then((_) async {
        final entries =
            _entries
                .where(
                  (old) =>
                      old.identity != account ||
                      historyDate(old.data.day.date) != historyDate(day.date),
                )
                .toList()
              ..add(entry);
        if (entries.length > 35) entries.removeRange(0, entries.length - 35);
        await _store.write(entries);
        _entries = entries;
      });
      _writes = write.catchError((Object _) {});
      await write;
      _selectSaved();
    } catch (failure) {
      final message = failure is SolarEdgeFailure
          ? failure.message
          : failure is SolaxFailure
          ? failure.message
          : 'History could not be loaded or saved. Your saved readings are retained; retry later.';
      if (account == identity(source) &&
          historyDate(day.date) == historyDate(selectedDay)) {
        state.error = message;
      }
      _selectSaved();
    } finally {
      state.loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    edge.removeListener(_connectionsChanged);
    solax?.removeListener(_connectionsChanged);
    super.dispose();
  }
}

String historySourceName(HistorySource source) => switch (source) {
  HistorySource.solarEdge => 'SolarEdge',
  HistorySource.solax => 'SolaX',
};
