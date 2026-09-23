import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SolarEdgeCredentials {
  SolarEdgeCredentials(String siteId, String apiKey)
    : siteId = siteId.trim(),
      apiKey = apiKey.trim() {
    if (!RegExp(r'^\d+$').hasMatch(this.siteId) ||
        !RegExp(r'^[a-zA-Z0-9]{32}$').hasMatch(this.apiKey)) {
      throw const SolarEdgeFailure(
        'Enter a numeric site ID and a 32-character API key.',
      );
    }
  }

  final String siteId;
  final String apiKey;

  // Never include credentials in diagnostics, including failed test output.
  @override
  String toString() => 'SolarEdgeCredentials(redacted)';
}

class SolarEdgeFailure implements Exception {
  const SolarEdgeFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class SolarOverview {
  const SolarOverview({this.powerWatts, this.energyWh, this.reportedAt});

  final double? powerWatts;
  final double? energyWh;
  // SolarEdge's overview timestamp has no timezone offset. Do not interpret it
  // in the phone's timezone or claim a precise age before site timezone support.
  final String? reportedAt;

  factory SolarOverview.fromJson(Map<String, dynamic> json) {
    double? reading(String group, String field) {
      final object = json[group];
      final value = object is Map ? object[field] : null;
      return value is num && value.isFinite && value >= 0
          ? value.toDouble()
          : null;
    }

    final stamp = json['lastUpdateTime'];
    final validStamp =
        stamp is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(stamp) &&
        DateTime.tryParse(stamp) != null;
    return SolarOverview(
      powerWatts: reading('currentPower', 'power'),
      energyWh: reading('lastDayData', 'energy'),
      reportedAt: validStamp ? stamp : null,
    );
  }
}

abstract interface class SolarEdgeSource {
  Future<SolarOverview> overview(SolarEdgeCredentials credentials);
}

class SolarEdgeApi implements SolarEdgeSource {
  SolarEdgeApi(this._client);
  final http.Client _client;

  @override
  Future<SolarOverview> overview(SolarEdgeCredentials credentials) async {
    try {
      final request =
          http.Request(
              'GET',
              Uri.https(
                'monitoringapi.solaredge.com',
                '/site/${credentials.siteId}/overview',
                {'api_key': credentials.apiKey},
              ),
            )
            ..followRedirects = false
            ..headers['Accept'] = 'application/json';
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 20));
      switch (response.statusCode) {
        case 200:
          break;
        case 401 || 403:
          throw const SolarEdgeFailure(
            'SolarEdge rejected this connection. Check the site ID and API key.',
          );
        case 429:
          throw const SolarEdgeFailure(
            'SolarEdge’s request limit was reached. Please try again later.',
          );
        default:
          throw const SolarEdgeFailure(
            'SolarEdge could not complete the request. Please try again later.',
          );
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['overview'] is! Map<String, dynamic>) {
        throw const SolarEdgeFailure(
          'SolarEdge returned an unexpected response. Your connection was not changed.',
        );
      }
      return SolarOverview.fromJson(data['overview'] as Map<String, dynamic>);
    } on SolarEdgeFailure {
      rethrow;
    } catch (_) {
      // HTTP exceptions can contain the request URL, which includes the key.
      // Never forward exception strings or raw provider responses to the UI/logs.
      throw const SolarEdgeFailure(
        'Could not reach SolarEdge. Check your internet connection and try again.',
      );
    }
  }
}
