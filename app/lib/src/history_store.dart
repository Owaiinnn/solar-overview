import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'history.dart';

class SavedHistory {
  const SavedHistory(this.identity, this.data, this.fetchedAt);
  final String identity;
  final ProductionHistory data;
  final DateTime fetchedAt;
  Map<String, dynamic> toJson() => {
    'identity': identity,
    'data': data.toJson(),
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };
  factory SavedHistory.fromJson(Map<String, dynamic> json) {
    final fetched = DateTime.parse(json['fetchedAt'] as String);
    if (!fetched.isUtc || json['identity'] is! String) {
      throw const FormatException();
    }
    return SavedHistory(
      json['identity'] as String,
      ProductionHistory.fromJson(json['data'] as Map<String, dynamic>),
      fetched,
    );
  }
}

abstract interface class HistoryStore {
  Future<List<SavedHistory>> read();
  Future<void> write(List<SavedHistory> entries);
}

class MemoryHistoryStore implements HistoryStore {
  List<SavedHistory> entries = [];
  @override
  Future<List<SavedHistory>> read() async => List.of(entries);
  @override
  Future<void> write(List<SavedHistory> entries) async {
    this.entries = List.of(entries);
  }
}

class SecureHistoryStore implements HistoryStore {
  SecureHistoryStore({
    FlutterSecureStorage? storage,
    this.storageKey = 'solar_overview.history.v1',
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked_this_device,
             ),
             aOptions: AndroidOptions(),
           );
  final FlutterSecureStorage _storage;
  final String storageKey;
  @override
  Future<List<SavedHistory>> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return [];
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1 || (json['entries'] as List).length > 35) {
      throw const FormatException();
    }
    return (json['entries'] as List)
        .map((entry) => SavedHistory.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> write(List<SavedHistory> entries) => _storage.write(
    key: storageKey,
    value: jsonEncode({
      'version': 1,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    }),
  );
}
