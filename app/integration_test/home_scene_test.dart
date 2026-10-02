import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:solar_overview/src/solar_scene.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('native scene repeats and records steady-state rendering cost', (
    tester,
  ) async {
    // Isolated artwork only: never opens storage or contacts either provider.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 260,
              child: SolarScene(active: true, producing: true),
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

    final builds = frames.map((f) => f.buildDuration.inMicroseconds).toList();
    final rasters = frames.map((f) => f.rasterDuration.inMicroseconds).toList();
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
    binding.reportData = report;
    // ignore: avoid_print
    print('Solar scene frame timings: $report');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
