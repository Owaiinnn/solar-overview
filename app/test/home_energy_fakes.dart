import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/battery_controller.dart';
import 'package:solar_overview/src/battery_store.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/p1_controller.dart';
import 'package:solar_overview/src/p1_store.dart';

import 'battery_fakes.dart';
import 'p1_fakes.dart';
import 'solax_fakes.dart';

Future<BatteryController> homeBattery({
  BatteryState state = BatteryState.charging,
  double? percent = 60,
  double? power,
  bool connected = true,
  bool saved = false,
  FakeBatterySource? source,
  DateTime Function()? now,
}) async {
  final clock = now ?? () => solaxNow;
  final reading = BatteryReading.fromJson({
    '9405': percent,
    '6001': switch (state) {
      BatteryState.idle => 1000,
      BatteryState.charging => 1001,
      BatteryState.discharging => 1002,
      BatteryState.unknown => null,
    },
    '6000':
        power ??
        switch (state) {
          BatteryState.charging => -520,
          BatteryState.discharging => 520,
          _ => 0,
        },
  });
  final store = MemoryBatteryStore();
  if (connected) {
    store.saved = BatteryRecord(
      address: BatteryAddress('192.168.1.20'),
      reading: saved ? reading : null,
      receivedAt: saved ? clock() : null,
      nextAttempt: saved ? clock().add(const Duration(minutes: 5)) : null,
    );
  }
  final controller = BatteryController(
    store,
    source ?? (FakeBatterySource()..result = reading),
    now: clock,
  );
  await controller.initialize();
  return controller;
}

Future<P1Controller> homeGrid({
  GridDirection direction = GridDirection.importing,
  bool connected = true,
  bool saved = false,
  FakeP1Source? source,
  DateTime Function()? now,
}) async {
  final clock = now ?? () => solaxNow;
  var reading = p1Reading(
    at: clock(),
    importKw: direction == GridDirection.importing ? '01.200' : '00.000',
    exportKw: direction == GridDirection.exporting ? '00.520' : '00.000',
  );
  if (direction == GridDirection.unavailable) {
    final json = reading.toJson();
    json['fields'] = {...reading.fields, '1-0:1.7.0': null};
    reading = P1Reading.fromJson(json);
  }
  final store = MemoryP1Store();
  if (connected) {
    store.saved = P1Record(
      address: P1Address('192.168.1.21'),
      reading: saved ? reading : null,
      receivedAt: saved ? clock() : null,
      nextAttempt: saved ? clock().add(const Duration(minutes: 5)) : null,
    );
  }
  final controller = P1Controller(
    store,
    source ?? (FakeP1Source(now: clock)..value = reading),
    now: clock,
  );
  await controller.initialize();
  return controller;
}
