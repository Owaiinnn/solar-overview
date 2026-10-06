import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'site_time.dart';
import 'solar_freshness.dart';

String? solaxTimeZone(String? value) {
  if (value?.replaceAll(' ', '') ==
      '(UTC+01:00)Amsterdam,Berlin,Bern,Rome,Stockholm,Vienna') {
    return 'Europe/Amsterdam';
  }
  return siteLocation(value)?.name;
}

class SolaxCredentials {
  SolaxCredentials(String clientId, String clientSecret)
    : clientId = clientId.trim(),
      clientSecret = clientSecret.trim() {
    if (this.clientId.isEmpty ||
        this.clientSecret.isEmpty ||
        this.clientId.length > 512 ||
        this.clientSecret.length > 512) {
      throw const SolaxFailure('Enter your SolaX client ID and client secret.');
    }
  }
  final String clientId;
  final String clientSecret;
  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'clientSecret': clientSecret,
    'region': 'eu',
  };
  factory SolaxCredentials.fromJson(Map<String, dynamic> json) {
    if (json['region'] != 'eu') throw const FormatException();
    return SolaxCredentials(
      json['clientId'] as String,
      json['clientSecret'] as String,
    );
  }
  bool sameAccount(SolaxCredentials other) =>
      clientId == other.clientId && clientSecret == other.clientSecret;
  @override
  String toString() => 'SolaxCredentials(redacted)';
}

enum SolaxFailureKind {
  request,
  authentication,
  revoked,
  denied,
  rateLimit,
  storage,
}

class SolaxFailure implements Exception {
  const SolaxFailure(this.message, {this.kind = SolaxFailureKind.request});
  final String message;
  final SolaxFailureKind kind;
  @override
  String toString() => message;
}

class SolaxToken {
  const SolaxToken(this.value, this.expiresAt);
  final String value;
  final DateTime expiresAt;
  bool usable(DateTime now) =>
      expiresAt.isAfter(now.toUtc().add(const Duration(minutes: 5)));
  Map<String, dynamic> toJson() => {
    'value': value,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
  factory SolaxToken.fromJson(Map<String, dynamic> json) {
    final value = json['value'] as String;
    final date = DateTime.parse(json['expiresAt'] as String);
    if (value.isEmpty || !date.isUtc) throw const FormatException();
    return SolaxToken(value, date);
  }
  @override
  String toString() => 'SolaxToken(redacted)';
}

class SolaxPlant {
  const SolaxPlant(this.id, this.timeZone);
  final String id;
  final String? timeZone;
  Map<String, dynamic> toJson() => {'id': id, 'timeZone': timeZone};
  factory SolaxPlant.fromJson(Map<String, dynamic> json) =>
      SolaxPlant(_id(json['id']), solaxTimeZone(json['timeZone'] as String?));
  @override
  String toString() => 'SolaxPlant(redacted)';
}

class SolaxDevice {
  const SolaxDevice(this.sn, this.plantId, this.model);
  final String sn;
  final String plantId;
  final int? model;
  bool get supported => model == 28;
  Map<String, dynamic> toJson() => {
    'sn': sn,
    'plantId': plantId,
    'model': model,
  };
  factory SolaxDevice.fromJson(Map<String, dynamic> json) =>
      SolaxDevice(_id(json['sn']), _id(json['plantId']), json['model'] as int?);
  @override
  String toString() => 'SolaxDevice(redacted)';
}

String _id(Object? value) {
  if (value is! String || value.isEmpty || value.length > 512) {
    throw const FormatException();
  }
  return value;
}

class SolaxReading {
  SolaxReading({
    required Map<String, double?> fields,
    this.reportedAt,
    this.timeZone,
    this.statusCode,
    this.sourceUtc,
  }) : fields = Map.unmodifiable(fields);
  static const deviceFields = [
    'acPower1',
    'acPower2',
    'acPower3',
    'dailyACOutput',
    'totalACOutput',
    'dailyYield',
    'totalYield',
    'acVoltage1',
    'acVoltage2',
    'acVoltage3',
    'acCurrent1',
    'acCurrent2',
    'acCurrent3',
    'acFrequency1',
    'acFrequency2',
    'acFrequency3',
    'inverterTemperature',
  ];
  static const mpptFields = [
    'MPPT1Power',
    'MPPT1Voltage',
    'MPPT1Current',
    'MPPT2Power',
    'MPPT2Voltage',
    'MPPT2Current',
  ];
  final Map<String, double?> fields;
  final String? reportedAt;
  final String? timeZone;
  final int? statusCode;
  String get provenance => '/openapi/v2/device/realtime_data';
  final DateTime? sourceUtc;
  DateTime? get reportedAtUtc =>
      sourceUtc ?? siteTimestampUtc(reportedAt, timeZone);
  double? get powerWatts => _nonnegative(fields['acPower1']);
  double? get dailyEnergyWh => _kwh(fields['dailyACOutput']);
  double? get lifetimeEnergyWh => _kwh(fields['totalACOutput']);
  double? mpptPowerWatts(int channel) =>
      _nonnegative(fields['mpptMap.MPPT${channel}Power']);
  double? get temperatureCelsius => fields['inverterTemperature'];
  double? acVoltageVolts(int phase) => _nonnegative(fields['acVoltage$phase']);
  double? acCurrentAmps(int phase) => _nonnegative(fields['acCurrent$phase']);
  double? acFrequencyHz(int phase) => _nonnegative(fields['acFrequency$phase']);
  double? mpptVoltageVolts(int channel) =>
      _nonnegative(fields['mpptMap.MPPT${channel}Voltage']);
  double? mpptCurrentAmps(int channel) =>
      _nonnegative(fields['mpptMap.MPPT${channel}Current']);
  static double? _nonnegative(double? value) =>
      value != null && value >= 0 ? value : null;
  static double? _kwh(double? value) {
    final converted = _nonnegative(value);
    return converted != null && (converted * 1000).isFinite
        ? converted * 1000
        : null;
  }

