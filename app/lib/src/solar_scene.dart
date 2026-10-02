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
      const Offset(74, 59),
      const Offset(98, 52),
      const Offset(98, 71),
      const Offset(74, 78),
    ], const Color(0xFFD7E2CB));
    polygon([
      const Offset(54, 23),
      const Offset(78, 16),
      const Offset(101, 52),
      const Offset(77, 59),
    ], green);
    for (var bank = 0; bank < 2; bank++) {
      final origin = Offset(65 + bank * 11.0, 32 - bank * 3.2);
      const across = Offset(9, -2.6);
      const down = Offset(12, 18.8);
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
      const Offset(31, 59),
      const Offset(54, 23),
      const Offset(77, 59),
      const Offset(74, 59),
      const Offset(74, 78),
      const Offset(34, 78),
      const Offset(34, 59),
    ], cream);
    line(const Offset(31, 59), const Offset(54, 23), dark, 1.8);
    line(const Offset(54, 23), const Offset(77, 59), dark, 1.8);
    line(const Offset(30, 59), const Offset(35, 59), dark, 1.8);
    line(const Offset(73, 59), const Offset(78, 59), dark, 1.8);
    // Narrow attic and wide upper window, centered at the logo's x=54.
    fill(green);
    canvas.drawRect(const Rect.fromLTRB(52.7, 31, 55.3, 38.5), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(44, 44.5, 64, 54),
        const Radius.circular(.5),
      ),
      paint,
    );
    for (final x in [48.0, 60.0]) {
      line(Offset(x, 44.5), Offset(x, 54), cream, .8);
    }
    // Projecting bay: shallow canopy, matching aligned three-pane dividers,
    // and a raised base. No horizontal crossbar absent from the app logo.
    fill(const Color(0xFFB7C9AD));
    canvas.drawRect(const Rect.fromLTRB(41, 62, 67, 64.5), paint);
    fill(const Color(0xFFD7E2CB));
    canvas.drawRect(const Rect.fromLTRB(43.5, 64.5, 64.5, 78), paint);
    fill(green);
    canvas.drawRect(const Rect.fromLTRB(43.5, 64.5, 64.5, 75.5), paint);
    for (final x in [48.0, 60.0]) {
      line(Offset(x, 64.5), Offset(x, 75.5), cream, .8);
    }
    line(const Offset(43.25, 75.5), const Offset(64.75, 75.5), green, .8);
    fill(green);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(66.25, 66, 72, 78),
        const Radius.circular(.5),
      ),
      paint,
    );
    line(const Offset(70.25, 72.5), const Offset(70.75, 72.5), cream, .6);
    canvas.restore();
    // Small garden plants frame the house.
    for (final x in [65.0, 300.0]) {
      line(Offset(x, 218), Offset(x, 182), green, 3);
      fill(const Color(0xFF88A783));
      canvas.drawOval(Rect.fromLTWH(x - 17, 178, 18, 28), paint);
      canvas.drawOval(Rect.fromLTWH(x, 187, 16, 24), paint);
    }
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
