import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_overview/src/production_total.dart';
import 'package:solar_overview/src/solar_scene.dart';

import 'home_test.dart' show scene;

void main() {
  testWidgets(
    'occasional bird alternates direction and respects motion state',
    (tester) async {
      Future<void> show({
        bool active = true,
        bool reduced = false,
        bool loading = false,
        SolarProductionState production = SolarProductionState.positive,
      }) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: SolarScene(
              active: active,
              production: production,
              loading: loading,
            ),
          ),
        ),
      );
      await show();
      await tester.pump(const Duration(seconds: 21));
      expect(scene(tester).birdProgress, isNull);
      await tester.pump(const Duration(seconds: 4));
      for (var flight = 0; flight < 5; flight++) {
        expect(scene(tester).birdProgress, closeTo(3 / 7, .001));
        expect(scene(tester).birdFlyingRight, flight.isEven);
        if (flight < 4) {
          await tester.pump(const Duration(seconds: 4));
          expect(scene(tester).birdProgress, isNull);
          await tester.pump(const Duration(seconds: 26));
        }
      }
      await show(active: false);
      final paused = scene(tester).birdProgress;
      await tester.pump(const Duration(seconds: 10));
      expect(scene(tester).birdProgress, paused);
      await show(reduced: true);
      await tester.pump(const Duration(seconds: 25));
      expect(scene(tester).birdProgress, isNull);
      await show(loading: true);
      await tester.pump(const Duration(seconds: 25));
      expect(scene(tester).birdProgress, isNull);
      await show(production: SolarProductionState.zero);
      await tester.pump(const Duration(seconds: 25));
      expect(scene(tester).birdProgress, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
