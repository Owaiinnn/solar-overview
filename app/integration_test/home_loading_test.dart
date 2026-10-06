import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/app.dart';
import 'package:solar_overview/src/connection_controller.dart';
import 'package:solar_overview/src/solaredge.dart';

import '../test/fakes.dart';

class _OpeningStore extends MemoryStore {
  final ready = Completer<SolarEdgeCredentials?>();
  @override
  Future<SolarEdgeCredentials?> read() => ready.future;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('native Home loading animation then empty state', (tester) async {
    final store = _OpeningStore();
    final edge = ConnectionController(store, FakeSource());
    final opening = edge.initialize();
    await tester.pumpWidget(SolarApp(controller: edge));
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await binding.takeScreenshot('home-loading');
    await Future<void>.delayed(const Duration(milliseconds: 750));
    await binding.takeScreenshot('home-loading-next');
    store.ready.complete(null);
    await opening;
    await tester.pump();
    expect(find.text('Loading…'), findsNothing);
    expect(find.text('Unavailable'), findsOneWidget);
    await binding.takeScreenshot('home-loading-complete');
    await tester.pumpWidget(const SizedBox());
    edge.dispose();
  });
}
