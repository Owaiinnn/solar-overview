import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'src/app.dart';
import 'src/connection_controller.dart';
import 'src/credential_store.dart';
import 'src/browser_preview.dart';
import 'src/solaredge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    const preview = BrowserPreview();
    final controller = ConnectionController(preview, preview);
    await controller.initialize();
    runApp(SolarApp(controller: controller, preview: true));
    return;
  }
  final controller = ConnectionController(
    SecureCredentialStore(),
    SolarEdgeApi(http.Client()),
  );
  runApp(SolarApp(controller: controller));
  controller.initialize();
}
