import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

import 'site_time.dart';

class P1Failure implements Exception {
  const P1Failure(this.message);
  final String message;
  @override
  String toString() => message;
}

class P1Address {
  P1Address(String value) : host = value.trim() {
    final parts = host.split('.');
    final octets = parts.map(int.tryParse).toList();
    if (parts.length != 4 ||
        octets.any((n) => n == null || n < 0 || n > 255) ||
        List.generate(4, (i) => octets[i].toString()).join('.') != host ||
        !(octets[0] == 10 ||
            (octets[0] == 172 && octets[1]! >= 16 && octets[1]! <= 31) ||
            (octets[0] == 192 && octets[1] == 168))) {
      throw const P1Failure(
        'Enter the P1 reader’s private IPv4 address, without a URL or port.',
      );
    }
  }
  final String host;
  Uri get readingUri =>
      Uri(scheme: 'http', host: host, port: 8080, path: '/rpc/P1.GetData');
  @override
  String toString() => 'P1Address(redacted)';
}

enum GridDirection { importing, exporting, balanced, unavailable }

DateTime p1TimestampUtc(String stamp) {
  if (!RegExp(r'^\d{12}[SW]$').hasMatch(stamp)) {
    throw const P1Failure('The meter timestamp is missing or invalid.');
  }
  int part(int i) => int.parse(stamp.substring(i, i + 2));
  final wall = DateTime.utc(
    2000 + part(0),
    part(2),
    part(4),
    part(6),
    part(8),
    part(10),
  );
  final expected =
      '${wall.year.toString().substring(2)}'
      '${wall.month.toString().padLeft(2, '0')}'
      '${wall.day.toString().padLeft(2, '0')}'
      '${wall.hour.toString().padLeft(2, '0')}'
      '${wall.minute.toString().padLeft(2, '0')}'
      '${wall.second.toString().padLeft(2, '0')}';
  final offset = Duration(hours: stamp.endsWith('S') ? 2 : 1);
  final utc = wall.subtract(offset);
  final local = tz.TZDateTime.from(utc, siteLocation('Europe/Amsterdam')!);
  if (expected != stamp.substring(0, 12) || local.timeZoneOffset != offset) {
    throw const P1Failure(
      'The meter timestamp or summer/winter suffix is invalid.',
    );
  }
  return utc;
}

class P1Reading {
  P1Reading._({
    required this.meterId,
    required this.timestamp,
    required this.fields,
  });
  static const powerKeys = ['1-0:1.7.0', '1-0:2.7.0'];
  static const counterKeys = [
    '1-0:1.8.1',
    '1-0:1.8.2',
    '1-0:2.8.1',
    '1-0:2.8.2',
  ];
  static final units = <String, String>{
    for (final key in powerKeys) key: 'kW',
    for (final key in counterKeys) key: 'kWh',
    for (final phase in [2, 4, 6]) ...{
      '1-0:${phase}1.7.0': 'kW',
      '1-0:${phase}2.7.0': 'kW',
      '1-0:${phase + 1}2.7.0': 'V',
      '1-0:${phase + 1}1.7.0': 'A',
    },
  };
  final String meterId;
  final String timestamp;
  final Map<String, num?> fields;
  late final DateTime measuredAt = p1TimestampUtc(timestamp);
  int? get importWatts => fields[powerKeys[0]] as int?;
  int? get exportWatts => fields[powerKeys[1]] as int?;
  int? get netWatts => importWatts == null || exportWatts == null
      ? null
      : importWatts! - exportWatts!;
  GridDirection get direction => switch (netWatts) {
    null => GridDirection.unavailable,
    > 0 => GridDirection.importing,
    < 0 => GridDirection.exporting,
    _ => GridDirection.balanced,
  };
  String get provenance => 'P1.GetData · DSMR electricity OBIS';
  bool get suitableForHouseholdBalance => false;

  factory P1Reading.parse(String response) {
    var text = response.trim();
    if (text.startsWith('{') && text.endsWith('}')) {
      text = text.substring(1, text.length - 1).trim();
    }
    final end = RegExp(r'!([0-9A-Fa-f]{4})?$').firstMatch(text);
    if (end == null || text.indexOf('!') != end.start) {
      throw const P1Failure(
        'The P1 reader returned an incomplete meter telegram.',
      );
    }
    if (text.startsWith('/')) {
      if (end.group(1) == null || text.indexOf('/', 1) != -1) {
        throw const P1Failure('The meter telegram framing is invalid.');
      }
      var crc = 0;
      for (final byte in ascii.encode(text.substring(0, end.start + 1))) {
        crc ^= byte;
        for (var bit = 0; bit < 8; bit++) {
          crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
        }
      }
      if (crc != int.parse(end.group(1)!, radix: 16)) {
        throw const P1Failure('The meter telegram checksum is invalid.');
      }
    }
    final values = <String, String>{};
    for (final line in text.substring(0, end.start).split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('/')) continue;
      final match = RegExp(r'^([0-9]+(?:-[0-9]+)?:[0-9]+\.[0-9]+\.[0-9]+)(.*)$')
          .firstMatch(trimmed);
      if (match == null) {
        throw const P1Failure('The meter telegram format is unsupported.');
      }
      final key = match.group(1)!;
      if (!units.containsKey(key) &&
          key != '0-0:1.0.0' &&
          key != '0-0:96.1.1') {
        continue;
      }
      if (values.containsKey(key)) {
        throw const P1Failure(
          'The meter telegram contains duplicate measurements.',
        );
      }
      values[key] = match.group(2)!;
    }
    String requiredValue(String key) {
      final match = RegExp(r'^\(([^()]+)\)$').firstMatch(values[key] ?? '');
      if (match == null) {
        throw const P1Failure('The meter timestamp or identity is missing.');
      }
      return match.group(1)!;
    }

