import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final directory = Directory('build/history-preview');
    await directory.create(recursive: true);
    var index = 0;
    for (final capture in data?['screenshots'] as List<dynamic>? ?? []) {
      await File('${directory.path}/history-${index++}.png')
          .writeAsBytes(List<int>.from(capture['bytes'] as List));
    }
  },
);
