import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'src/app.dart';
import 'src/p1.dart';
import 'src/p1_controller.dart';
import 'src/p1_store.dart';
import 'src/connection_controller.dart';
import 'src/credential_store.dart';
import 'src/browser_preview.dart';
import 'src/solaredge.dart';
import 'src/reading_store.dart';
import 'src/solax.dart';
import 'src/solax_store.dart';
import 'src/solax_controller.dart';

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
    readingStore: SecureReadingStore(),
  );
  final solax = SolaxController(SecureSolaxStore(), SolaxApi(http.Client()));
  final p1 = P1Controller(SecureP1Store(), P1Api(http.Client()));
  runApp(SolarApp(controller: controller, solax: solax, p1: p1));
  p1.initialize();
  controller.initialize();
  solax.initialize();
}
