import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:timezone/timezone.dart' as tz;

import 'site_time.dart';

enum PriceResolution {
  quarterHourly('QUARTER_HOURLY', 15, '15 minutes'),
  hourly('HOURLY', 60, 'Hourly');

  const PriceResolution(this.apiValue, this.minutes, this.label);
  final String apiValue;
  final int minutes;
  final String label;
}

class TibberFailure implements Exception {
  const TibberFailure(
    this.message, {
    this.authentication = false,
    this.retryAfter,
  });
  final String message;
  final bool authentication;
  final Duration? retryAfter;
  @override
  String toString() => 'TibberFailure(redacted)';
}

class PriceInterval {
  const PriceInterval({
    required this.start,
    required this.end,
    required this.currency,
    this.total,
    this.energy,
    this.tax,
  });
  final DateTime start;
  final DateTime end;
  final String currency;
  final double? total;
  final double? energy;
  final double? tax;
  bool contains(DateTime time) => !time.isBefore(start) && time.isBefore(end);
  Map<String, dynamic> toJson() => {
    'startsAt': start.toUtc().toIso8601String(),
    'currency': currency,
    'total': total,
    'energy': energy,
    'tax': tax,
  };
  factory PriceInterval.fromJson(
    Map<String, dynamic> json,
    PriceResolution resolution,
  ) {
    final stamp = json['startsAt'];
    if (stamp is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.0{1,6})?(Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(stamp)) {
      throw const FormatException();
    }
    final wall = DateTime.parse('${stamp.substring(0, 19)}Z');
    if (wall.toIso8601String().substring(0, 19) != stamp.substring(0, 19)) {
      throw const FormatException();
    }
    final start = DateTime.parse(stamp).toUtc();
    if (start.second != 0 ||
        start.millisecond != 0 ||
        start.microsecond != 0 ||
        start.minute % resolution.minutes != 0) {
      throw const FormatException();
    }
    final currency = json['currency'];
    if (currency is! String || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw const FormatException();
    }
    double? number(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite) throw const FormatException();
      return value.toDouble();
    }

    return PriceInterval(
      start: start,
      end: start.add(Duration(minutes: resolution.minutes)),
      currency: currency,
      total: number('total'),
      energy: number('energy'),
      tax: number('tax'),
    );
  }
}

class TibberHome {
  TibberHome({
    required this.id,
    required this.name,
    required this.timeZone,
    required this.subscriptionStatus,
    required this.resolution,
    required List<PriceInterval> prices,
  }) : prices = List.unmodifiable(prices);
  final String id;
  final String name;
  final String timeZone;
  final String? subscriptionStatus;
  final PriceResolution resolution;
  final List<PriceInterval> prices;
  bool get activeSubscription => subscriptionStatus == 'running';
  tz.TZDateTime local(DateTime instant) =>
      tz.TZDateTime.from(instant, siteLocation(timeZone)!);
  tz.TZDateTime day(DateTime now, [int offset = 0]) {
    final date = local(now);
    return tz.TZDateTime(
      siteLocation(timeZone)!,
      date.year,
      date.month,
      date.day + offset,
    );
  }

  PriceInterval? current(DateTime now) {
    if (!activeSubscription) return null;
    for (final price in prices) {
      if (price.contains(now)) return price;
    }
    return null;
  }

  List<PriceInterval> forDay(DateTime now, [int offset = 0]) {
    final start = day(now, offset);
    final end = day(now, offset + 1);
    return prices
        .where((p) => !p.start.isBefore(start) && p.start.isBefore(end))
        .toList();
  }

  int expectedIntervals(DateTime now, [int offset = 0]) =>
      day(now, offset + 1).difference(day(now, offset)).inMinutes ~/
      resolution.minutes;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'timeZone': timeZone,
    'subscriptionStatus': subscriptionStatus,
    'resolution': resolution.name,
    'prices': prices.map((p) => p.toJson()).toList(),
  };
  factory TibberHome.fromJson(Map<String, dynamic> json) {
    final resolution = PriceResolution.values.byName(
      json['resolution'] as String,
    );
    return _parse(
      json['id'],
      json['name'],
      json['timeZone'],
      json['subscriptionStatus'],
      resolution,
      json['prices'],
    );
  }
  static TibberHome _parse(
    Object? id,
    Object? name,
    Object? zone,
    Object? status,
    PriceResolution resolution,
    Object? rows,
  ) {
    if (id is! String ||
        id.isEmpty ||
        id.length > 256 ||
        name is! String ||
        name.length > 256 ||
        zone is! String ||
        siteLocation(zone) == null ||
        (status != null && status is! String) ||
        rows is! List ||
        rows.length > 208) {
      throw const FormatException();
    }
    final prices =
        rows
            .map(
              (row) => PriceInterval.fromJson(
                row as Map<String, dynamic>,
                resolution,
              ),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < prices.length; i++) {
      if (prices[i].start.isBefore(prices[i - 1].end) ||
          prices[i].currency != prices.first.currency) {
        throw const FormatException();
      }
    }
    return TibberHome(
      id: id,
      name: name,
      timeZone: zone,
      subscriptionStatus: status as String?,
      resolution: resolution,
      prices: prices,
    );
  }

  @override
  String toString() => 'TibberHome(redacted)';
}

