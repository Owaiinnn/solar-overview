import 'connection_controller.dart';
import 'solar_freshness.dart';
import 'solax_controller.dart';

class ProductionTotal {
  ProductionTotal(ConnectionController solarEdge, SolaxController? solax) {
    final edge = solarEdge.overview;
    final x = solax?.reading;
    if (solarEdge.connected &&
        !solarEdge.storageUnavailable &&
        solarEdge.error == null &&
        solarEdge.freshness == ReadingFreshness.recent &&
        _valid(edge?.powerWatts)) {
      sources['SolarEdge'] = edge!.powerWatts!;
      _times.add(edge.reportedAtUtc!);
    }
    if (solax != null &&
        solax.connected &&
        !solax.storageUnavailable &&
        !solax.reconnectRequired &&
        solax.error == null &&
        solax.freshness == ReadingFreshness.recent &&
        _valid(x?.powerWatts)) {
      sources['SolaX'] = x!.powerWatts!;
      _times.add(x.reportedAtUtc!);
    }
  }

  static const maximumSkew = Duration(minutes: 5);
  final Map<String, double> sources = {};
  final List<DateTime> _times = [];
  static bool _valid(double? value) =>
      value != null && value.isFinite && value >= 0;

  bool get partial => sources.length == 1;
  String get title =>
      partial ? 'Partial solar production' : 'Combined solar production';
  String get coverage => partial
      ? '${sources.keys.single} only · 1 of 2 sources'
      : 'SolarEdge + SolaX · ${sources.length} of 2 sources';

  bool get timeMismatch =>
      _times.length == 2 &&
      _times.first.difference(_times.last).abs() > maximumSkew;
  double? get watts {
    if (sources.isEmpty || timeMismatch) return null;
    final result = sources.values.fold(0.0, (total, value) => total + value);
    return result.isFinite ? result : null;
  }
}