  double? todayEnergyWh(DateTime now) {
    final stamp = reportedAtUtc;
    return stamp != null &&
            !stamp.isAfter(now.toUtc()) &&
            isSiteToday(stamp, now, timeZone)
        ? dailyEnergyWh
        : null;
  }

  String get status => switch (statusCode) {
    100 => 'Waiting',
    101 => 'Self-check',
    102 => 'Normal',
    103 => 'Fault',
    104 => 'Permanent fault',
    105 => 'Updating',
    106 => 'EPS check',
    107 => 'EPS mode',
    108 => 'Self-test',
    109 => 'Idle',
    110 => 'Standby',
    _ => 'Unknown',
  };
  static DateTime? _utc(Object? value) {
    if (value is! String) return null;
    final plain = validSiteTimestamp(value);
    if (plain != null) {
      return DateTime.parse('${plain.replaceFirst(' ', 'T')}Z');
    }
    if (!RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|\+00:00)$',
    ).hasMatch(value)) {
      return null;
    }
    if (validSiteTimestamp(value.substring(0, 19).replaceFirst('T', ' ')) ==
        null) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  ReadingFreshness freshness(DateTime now) =>
      solarFreshness(reportedAtUtc, now);

  factory SolaxReading.fromResponse(Map<String, dynamic> json, String? zone) {
    double? number(Object? value) =>
        value is num && value.isFinite ? value.toDouble() : null;
    final mppt = json['mpptMap'];
    return SolaxReading(
      fields: {
        for (final key in deviceFields) key: number(json[key]),
        for (final key in mpptFields)
          'mpptMap.$key': number(
            mppt is Map
                ? (mppt.containsKey(key)
                      ? mppt[key]
                      : mppt[key.replaceFirst('MPPT', 'mppt')])
                : null,
          ),
      },
      reportedAt: validSiteTimestamp(json['plantLocalTime']),
      timeZone: solaxTimeZone(zone),
      sourceUtc: _utc(json['dataTime']),
      statusCode: json['deviceStatus'] is int
          ? json['deviceStatus'] as int
          : null,
    );
  }
  Map<String, dynamic> toJson() => {
    'fields': fields,
    'reportedAt': reportedAt,
    'timeZone': timeZone,
    'statusCode': statusCode,
    'sourceUtc': sourceUtc?.toUtc().toIso8601String(),
  };
  factory SolaxReading.fromJson(Map<String, dynamic> json) {
    final values = json['fields'] as Map<String, dynamic>;
    return SolaxReading.fromResponse({
      for (final key in deviceFields) key: values[key],
      'mpptMap': {for (final key in mpptFields) key: values['mpptMap.$key']},
      'plantLocalTime': json['reportedAt'],
      'deviceStatus': json['statusCode'],
      'dataTime': json['sourceUtc'],
    }, json['timeZone'] as String?);
  }
  @override
  String toString() => 'SolaxReading(redacted)';
}

