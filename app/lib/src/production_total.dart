import 'connection_controller.dart';
import 'solaredge.dart';
import 'solax_controller.dart';

/// The owner confirmed separate solar-only AC outputs for this installation
/// (ticket #4). MPPT inputs, energy counters and battery flows never enter here.
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

  bool get timeMismatch =>
      _times.length == 2 &&
      _times.first.difference(_times.last).abs() > maximumSkew;
  double? get watts {
    if (sources.isEmpty || timeMismatch) return null;
    final result = sources.values.fold(0.0, (total, value) => total + value);
    return result.isFinite ? result : null;
  }
}
