import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'production_total.dart';

class SolarScene extends StatefulWidget {
  const SolarScene({
    super.key,
    required this.active,
    required this.production,
    this.loading = false,
  });
  final bool active;
  final SolarProductionState production;
  final bool loading;

  @override
  State<SolarScene> createState() => _SolarSceneState();
}

class _SolarSceneState extends State<SolarScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: _duration,
  );
  bool _foreground = true;

  Duration get _duration => widget.loading
      ? const Duration(milliseconds: 1500)
      : widget.production == SolarProductionState.zero
      ? const Duration(seconds: 180)
      : const Duration(seconds: 5);

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
    if (oldWidget.loading != widget.loading ||
        oldWidget.production != widget.production) {
      _motion.stop();
      _motion.duration = _duration;
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
  Widget build(BuildContext context) => Semantics(
    label: widget.production == SolarProductionState.zero
        ? 'Decorative zero-production scene. '
              'Window light does not indicate household consumption or live weather.'
        : null,
    excludeSemantics: true,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: SolarScenePainter(
          _motion,
          production: widget.production,
          loading: widget.loading,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class SolarScenePainter extends CustomPainter {
  SolarScenePainter(
    this.phase, {
    required this.production,
    this.loading = false,
  }) : super(repaint: phase);
  final Animation<double> phase;
  final SolarProductionState production;
  final bool loading;

  double get houseLift => loading
      ? 10 * math.pow(math.sin(phase.value * math.pi), 2).toDouble()
      : 0;

  static const _shootingStarPaths = [
    (start: Offset(304, 12), end: Offset(190, 129)),
    (start: Offset(42, 18), end: Offset(154, 123)),
    (start: Offset(232, 10), end: Offset(116, 142)),
    (start: Offset(126, 16), end: Offset(266, 126)),
    (start: Offset(334, 49), end: Offset(226, 158)),
    (start: Offset(24, 61), end: Offset(119, 156)),
  ];

  ({Offset start, Offset end}) get shootingStarPath =>
      _shootingStarPaths[(phase.value * 6).floor() % _shootingStarPaths.length];

  double? get shootingStarProgress {
    if (production != SolarProductionState.zero || loading) return null;
    final seconds = (phase.value * 180) % 30;
    if (seconds < 28.5) return null;
    return (seconds - 28.5) / 1.5;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final zero = production == SolarProductionState.zero;
    final sceneHeight = zero ? 420.0 : 260.0;
    final scale = math.min(size.width / 360, size.height / sceneHeight);
    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - sceneHeight * scale) / 2,
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

    final green = zero ? const Color(0xFF345D50) : const Color(0xFF22634A);
    final dark = zero ? const Color(0xFF183D34) : const Color(0xFF174C39);
    final cream = zero ? const Color(0xFF81998A) : const Color(0xFFFFF2D8);
    final side = zero ? const Color(0xFF536F60) : const Color(0xFFD7E2CB);
    final ambient = loading
        ? 0.0
        : zero
        ? (phase.value * 15) % 1
        : phase.value;
    final warmth = .5 + .5 * math.sin(ambient * math.pi * 2);
    final window = zero
        ? Color.lerp(const Color(0xFFFFCB70), const Color(0xFFFFEDBD), warmth)!
        : green;
    final sunColor = production == SolarProductionState.positive
        ? const Color(0xFFE9B851)
        : const Color(0xFFAFBCAB);
    if (zero) {
      const dipper = [
        Offset(85, 44),
        Offset(116, 27),
        Offset(147, 31),
        Offset(175, 43),
        Offset(184, 72),
        Offset(227, 75),
        Offset(244, 39),
      ];
      for (var i = 0; i < dipper.length - 1; i++) {
        line(dipper[i], dipper[i + 1], const Color(0x33FFEAC3), .65);
      }
      line(dipper.last, dipper[3], const Color(0x33FFEAC3), .65);
      const stars = [
        ...dipper,
        Offset(33, 30),
        Offset(57, 76),
        Offset(151, 88),
        Offset(205, 14),
        Offset(284, 24),
        Offset(318, 69),
        Offset(20, 116),
        Offset(66, 138),
        Offset(110, 110),
        Offset(164, 146),
        Offset(210, 111),
        Offset(251, 132),
        Offset(299, 117),
        Offset(335, 148),
        Offset(274, 83),
        Offset(98, 157),
      ];
      for (var i = 0; i < stars.length; i++) {
        final pulse =
            .5 +
            .5 * math.sin(ambient * math.pi * 2 * (i.isEven ? 2 : 3) + i * 2.4);
        final twinkle = .3 + .7 * pulse;
        final radius = (i < dipper.length ? 1.5 : .8) + pulse * .75;
        final halo = radius * (3.5 + pulse);
        paint
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFEAC3).withValues(alpha: .24 * pulse + .05),
              const Color(0x00FFEAC3),
            ],
          ).createShader(Rect.fromCircle(center: stars[i], radius: halo));
        canvas.drawCircle(stars[i], halo, paint);
        paint.shader = null;
        fill(const Color(0xFFFFEAC3).withValues(alpha: twinkle));
        canvas.drawCircle(stars[i], radius, paint);
        if (i < dipper.length || i.isEven) {
          final color = const Color(0xFFFFEAC3).withValues(alpha: twinkle * .7);
          final reach = 2.5 + pulse * 2;
          line(
            stars[i] - Offset(reach, 0),
            stars[i] + Offset(reach, 0),
            color,
            .7,
          );
          line(
            stars[i] - Offset(0, reach),
            stars[i] + Offset(0, reach),
            color,
            .7,
          );
        }
      }
      final shooting = shootingStarProgress;
      if (shooting != null && shooting > 0) {
        final (:start, :end) = shootingStarPath;
        final tip = Offset.lerp(start, end, shooting)!;
        final tail = Offset.lerp(start, end, math.max(0, shooting - .3))!;
        final brightness = math.sin(shooting * math.pi);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: start.dx > end.dx ? Alignment.topRight : Alignment.topLeft,
            end: start.dx > end.dx
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            colors: [
              const Color(0x00FFF1CD),
              const Color(0xFFFFF1CD).withValues(alpha: brightness * .85),
            ],
          ).createShader(Rect.fromPoints(tail, tip));
        canvas.drawLine(tail, tip, paint);
        paint.shader = null;
        fill(const Color(0xFFFFF1CD).withValues(alpha: brightness * .12));
        canvas.drawCircle(tip, 6, paint);
        fill(const Color(0xFFFFF7E5).withValues(alpha: brightness));
        canvas.drawCircle(tip, 1.8, paint);
      }
    } else {
      final pulse = .5 + .5 * math.sin(phase.value * math.pi * 2);
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
    }
    if (zero) canvas.translate(0, 150);
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
    polygon([
      const Offset(75, 55),
      const Offset(99, 48),
      const Offset(99, 71),
      const Offset(75, 78),
    ], side);
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
    void litWindow(Rect bounds) {
      if (zero) {
        final glow = bounds.inflate(4 + warmth * 2);
        paint
          ..style = PaintingStyle.fill
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFD483).withValues(alpha: .34 + warmth * .22),
              const Color(0x00FFD483),
            ],
          ).createShader(glow);
        canvas.drawOval(glow, paint);
        paint.shader = null;
      }
      fill(window);
      canvas.drawRect(bounds, paint);
    }

    litWindow(const Rect.fromLTRB(52.7, 29.5, 55.3, 35.5));
    line(const Offset(52.2, 35.8), const Offset(55.8, 35.8), dark, .5);
    litWindow(const Rect.fromLTRB(45, 41, 63, 49.5));
    for (final x in [48.5, 59.5]) {
      line(Offset(x, 41), Offset(x, 49.5), cream, .8);
    }
    line(const Offset(44.5, 50), const Offset(63.5, 50), dark, .7);
    fill(side);
    canvas.drawRect(const Rect.fromLTRB(34.5, 59.5, 55, 78), paint);
    litWindow(const Rect.fromLTRB(34.5, 59.5, 55, 71.5));
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
    fill(green);
    canvas.drawRect(const Rect.fromLTRB(63.5, 61, 73, 73), paint);
    fill(dark);
    canvas.drawRect(const Rect.fromLTRB(65, 61, 71.5, 77.5), paint);
    for (final x in [65.0, 71.5]) {
      line(Offset(x, 61), Offset(x, 77.5), cream, .65);
    }
    if (zero) {
      litWindow(const Rect.fromLTRB(67.5, 63, 69, 74.5));
    } else {
      fill(const Color(0xFF82A997));
      canvas.drawRect(const Rect.fromLTRB(67.5, 63, 69, 74.5), paint);
    }
    for (final y in [65.7, 68.7, 71.7]) {
      line(Offset(67.5, y), Offset(69, y), dark, .5);
    }
    line(const Offset(65.8, 69.5), const Offset(66.1, 69.5), cream, .5);
    line(const Offset(64, 78), const Offset(73, 78), dark, .8);
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
    if (production == SolarProductionState.positive && !loading) {
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
      oldDelegate.production != production ||
      oldDelegate.loading != loading ||
      oldDelegate.phase != phase;
}
