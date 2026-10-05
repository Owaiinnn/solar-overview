import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original, offline vector artwork. Motion is decorative, never a flow meter.
class SolarScene extends StatefulWidget {
  const SolarScene({
    super.key,
    required this.active,
    required this.producing,
    this.loading = false,
  });
  final bool active;
  final bool producing;
  final bool loading;

  @override
  State<SolarScene> createState() => _SolarSceneState();
}

class _SolarSceneState extends State<SolarScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: widget.loading
        ? const Duration(milliseconds: 1500)
        : const Duration(seconds: 5),
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
    if (oldWidget.loading != widget.loading) {
      _motion.stop();
      _motion.duration = widget.loading
          ? const Duration(milliseconds: 1500)
          : const Duration(seconds: 5);
      _motion.value = 0;
    }
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
        painter: SolarScenePainter(
          _motion,
          producing: widget.producing,
          loading: widget.loading,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class SolarScenePainter extends CustomPainter {
  SolarScenePainter(this.phase, {required this.producing, this.loading = false})
    : super(repaint: phase);
  final Animation<double> phase;
  final bool producing;
  final bool loading;

  // At phase zero the house rests on the ground, including reduced motion.
  double get houseLift => loading
      ? 10 * math.pow(math.sin(phase.value * math.pi), 2).toDouble()
      : 0;

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
    // Abstract backdrop only: the entrance hedge is the sole vegetation.
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
    // Soft contact shadow changes as the house rises during loading.
    fill(green.withValues(alpha: .10 - houseLift * .003));
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(167, 225),
        width: 160 - houseLift * 3,
        height: 12 - houseLift * .3,
      ),
      paint,
    );
    canvas.save();
    canvas.translate(145, 56 - houseLift);
    canvas.scale(3);
    canvas.translate(-54, -23);
    // Front elevation uses the exact coordinates of assets/icon/house.svg.
    // Only the side roof/wall and panels extend that front-view logo into a scene.
    polygon([
      const Offset(75, 55),
      const Offset(99, 48),
      const Offset(99, 71),
      const Offset(75, 78),
    ], const Color(0xFFD7E2CB));
    polygon([
      const Offset(54, 23),
      const Offset(78, 16),
      const Offset(101, 48),
      const Offset(77, 55),
    ], green);
    for (var bank = 0; bank < 2; bank++) {
      final origin = Offset(65 + bank * 11.0, 32 - bank * 3.2);
      const across = Offset(9, -2.6);
      const down = Offset(11, 15.3);
      polygon([
        origin,
        origin + across,
        origin + across + down,
        origin + down,
      ], const Color(0xFF163F3C));
      for (var i = 0; i <= 4; i++) {
        final a = origin + down * (i / 4);
        line(a, a + across, const Color(0xFF82B7A5), .3);
      }
      line(
        origin + across * .5,
        origin + across * .5 + down,
        const Color(0xFF82B7A5),
        .3,
      );
    }
    polygon([
      const Offset(31, 55),
      const Offset(54, 23),
      const Offset(77, 55),
      const Offset(75, 55),
      const Offset(75, 78),
      const Offset(33, 78),
      const Offset(33, 55),
    ], cream);
    line(const Offset(31, 55), const Offset(54, 23), dark, 1.8);
    line(const Offset(54, 23), const Offset(77, 55), dark, 1.8);
    line(const Offset(53, 22.5), const Offset(55, 22.5), dark, 1.8);
    line(const Offset(30.5, 55), const Offset(34, 55), dark, 1.8);
    line(const Offset(74, 55), const Offset(77.5, 55), dark, 1.8);
    // Attic and upper window remain centered on the balanced gable.
    fill(green);
    canvas.drawRect(const Rect.fromLTRB(52.7, 29.5, 55.3, 35.5), paint);
    line(const Offset(52.2, 35.8), const Offset(55.8, 35.8), dark, .5);
    fill(green);
    canvas.drawRect(const Rect.fromLTRB(45, 41, 63, 49.5), paint);
    for (final x in [48.5, 59.5]) {
      line(Offset(x, 41), Offset(x, 49.5), cream, .8);
    }
    line(const Offset(44.5, 50), const Offset(63.5, 50), dark, .7);
    // Projecting bay on the left, independent of the upper pane divisions.
    fill(const Color(0xFFD7E2CB));
    canvas.drawRect(const Rect.fromLTRB(34.5, 59.5, 55, 78), paint);
    polygon([
      const Offset(34.5, 59.5),
      const Offset(55, 59.5),
      const Offset(55, 71.5),
      const Offset(34.5, 71.5),
    ], green);
    for (final x in [39.0, 50.5]) {
      line(Offset(x, 59.5), Offset(x, 71.5), cream, .85);
    }
    line(const Offset(34.5, 59.5), const Offset(34.5, 71.5), cream, .85);
    line(const Offset(55, 59.5), const Offset(55, 71.5), cream, .85);
    line(const Offset(34, 72), const Offset(55.5, 72), cream, 1);
    line(const Offset(34, 72.6), const Offset(55.5, 72.6), dark, .4);
    fill(dark);
    canvas.drawRect(const Rect.fromLTRB(32.5, 58, 55.5, 59.5), paint);
    canvas.drawRect(const Rect.fromLTRB(61.5, 59, 75, 60), paint);
    // Dark entrance, slender sidelights and vertical door glazing.
    fill(green);
    canvas.drawRect(const Rect.fromLTRB(63.5, 61, 73, 73), paint);
    fill(dark);
    canvas.drawRect(const Rect.fromLTRB(65, 61, 71.5, 77.5), paint);
    for (final x in [65.0, 71.5]) {
      line(Offset(x, 61), Offset(x, 77.5), cream, .65);
    }
    fill(const Color(0xFF82A997));
    canvas.drawRect(const Rect.fromLTRB(67.5, 63, 69, 74.5), paint);
    for (final y in [65.7, 68.7, 71.7]) {
      line(Offset(67.5, y), Offset(69, y), dark, .5);
    }
    line(const Offset(65.8, 69.5), const Offset(66.1, 69.5), cream, .5);
    line(const Offset(64, 78), const Offset(73, 78), dark, .8);
    // Same closed hedge silhouette as house.svg, inside the house transform:
    // it rises with the facade during loading, never as an independent plant.
    final hedge = Path()
      ..moveTo(58.7, 54)
      ..quadraticBezierTo(60.8, 53.5, 60.7, 57)
      ..quadraticBezierTo(62.3, 58, 61.6, 61)
      ..quadraticBezierTo(63, 63, 62, 65)
      ..quadraticBezierTo(63.4, 67, 62.2, 69)
      ..quadraticBezierTo(63.4, 71, 62.4, 73)
      ..quadraticBezierTo(63.3, 76, 61.7, 79)
      ..quadraticBezierTo(59.5, 80, 56.5, 79)
      ..quadraticBezierTo(55.1, 77, 56.1, 74)
      ..quadraticBezierTo(54.9, 72, 56, 69)
      ..quadraticBezierTo(55, 66, 56.1, 64)
      ..quadraticBezierTo(55.3, 61, 56.8, 59)
      ..quadraticBezierTo(56.2, 56, 58.7, 54)
      ..close();
    fill(green);
    canvas.drawPath(hedge, paint);
    // Sparse foliage marks read at scene size without tracing individual leaves.
    for (var i = 0; i < 5; i++) {
      final y = 59 + i * 3.8;
      line(Offset(57.5, y), Offset(58.6, y + 1.2), const Color(0xFF88A783), .6);
      line(
        Offset(60.6, y + 1),
        Offset(59.8, y + 2.1),
        const Color(0xFF88A783),
        .6,
      );
    }
    canvas.restore();
    if (producing && !loading) {
      // Staggered, soft rays visibly arrive at the panel surface every loop.
      for (var i = 0; i < 3; i++) {
        final t = (phase.value + i / 3) % 1;
        final start = Offset(267 + i * 6.0, 68);
        final end = Offset(207 + i * 16.0, 113 - i * 5.0);
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
      oldDelegate.producing != producing ||
      oldDelegate.loading != loading ||
      oldDelegate.phase != phase;
}
