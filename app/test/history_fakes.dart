import 'dart:async';

import 'package:solar_overview/src/history.dart';
import 'package:solar_overview/src/solaredge.dart';
import 'package:solar_overview/src/solax.dart';

import 'fakes.dart';
import 'solax_fakes.dart';

ProductionHistory syntheticHistory(
  HistoryDay day, {
  double watts = 500,
  double energy = 2000,
}) => ProductionHistory(
  day: day,
  interval: const Duration(minutes: 15),
  samples: historyBuckets(day, const Duration(minutes: 15), [
    for (var index = 32; index <= 68; index++)
      if (index != 49)
        HistorySample(
          day.start.add(Duration(minutes: index * 15)),
          index == 68 ? 0 : watts * (1 - (index - 50).abs() / 19),
          mppt1: index == 68 ? 0 : watts * 0.45,
          mppt2: index == 68 ? 0 : watts * 0.7,
        ),
  ]),
  dailyWh: {historyDate(day.date): energy},
);

class HistoryEdgeSource extends FakeSource implements SolarEdgeHistorySource {
  int historyCalls = 0;
  Completer<void>? pending;
  SolarEdgeFailure? historyFailure;
  @override
  Future<ProductionHistory> history(
    SolarEdgeCredentials credentials,
    HistoryDay day,
  ) async {
    historyCalls++;
    if (pending != null) await pending!.future;
    if (historyFailure != null) throw historyFailure!;
    return syntheticHistory(day);
  }
}

class HistorySolaxSource extends FakeSolaxSource implements SolaxHistorySource {
  int historyCalls = 0;
  SolaxFailure? historyFailure;
  @override
  Future<ProductionHistory> history(
    SolaxToken token,
    SolaxPlant plant,
    SolaxDevice device,
    HistoryDay day,
  ) async {
    historyCalls++;
    if (historyFailure != null) throw historyFailure!;
    return syntheticHistory(day, watts: 200, energy: 1000);
  }
}