abstract interface class TibberSource {
  Future<List<TibberHome>> read(
    String token,
    PriceResolution resolution, {
    String? homeId,
  });
}

class TibberApi implements TibberSource {
  TibberApi(
    this.client, {
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 20),
  }) : _now = now ?? DateTime.now;
  final http.Client client;
  final DateTime Function() _now;
  final Duration timeout;
  Duration _retryDelay(String? header) {
    var delay = const Duration(hours: 1);
    if (header == null) return delay;
    try {
      final seconds = int.tryParse(header);
      final requested = seconds == null
          ? parseHttpDate(header).difference(_now().toUtc())
          : Duration(seconds: seconds);
      if (requested > delay) delay = requested;
    } on FormatException {
      return delay;
    }
    return delay;
  }

  static final endpoint = Uri.https('api.tibber.com', '/v1-beta/gql');
  static const _fields = '''
    id appNickname timeZone
    currentSubscription {
      status
      priceInfo(resolution: \$resolution) {
        today { startsAt total energy tax currency }
        tomorrow { startsAt total energy tax currency }
      }
    }
  ''';
  @override
  Future<List<TibberHome>> read(
    String token,
    PriceResolution resolution, {
    String? homeId,
  }) async {
    try {
      final query = homeId == null
          ? 'query Prices(\$resolution: PriceInfoResolution!) { viewer { homes { $_fields } } }'
          : 'query Prices(\$resolution: PriceInfoResolution!, \$homeId: ID!) { viewer { home(id: \$homeId) { $_fields } } }';
      final request = http.Request('POST', endpoint)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          'query': query,
          'variables': {'resolution': resolution.apiValue, 'homeId': ?homeId},
        });
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const TibberFailure(
          'Tibber authorization failed. Replace your token in Settings.',
          authentication: true,
        );
      }
      if (response.statusCode == 429) {
        throw TibberFailure(
          'Tibber asked us to wait. Saved prices remain available.',
          retryAfter: _retryDelay(response.headers['retry-after']),
        );
      }

      if (response.statusCode != 200) {
        throw const TibberFailure(
          'Tibber is unavailable. Check your connection and retry later.',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final errors = json['errors'];
      if (errors != null && (errors is! List || errors.isNotEmpty)) {
        final auth =
            errors is List &&
            errors.any(
              (e) =>
                  e is Map &&
                  e['extensions'] is Map &&
                  [
                    'UNAUTHENTICATED',
                    'FORBIDDEN',
                    'UNAUTHORIZED',
                  ].contains(e['extensions']['code']),
            );
        throw TibberFailure(
          auth
              ? 'Tibber authorization failed. Replace your token in Settings.'
              : 'Tibber could not return complete prices. Saved prices remain available.',
          authentication: auth,
        );
      }
      final viewer =
          (json['data'] as Map<String, dynamic>)['viewer']
              as Map<String, dynamic>;
      final homes = homeId == null ? viewer['homes'] as List : [viewer['home']];
      if (homes.isEmpty) {
        throw const TibberFailure(
          'No homes were found for this Tibber account.',
        );
      }
      final ids = <String>{};
      return homes.asMap().entries.map((entry) {
        final home = entry.value as Map<String, dynamic>;
        if (!home.containsKey('currentSubscription')) {
          throw const FormatException();
        }
        final subscription =
            home['currentSubscription'] as Map<String, dynamic>?;
        if (subscription != null &&
            (!subscription.containsKey('priceInfo') ||
                !subscription.containsKey('status'))) {
          throw const FormatException();
        }
        final info = subscription?['priceInfo'] as Map<String, dynamic>?;
        final parsed = TibberHome._parse(
          home['id'],
          home['appNickname'] ?? 'Home ${entry.key + 1}',
          home['timeZone'],
          subscription?['status'],
          resolution,
          info == null
              ? []
              : [...info['today'] as List, ...info['tomorrow'] as List],
        );
        if (!ids.add(parsed.id) || (homeId != null && parsed.id != homeId)) {
          throw const FormatException();
        }
        return parsed;
      }).toList();
    } on TibberFailure {
      rethrow;
    } on FormatException {
      throw const TibberFailure(
        'Tibber returned invalid price data. Saved prices remain available.',
      );
    } on TypeError {
      throw const TibberFailure(
        'Tibber returned incomplete price data. Saved prices remain available.',
      );
    } catch (_) {
      throw const TibberFailure(
        'Could not reach Tibber. Check your connection and retry later.',
      );
    }
  }
}
