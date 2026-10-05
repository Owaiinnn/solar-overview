import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

// Synthetic captures only. Always run with --keep-app-running to preserve data.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final directory = Directory('build/p1-preview');
    await directory.create(recursive: true);
    for (final capture in data?['screenshots'] as List<dynamic>? ?? []) {
      await File('${directory.path}/${capture['screenshotName']}.png')
          .writeAsBytes(List<int>.from(capture['bytes'] as List));
    }
  },
);
