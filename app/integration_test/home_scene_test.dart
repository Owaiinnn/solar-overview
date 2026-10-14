import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/solar_scene.dart';
import 'package:solar_overview/src/home_energy.dart';
import 'package:solar_overview/src/battery.dart';
import 'package:solar_overview/src/p1.dart';
import 'package:solar_overview/src/production_total.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final results = <String, Object>{};
  for (final production in [
    SolarProductionState.positive,
    SolarProductionState.zero,
  ]) {
    testWidgets(
      'native $production scene repeats and records steady-state rendering cost',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: production == SolarProductionState.zero
                  ? const Color(0xFF18352F)
                  : const Color(0xFFF5F7F3),
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 420,
                  child: SolarScene(
                    active: true,
                    production: production,
                    battery: const HomeBatteryState(
                      quality: LocalReadingQuality.recent,
                      percent: 60,
                      state: BatteryState.charging,
                      packWatts: -520,
                    ),
                    grid: const HomeGridState(
                      quality: LocalReadingQuality.recent,
                      direction: GridDirection.exporting,
                      watts: -520,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 2));
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> timings) => frames.addAll(timings);
        SchedulerBinding.instance.addTimingsCallback(collect);
        try {
          await Future<void>.delayed(const Duration(seconds: 12));
        } finally {
          SchedulerBinding.instance.removeTimingsCallback(collect);
        }
        expect(frames.length, greaterThan(30));
        double percentile(List<int> values, double p) {
          values.sort();
          return values[((values.length - 1) * p).round()] / 1000;
        }

        final builds = frames
            .map((f) => f.buildDuration.inMicroseconds)
            .toList();
        final rasters = frames
            .map((f) => f.rasterDuration.inMicroseconds)
            .toList();
        final report = <String, Object>{
          'frames': frames.length,
          'build_p50_ms': percentile(builds, .5),
          'build_p95_ms': percentile(builds, .95),
          'raster_p50_ms': percentile(rasters, .5),
          'raster_p95_ms': percentile(rasters, .95),
          'frames_over_16_67_ms': frames
              .where(
                (f) =>
                    f.buildDuration.inMicroseconds > 16667 ||
                    f.rasterDuration.inMicroseconds > 16667,
              )
              .length,
        };
        results[production.name] = report;
        binding.reportData = results;
        // ignore: avoid_print
        print('Solar $production scene frame timings: $report');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
