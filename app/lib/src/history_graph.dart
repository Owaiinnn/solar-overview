import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'history.dart';
import 'history_controller.dart';

class HistoryGraph extends StatefulWidget {
  const HistoryGraph({super.key, required this.data, this.dc = false});
  final Map<HistorySource, ProductionHistory> data;
  final bool dc;
  @override
  State<HistoryGraph> createState() => _HistoryGraphState();
}

class _HistoryGraphState extends State<HistoryGraph> {
  double? _selected;
  bool _readingsExpanded = false;
  @override
  void didUpdateWidget(HistoryGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.values.first.day.date !=
        widget.data.values.first.day.date) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.data.values.first.day;
    final combined = widget.dc
        ? null
        : combinedPowerHistory(
            widget.data[HistorySource.solarEdge],
            widget.data[HistorySource.solax],
          );
    final lines = <_PlotLine>[
      for (final entry in widget.data.entries)
        if (widget.dc) ...[
          _PlotLine(
            'SolaX input 1 (DC)',
            const Color(0xFF6A4897),
            entry.value.samples,
            (sample) => sample.mppt1,
          ),
          _PlotLine(
            'SolaX input 2 (DC)',
            const Color(0xFF23618A),
            entry.value.samples,
            (sample) => sample.mppt2,
          ),
        ] else
          _PlotLine(
            '${historySourceName(entry.key)} (AC)',
            entry.key == HistorySource.solarEdge
                ? const Color(0xFF22634A)
                : const Color(0xFFAE5700),
            entry.value.samples,
            (sample) => sample.watts,
          ),
      if (combined != null)
        _PlotLine(
          'Combined (AC)',
          const Color(0xFF3949AB),
          combined.samples,
          (sample) => sample.watts,
          strokeWidth: 3,
        ),
    ];
    final maxWatts = math.max(
      1000.0,
      lines
          .expand((line) => line.samples.map(line.value))
          .whereType<double>()
          .fold(0.0, math.max),
    );
    final topKw = (maxWatts / 1000).ceilToDouble();
    final selectedTime = _selected == null
        ? null
        : day.start.add(
            Duration(
              milliseconds:
                  (day.end.difference(day.start).inMilliseconds * _selected!)
                      .round(),
            ),
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.dc ? 'DC input power' : 'AC production power',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${day.timeZone} · ${day.end.difference(day.start).inHours}-hour day',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final line in lines)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart, color: line.color, size: 20),
                      const SizedBox(width: 4),
                      Flexible(child: Text(line.label)),
                    ],
                  ),
              ],
            ),
            if (!widget.dc) ...[
              const SizedBox(height: 8),
              Text(
                combined == null
                    ? 'Combined needs both sources loaded and selected for the same day and timezone.'
                    : 'Combined = SolarEdge + SolaX at matching 15-minute timestamps. Missing readings stay as gaps.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Text('${topKw.toStringAsFixed(1)} kW'),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label: 'Power graph. Missing samples are gaps. Expand readings below for accessible values.',
                child: GestureDetector(
                  key: ValueKey('history-plot-${widget.dc}'),
                  onTapDown: (details) => setState(
                    () => _selected =
                        (details.localPosition.dx / constraints.maxWidth).clamp(
                          0,
                          1,
                        ),
                  ),
                  onHorizontalDragUpdate: (details) => setState(
                    () => _selected =
                        (details.localPosition.dx / constraints.maxWidth).clamp(
                          0,
                          1,
                        ),
                  ),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _HistoryPainter(
                        day,
                        lines,
                        topKw * 1000,
                        Theme.of(context).colorScheme.outlineVariant,
                        _selected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Text('0 kW'),
            Row(
              children: [
                for (final fraction in [0.0, 0.5, 1.0])
                  Expanded(
                    child: Text(
                      historyClock(
                        day.start.add(
                          Duration(
                            milliseconds:
                                (day.end.difference(day.start).inMilliseconds *
                                        fraction)
                                    .round(),
                          ),
                        ),
                        day.timeZone,
                      ).substring(0, 5),
                      textAlign: fraction == 0
                          ? TextAlign.left
                          : fraction == 1
                          ? TextAlign.right
                          : TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            if (selectedTime != null) ...[
              const SizedBox(height: 8),
              Text(historyClock(selectedTime, day.timeZone)),
              for (final line in lines)
                Text(_selectedReading(line, selectedTime)),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Tap or drag to inspect readings.'),
              ),
            ExpansionTile(
              key: PageStorageKey(
                'history-readings-${widget.dc}-${day.timeZone}',
              ),
              tilePadding: EdgeInsets.zero,
              title: const Text('Readings in W'),
              onExpansionChanged: (value) =>
                  setState(() => _readingsExpanded = value),
              children: [
                if (_readingsExpanded)
                  for (final line in lines) ...[
                    Text(
                      line.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final sample in line.samples)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${historyClock(sample.time, day.timeZone)} · ${line.value(sample)?.toStringAsFixed(0) ?? 'Unavailable'}${line.value(sample) == null ? '' : ' W'}',
                        ),
                      ),
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _selectedReading(_PlotLine line, DateTime time) {
    final before = line.samples.where((sample) => !sample.time.isAfter(time));
    final sample = before.isEmpty ? null : before.last;
    final value = sample == null ? null : line.value(sample);
    final measuredAt = sample == null
        ? ''
        : ' · ${historyClock(sample.time, widget.data.values.first.day.timeZone)}';
    return '${line.label}: ${value == null ? 'Unavailable' : '${value.toStringAsFixed(0)} W'}$measuredAt';
  }
}

class _PlotLine {
  const _PlotLine(
    this.label,
    this.color,
    this.samples,
    this.value, {
    this.strokeWidth = 2,
  });
  final String label;
  final Color color;
  final List<HistorySample> samples;
  final double? Function(HistorySample) value;
  final double strokeWidth;
}

class _HistoryPainter extends CustomPainter {
  _HistoryPainter(
    this.day,
    this.lines,
    this.maxWatts,
    this.grid,
    this.selected,
  );
  final HistoryDay day;
  final List<_PlotLine> lines;
  final double maxWatts;
  final Color grid;
  final double? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        gridPaint,
      );
    }
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      Offset? previous;
      for (final sample in line.samples) {
        final watts = line.value(sample);
        if (watts == null) {
          previous = null;
          continue;
        }
        final point = Offset(
          sample.time.difference(day.start).inMilliseconds /
              day.end.difference(day.start).inMilliseconds *
              size.width,
          size.height * (1 - watts / maxWatts),
        );
        if (previous != null) canvas.drawLine(previous, point, paint);
        canvas.drawCircle(point, 1.5, Paint()..color = line.color);
        previous = point;
      }
    }
    if (selected != null) {
      canvas.drawLine(
        Offset(size.width * selected!, 0),
        Offset(size.width * selected!, size.height),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_HistoryPainter oldDelegate) => true;
}
