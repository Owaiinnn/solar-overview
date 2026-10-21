import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'site_time.dart';
import 'solar_freshness.dart';
import 'history.dart';

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

  ReadingFreshness freshness(DateTime now) =>
      solarFreshness(reportedAtUtc, now);

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

abstract interface class SolarEdgeHistorySource {
  Future<ProductionHistory> history(
    SolarEdgeCredentials credentials,
    HistoryDay day,
  );
}

class SolarEdgeApi implements SolarEdgeSource, SolarEdgeHistorySource {
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

  @override
  Future<ProductionHistory> history(
    SolarEdgeCredentials credentials,
    HistoryDay day,
  ) async {
    final date = historyDate(day.date);
    final power = await _get(credentials, 'power', {
      'startTime': '$date 00:00:00',
      'endTime': '$date 23:59:59',
    });
    final monthStart = DateTime.utc(day.date.year, day.date.month);
    final monthEnd = DateTime.utc(day.date.year, day.date.month + 1, 0);
    final energy = await _get(credentials, 'energy', {
      'timeUnit': 'DAY',
      'startDate': historyDate(monthStart),
      'endDate': historyDate(monthEnd),
    });
    if (power['unit'] != 'W' ||
        power['timeUnit'] != 'QUARTER_OF_AN_HOUR' ||
        power['values'] is! List ||
        energy['unit'] != 'Wh' ||
        energy['timeUnit'] != 'DAY' ||
        energy['values'] is! List) {
      throw const SolarEdgeFailure(
        'SolarEdge history has unsupported units or intervals.',
      );
    }
    final samples = <HistorySample>[];
    for (final row in power['values'] as List) {
      if (row is! Map) {
        throw const SolarEdgeFailure('SolarEdge returned invalid history.');
      }
      final stamp = siteTimestampUtc(
        validSiteTimestamp(row['date']),
        day.timeZone,
      );
      if (stamp != null && day.contains(stamp)) {
        samples.add(HistorySample(stamp, historyNumber(row['value'])));
      }
    }
    final daily = <String, double?>{};
    for (final row in energy['values'] as List) {
      if (row is! Map) {
        throw const SolarEdgeFailure(
          'SolarEdge returned invalid daily energy.',
        );
      }
      final stamp = validSiteTimestamp(row['date']);
      if (stamp == null || !stamp.endsWith('00:00:00')) continue;
      final date = stamp.substring(0, 10);
      if (!date.startsWith(historyMonth(day.date))) continue;
      if (daily.containsKey(date)) {
        throw const SolarEdgeFailure(
          'SolarEdge returned duplicate daily energy.',
        );
      }
      daily[date] = historyNumber(row['value']);
    }
    const interval = Duration(minutes: 15);
    return ProductionHistory(
      day: day,
      interval: interval,
      samples: historyBuckets(day, interval, samples),
      dailyWh: daily,
    );
  }

  Future<Map<String, dynamic>> _get(
    SolarEdgeCredentials credentials,
    String endpoint, [
    Map<String, String> parameters = const {},
  ]) async {
    final abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              'GET',
              Uri.https(
                'monitoringapi.solaredge.com',
                '/site/${credentials.siteId}/$endpoint',
                {...parameters, 'api_key': credentials.apiKey},
              ),
              abortTrigger: abort.future,
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
          final reading = switch (endpoint) {
            'power' => 'power history',
            'energy' => 'daily energy',
            _ => 'data',
          };
          throw SolarEdgeFailure(
            'SolarEdge could not load $reading (HTTP ${response.statusCode}). Please try again later.',
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
    } finally {
      abort.complete();
    }
  }
}
