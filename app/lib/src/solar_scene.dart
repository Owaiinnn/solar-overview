import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original, offline vector artwork. Motion is decorative, never a flow meter.
class SolarScene extends StatefulWidget {
  const SolarScene({super.key, required this.active, required this.producing});
  final bool active;
  final bool producing;

  @override
  State<SolarScene> createState() => _SolarSceneState();
}

class _SolarSceneState extends State<SolarScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(SolarScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (widget.active &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !reduced) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
      if (reduced) _motion.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: SolarScenePainter(_motion, producing: widget.producing),
        size: Size.infinite,
      ),
    ),
  );
}

class SolarScenePainter extends CustomPainter {
  SolarScenePainter(this.phase, {required this.producing})
    : super(repaint: phase);
  final Animation<double> phase;
  final bool producing;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 360, size.height / 260);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 260 * scale) / 2,
    );
    canvas.scale(scale);
    final paint = Paint()..isAntiAlias = true;
    void fill(Color color) {
      paint
        ..color = color
        ..style = PaintingStyle.fill;
    }

    void polygon(List<Offset> points, Color color) {
      fill(color);
      canvas.drawPath(Path()..addPolygon(points, true), paint);
    }

    void line(Offset a, Offset b, Color color, double width) {
      paint
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, b, paint);
    }

    const green = Color(0xFF22634A);
    const dark = Color(0xFF174C39);
    const cream = Color(0xFFFFF2D8);
    // A soft garden silhouette grounds the scene without implying wiring.
    fill(const Color(0xFFE7EDE2));
    canvas.drawOval(const Rect.fromLTWH(24, 206, 312, 34), paint);
    fill(const Color(0xFFEAF0E5));
    canvas.drawCircle(const Offset(167, 142), 94, paint);
    final pulse = .5 + .5 * math.sin(phase.value * math.pi * 2);
    final sunColor = producing
        ? const Color(0xFFE9B851)
        : const Color(0xFFAFBCAB);
    fill(sunColor.withValues(alpha: .09 + pulse * .04));
    canvas.drawCircle(const Offset(282, 46), 37 + pulse * 3, paint);
    fill(sunColor.withValues(alpha: .18));
    canvas.drawCircle(const Offset(282, 46), 28, paint);
    fill(sunColor);
    canvas.drawCircle(const Offset(282, 46), 19, paint);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      line(
        const Offset(282, 46) + direction * 25,
        const Offset(282, 46) + direction * 30,
        sunColor.withValues(alpha: .7),
        2,
      );
    }
    // Front gable, side wall and pitched roof echo the launcher house.
    polygon([
      const Offset(89, 145),
      const Offset(148, 85),
      const Offset(207, 145),
      const Offset(207, 222),
      const Offset(89, 222),
    ], cream);
    polygon([
      const Offset(207, 145),
      const Offset(281, 121),
      const Offset(281, 204),
      const Offset(207, 222),
    ], const Color(0xFFD7E2CB));
    polygon([
      const Offset(148, 85),
      const Offset(222, 62),
      const Offset(289, 122),
      const Offset(207, 150),
    ], green);
    line(const Offset(81, 149), const Offset(148, 82), dark, 7);
    line(const Offset(148, 82), const Offset(208, 148), dark, 7);
    // Two panel banks on the roof; no claim about the installation topology.
    for (var bank = 0; bank < 2; bank++) {
      final origin = Offset(171 + bank * 34.0, 94 - bank * 10.0);
      const across = Offset(29, -9);
      const down = Offset(35, 34);
      polygon([
        origin,
        origin + across,
        origin + across + down,
        origin + down,
      ], const Color(0xFF163F3C));
      for (var i = 0; i <= 3; i++) {
        final a = origin + down * (i / 3);
        line(a, a + across, const Color(0xFF82B7A5), .9);
      }
      line(
        origin + across * .5,
        origin + across * .5 + down,
        const Color(0xFF82B7A5),
        .9,
      );
    }
    fill(green);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(133, 124, 25, 23),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(109, 162, 53, 43),
        const Radius.circular(3),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(175, 176, 20, 46),
        const Radius.circular(3),
      ),
      paint,
    );
    line(const Offset(126, 165), const Offset(126, 202), cream, 2);
    line(const Offset(145, 165), const Offset(145, 202), cream, 2);
    line(const Offset(111, 182), const Offset(160, 182), cream, 2);
    line(const Offset(145, 127), const Offset(145, 144), cream, 2);
    fill(cream);
    canvas.drawCircle(const Offset(189, 201), 1.6, paint);
    line(
      const Offset(104, 207),
      const Offset(165, 207),
      const Color(0xFFB7C9AD),
      5,
    );
    // Small garden plants frame the house.
    for (final x in [65.0, 300.0]) {
      line(Offset(x, 218), Offset(x, 182), green, 3);
      fill(const Color(0xFF88A783));
      canvas.drawOval(Rect.fromLTWH(x - 17, 178, 18, 28), paint);
      canvas.drawOval(Rect.fromLTWH(x, 187, 16, 24), paint);
    }
    if (producing) {
      // Staggered, soft rays visibly arrive at the panel surface every loop.
      for (var i = 0; i < 3; i++) {
        final t = (phase.value + i / 3) % 1;
        final start = Offset(267 + i * 6.0, 68);
        final end = Offset(199 + i * 17.0, 116 - i * 5.0);
        final opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
        final tip = Offset.lerp(start, end, t)!;
        final tail = Offset.lerp(start, end, math.max(0, t - .22))!;
        line(tail, tip, sunColor.withValues(alpha: opacity * .12), 12);
        line(tail, tip, sunColor.withValues(alpha: opacity * .85), 3);
        if (t > .8) {
          fill(sunColor.withValues(alpha: (1 - t) * 2));
          canvas.drawCircle(end, 3 + (t - .8) * 25, paint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SolarScenePainter oldDelegate) =>
      oldDelegate.producing != producing || oldDelegate.phase != phase;
}
