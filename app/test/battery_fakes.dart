import 'dart:async';

import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/battery_store.dart';

final batteryNow = DateTime.utc(2026, 10, 4, 12);
BatteryReading batteryReading({double power = -200, int state = 1001}) =>
    BatteryReading.fromJson({
      '9405': 60,
      '6000': power,
      '6001': state,
      '2275': 220,
      '2278': 300,
      '6004': 1.2,
      '6005': 0.4,
    });

class MemoryBatteryStore implements BatteryStore {
  BatteryRecord saved = const BatteryRecord();
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<BatteryRecord> read() async {
    if (failRead) throw StateError('private storage error');
    return saved;
  }

  @override
  Future<void> write(BatteryRecord value) async {
    if (failWrite) throw StateError('private storage error');
    saved = value;
  }
}

class FakeBatterySource implements BatterySource {
  int calls = 0;
  bool reject = false;
  Completer<BatteryReading>? pending;
  BatteryReading result = batteryReading();
  @override
  Future<BatteryReading> read(BatteryAddress address) async {
    calls++;
    if (reject) throw const BatteryFailure('Battery unreachable.');
    return pending == null ? result : pending!.future;
  }
}
