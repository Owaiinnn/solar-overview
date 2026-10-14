import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'battery.dart';
import 'home_energy.dart';
import 'p1.dart';
import 'production_total.dart';

class SolarScene extends StatefulWidget {
  const SolarScene({
    super.key,
    required this.active,
    required this.production,
    this.loading = false,
    this.battery = const HomeBatteryState(),
    this.grid = const HomeGridState(),
  });
  final bool active;
  final SolarProductionState production;
  final bool loading;
  final HomeBatteryState battery;
  final HomeGridState grid;

  @override
  State<SolarScene> createState() => _SolarSceneState();
}

class _SolarSceneState extends State<SolarScene>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: _duration,
  );
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
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
      if (widget.battery.moving || widget.grid.moving) {
        if (!_flow.isAnimating) _flow.repeat();
      } else {
        _flow.stop();
        _flow.value = 0;
      }
    } else {
      _motion.stop();
      _flow.stop();
      if (reduced) {
        _motion.value = 0;
        _flow.value = 0;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.production == SolarProductionState.zero
        ? 'Decorative zero-production scene. '
              'Window light does not indicate household consumption or live weather.'
        : 'Decorative solar scene. Sun and rays do not indicate live weather.',
    excludeSemantics: true,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: SolarScenePainter(
          _motion,
          production: widget.production,
          loading: widget.loading,
          battery: widget.battery,
          grid: widget.grid,
          flow: _flow,
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
    this.battery = const HomeBatteryState(),
    this.grid = const HomeGridState(),
    this.flow = const AlwaysStoppedAnimation(0),
  }) : super(repaint: Listenable.merge([phase, flow]));
  final Animation<double> phase;
  final SolarProductionState production;
  final bool loading;
  final HomeBatteryState battery;
  final HomeGridState grid;
  final Animation<double> flow;

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
    const sceneHeight = 420.0;
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
    canvas.save();
    canvas.translate(0, 150);
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
        final start = Offset(267 + i * 6.0, -82);
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
    _paintEnergy(canvas, zero);
    canvas.restore();
  }

  void _paintEnergy(Canvas canvas, bool dark) {
    final ink = dark ? const Color(0xFFD9E8D6) : const Color(0xFF22634A);
    final accent = dark ? const Color(0xFFFFD483) : const Color(0xFF997123);
    final muted = ink.withValues(alpha: .3);
    final paint = Paint()..isAntiAlias = true;
    void line(Offset start, Offset end, Color color, double width) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawLine(start, end, paint);
    }

    void flowPath(Offset start, Offset end, bool outward) {
      line(start, end, muted, 1.5);
      final from = outward ? start : end;
      final to = outward ? end : start;
      for (var i = 0; i < 2; i++) {
        final t = (flow.value + i / 2) % 1;
        final tip = Offset.lerp(from, to, .15 + t * .7)!;
        final sign = to.dx > from.dx ? 1.0 : -1.0;
        line(tip - Offset(sign * 4, 3), tip, accent, 2);
        line(tip - Offset(sign * 4, -3), tip, accent, 2);
      }
    }

    final green = dark ? const Color(0xFF547B65) : const Color(0xFF22634A);
    final edge = dark ? const Color(0xFF264E40) : const Color(0xFF174C39);
    final cream = dark ? const Color(0xFFB1C2A8) : const Color(0xFFFFF2D8);
    final side = dark ? const Color(0xFF6C8872) : const Color(0xFFBDCEAE);
    void polygon(List<Offset> points, Color color) {
      paint
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawPath(Path()..addPolygon(points, true), paint);
    }

    void rounded(Rect bounds, double radius, Color color) {
      paint
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, Radius.circular(radius)),
        paint,
      );
    }

    void shadow(Offset center, double width) {
      paint
        ..style = PaintingStyle.fill
        ..color = green.withValues(alpha: .12);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: width, height: 6),
        paint,
      );
    }

    if (battery.visible) {
      shadow(const Offset(29, 376), 51);
      rounded(const Rect.fromLTRB(10, 365, 40, 373), 2, edge);
      polygon([
        const Offset(39, 314),
        const Offset(49, 309),
        const Offset(49, 363),
        const Offset(39, 370),
      ], side);
      rounded(const Rect.fromLTRB(7, 314, 40, 370), 3, cream);
      polygon([
        const Offset(7, 314),
        const Offset(17, 308),
        const Offset(49, 308),
        const Offset(40, 314),
      ], side);
      rounded(const Rect.fromLTRB(7, 313, 40, 319), 2, green);
      polygon([
        const Offset(40, 313),
        const Offset(49, 308),
        const Offset(49, 314),
        const Offset(40, 319),
      ], edge);
      rounded(const Rect.fromLTRB(13, 324, 34, 356), 2, edge);
      rounded(const Rect.fromLTRB(15, 326, 32, 354), 1, side);
      final percent = battery.percent;
      if (percent != null) {
        rounded(
          Rect.fromLTRB(15, 354 - 28 * percent / 100, 32, 354),
          1,
          battery.recent ? green : green.withValues(alpha: .35),
        );
        for (final y in [333.0, 340.0, 347.0]) {
          line(Offset(16, y), Offset(31, y), cream.withValues(alpha: .35), .7);
        }
      } else {
        line(const Offset(21, 340), const Offset(26, 340), cream, 1.5);
      }
      for (final y in [361.0, 364.0]) {
        line(Offset(17, y), Offset(30, y), side, 1);
      }
      line(
        const Offset(44, 324),
        const Offset(44, 355),
        edge.withValues(alpha: .3),
        1,
      );
      if (battery.moving) {
        flowPath(
          const Offset(52, 350),
          const Offset(73, 350),
          battery.reportedState == BatteryState.discharging,
        );
      }
    }
    if (grid.visible) {
      shadow(const Offset(332, 377), 53);
      polygon([
        const Offset(327, 308),
        const Offset(333, 308),
        const Offset(318, 371),
        const Offset(311, 371),
      ], green);
      polygon([
        const Offset(333, 308),
        const Offset(337, 305),
        const Offset(353, 368),
        const Offset(348, 371),
      ], edge);
      polygon([
        const Offset(331, 308),
        const Offset(337, 308),
        const Offset(348, 371),
        const Offset(342, 371),
      ], green);
      line(const Offset(324, 341), const Offset(341, 361), side, 2.5);
      line(const Offset(338, 341), const Offset(320, 361), side, 2.5);
      for (final beam in [
        const Rect.fromLTRB(310, 320, 350, 325),
        const Rect.fromLTRB(316, 336, 344, 341),
      ]) {
        polygon([
          beam.topLeft,
          beam.topLeft + const Offset(4, -3),
          beam.topRight + const Offset(4, -3),
          beam.topRight,
        ], side);
        rounded(beam, 1, green);
        polygon([
          beam.topRight,
          beam.topRight + const Offset(4, -3),
          beam.bottomRight + const Offset(4, -3),
          beam.bottomRight,
        ], edge);
        for (final x in [beam.left + 3, beam.right - 4]) {
          rounded(Rect.fromLTWH(x, beam.top - 7, 3, 7), 1, cream);
          line(
            Offset(x - .5, beam.top - 4),
            Offset(x + 3.5, beam.top - 4),
            side,
            1,
          );
        }
      }
      rounded(const Rect.fromLTRB(308, 370, 320, 374), 1, side);
      rounded(const Rect.fromLTRB(341, 370, 353, 374), 1, side);
      if (grid.moving) {
        flowPath(
          const Offset(308, 350),
          const Offset(288, 350),
          grid.direction == GridDirection.importing,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SolarScenePainter oldDelegate) =>
      oldDelegate.production != production ||
      oldDelegate.loading != loading ||
      oldDelegate.battery != battery ||
      oldDelegate.grid != grid ||
      oldDelegate.flow != flow ||
      oldDelegate.phase != phase;
}
