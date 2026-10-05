import 'dart:async';

import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/p1_store.dart';
import 'package:solar_overview/src/site_time.dart';
import 'package:timezone/timezone.dart' as tz;

final p1Now = DateTime.utc(2026, 10, 5, 10);
String p1Stamp(DateTime at) {
  final local = tz.TZDateTime.from(at, siteLocation('Europe/Amsterdam')!);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.year % 100)}${two(local.month)}${two(local.day)}${two(local.hour)}${two(local.minute)}${two(local.second)}${local.timeZoneOffset.inHours == 2 ? 'S' : 'W'}';
}

String p1Telegram({
  DateTime? at,
  String? stamp,
  String id = '544553542D4D45544552',
  String importKw = '00.000',
  String exportKw = '00.520',
  String counter = '001234.567',
}) =>
    '''{
1-3:0.2.8(50)
0-0:1.0.0(${stamp ?? p1Stamp(at ?? p1Now)})
0-0:96.1.1($id)
1-0:1.8.1($counter*kWh)
1-0:1.8.2(002345.678*kWh)
1-0:2.8.1(000123.456*kWh)
1-0:2.8.2(000234.567*kWh)
1-0:1.7.0($importKw*kW)
1-0:2.7.0($exportKw*kW)
1-0:32.7.0(230.1*V)
1-0:31.7.0(002*A)
1-0:21.7.0(00.000*kW)
1-0:22.7.0(00.520*kW)
0-1:24.2.1(261005120000S)(00000.000*m3)
!
}''';
P1Reading p1Reading({
  DateTime? at,
  String importKw = '00.000',
  String exportKw = '00.520',
}) =>
    P1Reading.parse(p1Telegram(at: at, importKw: importKw, exportKw: exportKw));

class MemoryP1Store implements P1Store {
  P1Record saved = const P1Record();
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<P1Record> read() async {
    if (failRead) throw Exception('private storage error');
    return saved;
  }

  @override
  Future<void> write(P1Record record) async {
    if (failWrite) throw Exception('private storage error');
    saved = P1Record.fromJson(record.toJson());
  }
}

class FakeP1Source implements P1Source {
  FakeP1Source({DateTime Function()? now}) : now = now ?? (() => p1Now);
  final DateTime Function() now;
  int calls = 0;
  bool reject = false;
  P1Reading? value;
  Completer<P1Reading>? pending;
  @override
  Future<P1Reading> read(P1Address address) async {
    calls++;
    if (reject) throw const P1Failure('P1 unreachable.');
    return pending?.future ?? value ?? p1Reading(at: now());
  }
}
