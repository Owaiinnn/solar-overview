import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'src/app.dart';
import 'src/connection_controller.dart';
import 'src/credential_store.dart';
import 'src/solaredge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = ConnectionController(
    SecureCredentialStore(),
    SolarEdgeApi(http.Client()),
  );
  runApp(SolarApp(controller: controller));
  controller.initialize();
}