abstract interface class SolaxSource {
  Future<SolaxToken> authenticate(SolaxCredentials credentials);
  Future<List<SolaxPlant>> plants(SolaxToken token);
  Future<List<SolaxDevice>> devices(SolaxToken token, SolaxPlant plant);
  Future<SolaxReading> reading(
    SolaxToken token,
    SolaxPlant plant,
    SolaxDevice device,
  );
}

class SolaxApi implements SolaxSource {
  SolaxApi(
    this._client, {
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 20),
  }) : _now = now ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _now;
  final Duration timeout;
  static const host = 'openapi-eu.solaxcloud.com';
  static const maxPages = 10;

  @override
  Future<SolaxToken> authenticate(SolaxCredentials credentials) async {
    final started = _now().toUtc();
    final data = await _request(
      '/openapi/auth/oauth/token',
      form: {
        'client_id': credentials.clientId,
        'client_secret': credentials.clientSecret,
        'grant_type': 'client_credentials',
      },
    );
    if (data is! Map ||
        data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty ||
        data['expires_in'] is! num ||
        !(data['expires_in'] as num).isFinite ||
        (data['expires_in'] as num) <= 300 ||
        (data['expires_in'] as num) > 31536000) {
      throw const SolaxFailure('SolaX returned an invalid token response.');
    }
    return SolaxToken(
      data['access_token'] as String,
      started.add(Duration(seconds: (data['expires_in'] as num).toInt())),
    );
  }

  Future<List<Map<String, dynamic>>> _pages(
    String path,
    SolaxToken token,
    Map<String, String> parameters,
  ) async {
    final result = <Map<String, dynamic>>[];
    int? expectedTotal;
    for (var page = 1; page <= maxPages; page++) {
      final data = await _request(
        path,
        token: token,
        query: {'businessType': '1', ...parameters, 'pageNo': '$page'},
      );
      if (data is! Map ||
          data['records'] is! List ||
          data['total'] is! int ||
          data['pages'] is! int ||
          data['current'] != page ||
          (data['total'] as int) < 0 ||
          (data['pages'] as int) < 0) {
        throw const SolaxFailure(
          'SolaX returned incomplete inventory. Retry later.',
        );
      }
      final total = data['total'] as int;
      final pages = data['pages'] as int;
      if (pages > maxPages ||
          (expectedTotal != null && expectedTotal != total)) {
        throw const SolaxFailure(
          'SolaX inventory is too large or changed during discovery. No selection was saved.',
        );
      }
      expectedTotal = total;
      for (final record in data['records'] as List) {
        if (record is! Map<String, dynamic>) {
          throw const SolaxFailure('SolaX returned invalid inventory.');
        }
        result.add(record);
      }
      if (page >= pages) {
        if (result.length != total) {
          throw const SolaxFailure('SolaX returned incomplete inventory.');
        }
        return result;
      }
      if ((data['records'] as List).isEmpty) {
        throw const SolaxFailure('SolaX returned incomplete inventory.');
      }
    }
    throw const SolaxFailure('SolaX inventory exceeded the discovery limit.');
  }

  @override
  Future<List<SolaxPlant>> plants(SolaxToken token) async {
    final rows = await _pages('/openapi/v2/plant/page_plant_info', token, {});
    try {
      final plants = rows
          .map(
            (r) => SolaxPlant(
              _id(r['plantId']),
              solaxTimeZone(r['plantTimeZone'] as String?),
            ),
          )
          .toList();
      if (plants.map((p) => p.id).toSet().length != plants.length) {
        throw const FormatException();
      }
      if (plants.isEmpty) {
        throw const SolaxFailure(
          'No residential plants are available. Check monitoring access in SolaX.',
        );
      }
      return plants;
    } on SolaxFailure {
      rethrow;
    } catch (_) {
      throw const SolaxFailure('SolaX returned invalid plant details.');
    }
  }

  @override
  Future<List<SolaxDevice>> devices(SolaxToken token, SolaxPlant plant) async {
    final rows = await _pages('/openapi/v2/device/page_device_info', token, {
      'deviceType': '1',
      'plantId': plant.id,
    });
    try {
      final devices = rows
          .map(
            (r) => SolaxDevice(
              _id(r['deviceSn']),
              _id(r['plantId']),
              r['deviceModel'] as int?,
            ),
          )
          .toList();
      if (devices.any((d) => d.plantId != plant.id) ||
          devices.map((d) => d.sn).toSet().length != devices.length) {
        throw const FormatException();
      }
      if (devices.isEmpty) {
        throw const SolaxFailure(
          'No inverters are available for this plant. Check monitoring access in SolaX.',
        );
      }
      return devices;
    } on SolaxFailure {
      rethrow;
    } catch (_) {
      throw const SolaxFailure('SolaX returned invalid inverter details.');
    }
  }

  @override
  Future<SolaxReading> reading(
    SolaxToken token,
    SolaxPlant plant,
    SolaxDevice device,
  ) async {
    if (!device.supported || device.plantId != plant.id) {
      throw const SolaxFailure(
        'This inverter is not supported by this connection yet.',
      );
    }
    final data = await _request(
      '/openapi/v2/device/realtime_data',
      token: token,
      query: {'businessType': '1', 'deviceType': '1', 'snList': device.sn},
    );
    if (data is! List ||
        data.length != 1 ||
        data.single is! Map<String, dynamic>) {
      throw const SolaxFailure('SolaX returned no usable inverter reading.');
    }
    final row = data.single as Map<String, dynamic>;
    if (row['deviceSn'] != device.sn ||
        !SolaxReading.deviceFields.any(row.containsKey)) {
      throw const SolaxFailure(
        'SolaX returned an unexpected inverter reading.',
      );
    }
    return SolaxReading.fromResponse(row, plant.timeZone);
  }

  Future<Object?> _request(
    String path, {
    Map<String, String>? form,
    Map<String, String>? query,
    SolaxToken? token,
  }) async {
    final abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              form == null ? 'GET' : 'POST',
              Uri.https(host, path, query),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'bearer ${token.value}';
      }
      if (form != null) request.bodyFields = form;
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode == 429) {
        throw const SolaxFailure(
          'SolaX request limit reached. Requests are paused for 24 hours.',
          kind: SolaxFailureKind.rateLimit,
        );
      }
      if (response.statusCode == 401) {
        throw SolaxFailure(
          'SolaX access was rejected. Check your dedicated application connection.',
          kind: token == null
              ? SolaxFailureKind.authentication
              : SolaxFailureKind.revoked,
        );
      }
      if (response.statusCode == 403) {
        throw const SolaxFailure(
          'SolaX denied monitoring access. Check application permissions.',
          kind: SolaxFailureKind.denied,
        );
      }
      if (response.statusCode != 200) {
        throw const SolaxFailure(
          'SolaX could not complete the request. Try again later.',
        );
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) throw const FormatException();
      if ([10405, 10406].contains(json['code'])) {
        throw const SolaxFailure(
          'SolaX request limit reached. Requests are paused for 24 hours.',
          kind: SolaxFailureKind.rateLimit,
        );
      }
      if (json['code'] == 10402) {
        throw const SolaxFailure(
          'SolaX token was revoked or expired. Use a separate application for each phone, then reconnect.',
          kind: SolaxFailureKind.revoked,
        );
      }
      if ([10403, 10500, 10505, 10506].contains(json['code'])) {
        throw const SolaxFailure(
          'SolaX denied monitoring access to this plant or inverter.',
          kind: SolaxFailureKind.denied,
        );
      }
      if (json['code'] != (form == null ? 10000 : 0)) {
        if (form != null) {
          throw const SolaxFailure(
            'SolaX rejected authentication. Check the client ID, secret and monitoring access.',
            kind: SolaxFailureKind.authentication,
          );
        }
        throw const SolaxFailure(
          'SolaX rejected the data request. Check monitoring access or reconnect after the wait.',
        );
      }
      return json['result'];
    } on SolaxFailure {
      rethrow;
    } catch (_) {
      throw const SolaxFailure(
        'Could not read SolaX data. Check your connection and retry later.',
      );
    } finally {
      abort.complete();
    }
  }
}
