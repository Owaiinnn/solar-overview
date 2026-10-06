import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'site_time.dart';

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

  @override
  String toString() => 'SolarEdgeCredentials(redacted)';
}

class SolarEdgeFailure implements Exception {
  const SolarEdgeFailure(this.message, {this.rateLimited = false});
  final String message;
  final bool rateLimited;

  @override
  String toString() => message;
}

enum ReadingFreshness { recent, stale, unknown }

class SolarOverview {
  const SolarOverview({
    this.powerWatts,
    this.energyWh,
    this.reportedAt,
    this.timeZone,
  });

  final double? powerWatts;
  final double? energyWh;
  final String? reportedAt;
  final String? timeZone;
  String get source => 'SolarEdge';
  DateTime? get reportedAtUtc => siteTimestampUtc(reportedAt, timeZone);

  ReadingFreshness freshness(DateTime now) {
    final stamp = reportedAtUtc;
    if (stamp == null || stamp.isAfter(now.toUtc())) {
      return ReadingFreshness.unknown;
    }
    return now.toUtc().difference(stamp) >= const Duration(minutes: 30)
        ? ReadingFreshness.stale
        : ReadingFreshness.recent;
  }

  double? todayEnergyWh(DateTime now) {
    final stamp = reportedAtUtc;
    return stamp != null &&
            !stamp.isAfter(now.toUtc()) &&
            isSiteToday(stamp, now, timeZone)
        ? energyWh
        : null;
  }

  factory SolarOverview.fromJson(
    Map<String, dynamic> json, {
    String? timeZone,
  }) {
    double? reading(String group, String field) {
      final object = json[group];
      final value = object is Map ? object[field] : null;
      return value is num && value.isFinite && value >= 0
          ? value.toDouble()
          : null;
    }

    return SolarOverview(
      powerWatts: reading('currentPower', 'power'),
      energyWh: reading('lastDayData', 'energy'),
      reportedAt: validSiteTimestamp(json['lastUpdateTime']),
      timeZone: siteLocation(timeZone)?.name,
    );
  }

  Map<String, dynamic> toJson() => {
    'currentPower': {'power': powerWatts},
    'lastDayData': {'energy': energyWh},
    'lastUpdateTime': reportedAt,
  };
}

abstract interface class SolarEdgeSource {
  Future<SolarOverview> overview(SolarEdgeCredentials credentials);
}

class SolarEdgeApi implements SolarEdgeSource {
  SolarEdgeApi(this._client);
  final http.Client _client;

  @override
  Future<SolarOverview> overview(SolarEdgeCredentials credentials) async {
    final data = await _get(credentials, 'overview');
    final details = await _get(credentials, 'details');
    final location = details['location'];
    final zone = location is Map ? location['timeZone'] : null;
    return SolarOverview.fromJson(data, timeZone: zone is String ? zone : null);
  }

  Future<Map<String, dynamic>> _get(
    SolarEdgeCredentials credentials,
    String endpoint,
  ) async {
    try {
      final request =
          http.Request(
              'GET',
              Uri.https(
                'monitoringapi.solaredge.com',
                '/site/${credentials.siteId}/$endpoint',
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
            'SolarEdge’s request limit was reached. Requests are paused for 24 hours.',
            rateLimited: true,
          );
        default:
          throw const SolarEdgeFailure(
            'SolarEdge could not complete the request. Please try again later.',
          );
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data[endpoint] is! Map<String, dynamic>) {
        throw const SolarEdgeFailure(
          'SolarEdge returned an unexpected response. Your connection was not changed.',
        );
      }
      return data[endpoint] as Map<String, dynamic>;
    } on SolarEdgeFailure {
      rethrow;
    } on FormatException {
      throw const SolarEdgeFailure(
        'SolarEdge returned an unreadable response. Please try again later.',
      );
    } catch (_) {
      throw const SolarEdgeFailure(
        'Could not reach SolarEdge. Check your internet connection and try again.',
      );
    }
  }
}
