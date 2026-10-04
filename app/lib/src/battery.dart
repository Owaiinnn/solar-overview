import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class BatteryFailure implements Exception {
  const BatteryFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

// Literal private IPv4 only: no credentials, public hosts, DNS rebinding,
// arbitrary ports, paths or redirects. The device's HTTP API uses port 8080.
class BatteryAddress {
  BatteryAddress(String value) : host = value.trim() {
    final parts = host.split('.');
    final octets = parts.map(int.tryParse).toList();
    if (parts.length != 4 ||
        octets.any((n) => n == null || n < 0 || n > 255) ||
        List.generate(4, (i) => octets[i].toString()).join('.') != host ||
        !(octets[0] == 10 ||
            (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31) ||
            (octets[0] == 192 && octets[1] == 168))) {
      throw const BatteryFailure(
        'Enter the battery’s private IPv4 address, without a URL or port.',
      );
    }
  }
  final String host;
  Uri get readingUri => Uri(
    scheme: 'http',
    host: host,
    port: 8080,
    path: '/rpc/Indevolt.GetData',
    queryParameters: {
      'config': jsonEncode({
        't': BatteryReading.points.map(int.parse).toList(),
      }),
    },
  );
  @override
  String toString() => 'BatteryAddress(redacted)';
}

enum BatteryState { idle, charging, discharging, unknown }

class BatteryReading {
  BatteryReading._(this.fields);
  static const points = [
    '9405',
    '6001',
    '6000',
    '2275',
    '2278',
    '6004',
    '6005',
  ];
  final Map<String, double?> fields;
  factory BatteryReading.fromJson(Map<String, dynamic> json) {
    double? number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite) return null;
      final n = value.toDouble();
      if (key == '9405' && (n < 0 || n > 100)) return null;
      if ((key == '6004' || key == '6005') && n < 0) return null;
      if (key == '6001' && ![1000, 1001, 1002].contains(n)) return null;
      return n;
    }

    final fields = {for (final key in points) key: number(key)};
    if (!['9405', '6001', '6000'].any((key) => fields[key] != null)) {
      throw const BatteryFailure(
        'The battery returned no usable battery readings.',
      );
    }
    return BatteryReading._(Map.unmodifiable(fields));
  }
  double? get percent => fields['9405'];
  // DC battery-pack power: positive discharge, negative charge. Never AC solar.
  double? get packWatts => fields['6000'];
  double? get inverterAcWatts => fields['2275'];
  double? get totalAcWatts => fields['2278'];
  double? get dailyChargeKwh => fields['6004'];
  double? get dailyDischargeKwh => fields['6005'];
  BatteryState get state => switch (fields['6001']) {
    1000 => BatteryState.idle,
    1001 => BatteryState.charging,
    1002 => BatteryState.discharging,
    _ => BatteryState.unknown,
  };
  bool get statePowerConflict => switch (state) {
    BatteryState.charging => (packWatts ?? 0) > 0,
    BatteryState.discharging => (packWatts ?? 0) < 0,
    BatteryState.idle => packWatts != null && packWatts != 0,
    BatteryState.unknown => false,
  };
  String get provenance => 'INDEVOLT /rpc/Indevolt.GetData';
  // No measurement timestamp is supplied. Receipt age cannot prove live flows.
  DateTime? get measuredAt => null;
  bool get suitableForHouseholdBalance => false;
  Map<String, dynamic> toJson() => Map.of(fields);
  @override
  String toString() => 'BatteryReading(redacted)';
}

abstract interface class BatterySource {
  Future<BatteryReading> read(BatteryAddress address);
}

class BatteryApi implements BatterySource {
  BatteryApi(this.client, {this.timeout = const Duration(seconds: 8)});
  final http.Client client;
  final Duration timeout;
  @override
  Future<BatteryReading> read(BatteryAddress address) async {
    final abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              'POST',
              address.readingUri,
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers['Accept'] = 'application/json'
            ..headers['Content-Type'] = 'application/json';
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const BatteryFailure(
          'Battery access was denied. Check that local HTTP mode is enabled in INDEVOLT. Digest authentication is not supported here.',
        );
      }
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const BatteryFailure(
          'The battery redirected the request. Check its local address; redirects are not followed.',
        );
      }
      if (response.statusCode != 200) {
        throw const BatteryFailure(
          'The battery could not complete the request. Check its address and local HTTP setting.',
        );
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) throw const FormatException();
      return BatteryReading.fromJson(json);
    } on BatteryFailure {
      rethrow;
    } catch (_) {
      // Never expose errors containing the local address or response body.
      throw const BatteryFailure(
        'Could not read the battery. Join your home network and check its address and local HTTP setting.',
      );
    } finally {
      abort.complete();
    }
  }
}