    final stamp = requiredValue('0-0:1.0.0');
    p1TimestampUtc(stamp);
    final id = requiredValue('0-0:96.1.1');
    if (!RegExp(r'^(?:[0-9A-Fa-f]{2}){1,48}$').hasMatch(id)) {
      throw const P1Failure('The meter identity format is unsupported.');
    }
    num? number(String key, String unit) {
      final value = values[key];
      if (value == null) return null;
      final match = RegExp(r'^\((\d{1,12})(?:\.(\d{1,3}))?\*' + unit + r'\)$')
          .firstMatch(value);
      if (match == null) {
        throw const P1Failure('A meter reading has an invalid value or unit.');
      }
      final milli =
          int.parse(match.group(1)!) * 1000 +
          int.parse((match.group(2) ?? '').padRight(3, '0'));
      return unit == 'kW' || unit == 'kWh' ? milli : milli / 1000;
    }

    final fields = {
      for (final entry in units.entries)
        entry.key: number(entry.key, entry.value),
    };
    if (![...powerKeys, ...counterKeys].any((key) => fields[key] != null)) {
      throw const P1Failure(
        'The P1 reader returned no usable electricity readings.',
      );
    }
    return P1Reading._(
      meterId: id.toUpperCase(),
      timestamp: stamp,
      fields: Map.unmodifiable(fields),
    );
  }

  bool countersDecreasedFrom(P1Reading previous) => counterKeys.any(
    (key) =>
        fields[key] != null &&
        previous.fields[key] != null &&
        fields[key]! < previous.fields[key]!,
  );
  Map<String, dynamic> toJson() => {
    'meterId': meterId,
    'timestamp': timestamp,
    'fields': fields,
  };
  factory P1Reading.fromJson(Map<String, dynamic> json) {
    final stamp = json['timestamp'] as String;
    p1TimestampUtc(stamp);
    final id = json['meterId'] as String;
    if (!RegExp(r'^(?:[0-9A-F]{2}){1,48}$').hasMatch(id)) {
      throw const FormatException();
    }
    final raw = json['fields'] as Map<String, dynamic>;
    final fields = <String, num?>{};
    for (final entry in units.entries) {
      final value = raw[entry.key];
      if (value != null &&
          (value is! num ||
              !value.isFinite ||
              value < 0 ||
              value >= 1000000000000000 ||
              ((entry.value == 'kW' || entry.value == 'kWh') &&
                  value is! int))) {
        throw const FormatException();
      }
      fields[entry.key] = value as num?;
    }
    if (![...powerKeys, ...counterKeys].any((key) => fields[key] != null)) {
      throw const FormatException();
    }
    return P1Reading._(
      meterId: id,
      timestamp: stamp,
      fields: Map.unmodifiable(fields),
    );
  }
  @override
  String toString() => 'P1Reading(redacted)';
}

abstract interface class P1Source {
  Future<P1Reading> read(P1Address address);
}

class P1Api implements P1Source {
  P1Api(this.client, {this.timeout = const Duration(seconds: 8)});
  final http.Client client;
  final Duration timeout;
  @override
  Future<P1Reading> read(P1Address address) async {
    final abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              'GET',
              address.readingUri,
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers['Accept'] = 'text/plain';
      final response = await (() async {
        final stream = await client.send(request);
        if (stream.statusCode == 401 || stream.statusCode == 403) {
          throw const P1Failure(
            'P1 access was denied. Check local HTTP mode in the reader’s app. Digest authentication is not supported.',
          );
        }
        if (stream.statusCode >= 300 && stream.statusCode < 400) {
          throw const P1Failure(
            'The P1 reader redirected the request. Check its address; redirects are not followed.',
          );
        }
        if (stream.statusCode != 200) {
          throw const P1Failure(
            'The P1 reader could not complete the request. Check its address and local HTTP mode.',
          );
        }
        final bytes = <int>[];
        await for (final chunk in stream.stream) {
          if (bytes.length + chunk.length > 65536) {
            throw const P1Failure(
              'The P1 response exceeds the supported telegram size.',
            );
          }
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes);
      })().timeout(timeout);
      return P1Reading.parse(response);
    } on P1Failure {
      rethrow;
    } catch (_) {
      throw const P1Failure(
        'Could not read the P1 meter. Join your home network and check the reader address and local HTTP mode.',
      );
    } finally {
      abort.complete();
    }
  }
}
