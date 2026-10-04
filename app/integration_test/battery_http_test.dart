import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/battery.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native private HTTP reads telemetry and rejects redirects and auth',
    (tester) async {
      // Synthetic server on the test device, never the real battery. Exercises
      // the release manifest's cleartext opt-in and the real native HTTP client.
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final host = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .firstWhere((host) {
            try {
              BatteryAddress(host);
              return true;
            } catch (_) {
              return false;
            }
          });
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      final client = http.Client();
      var status = 200;
      var calls = 0;
      final subscription = server.listen((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.uri.path, '/rpc/Indevolt.GetData');
        expect(
          jsonDecode(request.uri.queryParameters['config']!)['t'],
          contains(9405),
        );
        request.response.statusCode = status;
        if (status == 302) {
          request.response.headers.set(
            'location',
            'http://$host:8080/not-allowed',
          );
        }
        request.response.write('{"9405":60,"6000":-200,"6001":1001}');
        await request.response.close();
      });
      try {
        final api = BatteryApi(client);
        final reading = await api.read(BatteryAddress(host));
        expect(reading.percent, 60);
        expect(reading.packWatts, -200);
        status = 302;
        await expectLater(
          api.read(BatteryAddress(host)),
          throwsA(isA<BatteryFailure>()),
        );
        expect(calls, 2);
        status = 401;
        await expectLater(
          api.read(BatteryAddress(host)),
          throwsA(isA<BatteryFailure>()),
        );
        expect(calls, 3);
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
