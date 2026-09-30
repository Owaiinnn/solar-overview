import 'dart:async';

import 'package:solar_overview/src/solax.dart';
import 'package:solar_overview/src/solax_store.dart';

final solaxNow = DateTime.utc(2026, 9, 29, 12);
const solaxPlant = SolaxPlant('synthetic-plant', 'Europe/Amsterdam');
const solaxDevice = SolaxDevice('synthetic-device', 'synthetic-plant', 28);
SolaxReading solaxReading({
  String stamp = '2026-09-29T12:00:00Z',
  double power = 120,
}) => SolaxReading.fromResponse({
  'dataTime': stamp,
  'plantLocalTime': '2026-09-29 14:00:00',
  'acPower1': power,
  'dailyACOutput': 1.2,
  'totalACOutput': 95.5,
  'deviceStatus': 102,
  'mpptMap': {'MPPT1Power': 50.0, 'MPPT2Power': 75.0},
}, 'Europe/Amsterdam');
SolaxRecord solaxRecord({
  DateTime? next,
  DateTime? expiry,
  bool revoked = false,
}) => SolaxRecord(
  credentials: SolaxCredentials('synthetic-client', 'synthetic-secret'),
  token: SolaxToken(
    'synthetic-token',
    expiry ?? solaxNow.add(const Duration(days: 20)),
  ),
  plant: solaxPlant,
  device: solaxDevice,
  reading: solaxReading(),
  fetchedAt: solaxNow,
  nextAttempt: next,
  reconnectRequired: revoked,
);

class MemorySolaxStore implements SolaxStore {
  SolaxRecord record = const SolaxRecord();
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  int? failAtWrite;
  @override
  Future<SolaxRecord> read() async {
    if (failRead) throw StateError('private storage details');
    return record;
  }

  @override
  Future<void> write(SolaxRecord value) async {
    writes++;
    if (failWrite || writes == failAtWrite) {
      throw StateError('private storage details');
    }
    record = value;
  }
}

class FakeSolaxSource implements SolaxSource {
  int authCalls = 0, plantCalls = 0, deviceCalls = 0, readingCalls = 0;
  SolaxFailure? failure;
  SolaxFailure? authFailure;
  Completer<void>? pending;
  List<SolaxPlant> inventory = [solaxPlant];
  List<SolaxDevice> inverterInventory = [solaxDevice];
  SolaxReading result = solaxReading();
  final tokens = <String>[];
  @override
  Future<SolaxToken> authenticate(SolaxCredentials credentials) async {
    authCalls++;
    if (pending != null) await pending!.future;
    if (authFailure != null) throw authFailure!;
    return SolaxToken(
      'synthetic-new-token-$authCalls',
      solaxNow.add(const Duration(days: 30)),
    );
  }

  @override
  Future<List<SolaxPlant>> plants(SolaxToken token) async {
    plantCalls++;
    tokens.add(token.value);
    if (failure != null) throw failure!;
    return inventory;
  }

  @override
  Future<List<SolaxDevice>> devices(SolaxToken token, SolaxPlant plant) async {
    deviceCalls++;
    tokens.add(token.value);
    if (failure != null) throw failure!;
    return inverterInventory;
  }

  @override
  Future<SolaxReading> reading(
    SolaxToken token,
    SolaxPlant plant,
    SolaxDevice device,
  ) async {
    readingCalls++;
    tokens.add(token.value);
    if (failure != null) throw failure!;
    return result;
  }
}
