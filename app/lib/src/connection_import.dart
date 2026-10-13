import 'dart:convert';

import 'battery.dart';
import 'battery_controller.dart';
import 'connection_controller.dart';
import 'p1.dart';
import 'p1_controller.dart';
import 'solaredge.dart';
import 'solax.dart';
import 'solax_controller.dart';

class ConnectionImportFailure implements Exception {
  const ConnectionImportFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ConnectionImport {
  const ConnectionImport._({this.solarEdge, this.solax, this.p1, this.battery});
  static const maxBytes = 32 * 1024;
  static const template = '''{
  "version": 1,
  "solarEdge": {
    "siteId": "YOUR_SITE_ID",
    "apiKey": "YOUR_API_KEY"
  },
  "solax": {
    "clientId": "YOUR_CLIENT_ID",
    "clientSecret": "YOUR_CLIENT_SECRET",
    "plantId": "YOUR_PLANT_ID",
    "serialNumber": "YOUR_INVERTER_SERIAL",
    "model": 28,
    "timeZone": "Europe/Amsterdam"
  },
  "p1": {"address": "YOUR_P1_IP"},
  "battery": {"address": "YOUR_BATTERY_IP"}
}''';
  final SolarEdgeCredentials? solarEdge;
  final ({SolaxCredentials credentials, SolaxPlant plant, SolaxDevice device})?
  solax;
  final P1Address? p1;
  final BatteryAddress? battery;

  factory ConnectionImport.parse(String input) {
    if (input.length > maxBytes || utf8.encode(input).length > maxBytes) {
      throw const ConnectionImportFailure(
        'Choose a JSON file smaller than 32 KB.',
      );
    }
    Map<String, dynamic> object(Object? value, Set<String> keys, String label) {
      if (value is! Map<String, dynamic> ||
          value.keys.any((key) => !keys.contains(key))) {
        throw ConnectionImportFailure(
          'Check the fields in $label against the JSON template.',
        );
      }
      return value;
    }

    String field(Map<String, dynamic> data, String key, String label) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty || value.length > 512) {
        throw ConnectionImportFailure('Enter $label.$key as non-empty text.');
      }
      return value.trim();
    }

    try {
      final data = object(jsonDecode(input), {
        'version',
        'solarEdge',
        'solax',
        'p1',
        'battery',
      }, 'the setup');
      if (data['version'] != 1) {
        throw const ConnectionImportFailure('Use JSON setup version 1.');
      }
      SolarEdgeCredentials? edge;
      ({SolaxCredentials credentials, SolaxPlant plant, SolaxDevice device})?
      solax;
      P1Address? p1;
      BatteryAddress? battery;
      if (data.containsKey('solarEdge')) {
        final source = object(data['solarEdge'], {
          'siteId',
          'apiKey',
        }, 'solarEdge');
        edge = SolarEdgeCredentials(
          field(source, 'siteId', 'solarEdge'),
          field(source, 'apiKey', 'solarEdge'),
        );
      }
      if (data.containsKey('solax')) {
        final source = object(data['solax'], {
          'clientId',
          'clientSecret',
          'plantId',
          'serialNumber',
          'model',
          'timeZone',
        }, 'solax');
        final plantId = field(source, 'plantId', 'solax');
        final zone = solaxTimeZone(field(source, 'timeZone', 'solax'));
        if (zone == null || source['model'] != 28) {
          throw const ConnectionImportFailure(
            'SolaX needs a valid timezone and supported inverter model 28.',
          );
        }
        solax = (
          credentials: SolaxCredentials(
            field(source, 'clientId', 'solax'),
            field(source, 'clientSecret', 'solax'),
          ),
          plant: SolaxPlant(plantId, zone),
          device: SolaxDevice(
            field(source, 'serialNumber', 'solax'),
            plantId,
            28,
          ),
        );
      }
      if (data.containsKey('p1')) {
        final source = object(data['p1'], {'address'}, 'p1');
        p1 = P1Address(field(source, 'address', 'p1'));
      }
      if (data.containsKey('battery')) {
        final source = object(data['battery'], {'address'}, 'battery');
        battery = BatteryAddress(field(source, 'address', 'battery'));
      }
      if (edge == null && solax == null && p1 == null && battery == null) {
        throw const ConnectionImportFailure('Include at least one connection.');
      }
      return ConnectionImport._(
        solarEdge: edge,
        solax: solax,
        p1: p1,
        battery: battery,
      );
    } on ConnectionImportFailure {
      rethrow;
    } on SolarEdgeFailure catch (failure) {
      throw ConnectionImportFailure(failure.message);
    } on SolaxFailure catch (failure) {
      throw ConnectionImportFailure(failure.message);
    } on P1Failure catch (failure) {
      throw ConnectionImportFailure(failure.message);
    } on BatteryFailure catch (failure) {
      throw ConnectionImportFailure(failure.message);
    } catch (_) {
      throw const ConnectionImportFailure(
        'Could not read the JSON. Check its format against the template.',
      );
    }
  }

  List<String> get sources => [
    if (solarEdge != null) 'SolarEdge',
    if (solax != null) 'SolaX',
    if (p1 != null) 'P1 meter',
    if (battery != null) 'Battery',
  ];

  Future<Map<String, bool>> save({
    required ConnectionController controller,
    SolaxController? solaxController,
    P1Controller? p1Controller,
    BatteryController? batteryController,
  }) async {
    if (controller.connected ||
        (solaxController?.connected ?? false) ||
        (p1Controller?.connected ?? false) ||
        (batteryController?.connected ?? false)) {
      throw const ConnectionImportFailure(
        'Connections already exist. Manage them in Settings.',
      );
    }
    final results = <String, bool>{};
    if (solarEdge != null) {
      results['SolarEdge'] = await controller.importConnection(solarEdge!);
    }
    if (solax case final source?) {
      results['SolaX'] =
          await solaxController?.importConnection(
            source.credentials,
            source.plant,
            source.device,
          ) ??
          false;
    }
    if (p1 != null) {
      results['P1 meter'] = await p1Controller?.importConnection(p1!) ?? false;
    }
    if (battery != null) {
      results['Battery'] =
          await batteryController?.importConnection(battery!) ?? false;
    }
    return results;
  }

  @override
  String toString() => 'ConnectionImport(redacted)';
}
