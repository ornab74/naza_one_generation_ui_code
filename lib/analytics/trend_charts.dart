// LLM-CONTEXT:BEGIN
// FILE: lib/analytics/trend_charts.dart
// ROLE: Bounded, theme-aware longitudinal charts shared by feature surfaces.
// SECURITY-INVARIANT: Render only caller-supplied numeric summaries; never
// infer medical or safety conclusions from a chart.
// CHANGE-GUARD: Empty and malformed values are ignored, point counts are
// bounded, and chart rendering stays paint-only on the UI isolate.
// LLM-CONTEXT:END
import 'dart:math' as math;

import 'package:flutter/material.dart';

final class NazaTrendPoint {
  final DateTime time;
  final double value;
  final String? label;

  const NazaTrendPoint({required this.time, required this.value, this.label});
}

final class NazaTrendSeries {
  final String name;
  final Color color;
  final List<NazaTrendPoint> points;

  NazaTrendSeries({
    required this.name,
    required this.color,
    required Iterable<NazaTrendPoint> points,
  }) : points = List<NazaTrendPoint>.unmodifiable(points.take(120));
}

final class NazaTrendChart extends StatelessWidget {
  final List<NazaTrendSeries> series;
  final String emptyMessage;
  final double height;

  const NazaTrendChart({
    super.key,
    required this.series,
    this.emptyMessage = 'Add a few dated entries to reveal a trend.',
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final usable = series
        .where((item) => item.points.isNotEmpty)
        .toList(growable: false);
    if (usable.isEmpty)
      return SizedBox(
        height: height,
        child: Center(child: Text(emptyMessage, textAlign: TextAlign.center)),
      );
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _NazaTrendPainter(
              series: usable,
              grid: colors.outlineVariant,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: usable
              .map(
                (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

final class _NazaTrendPainter extends CustomPainter {
  final List<NazaTrendSeries> series;
  final Color grid;
  const _NazaTrendPainter({required this.series, required this.grid});

  @override
  void paint(Canvas canvas, Size size) {
    final all = series.expand((item) => item.points).toList(growable: false);
    final minTime = all
        .map((item) => item.time.millisecondsSinceEpoch)
        .reduce(math.min)
        .toDouble();
    final maxTime = all
        .map((item) => item.time.millisecondsSinceEpoch)
        .reduce(math.max)
        .toDouble();
    final minValue = all.map((item) => item.value).reduce(math.min);
    final maxValue = all.map((item) => item.value).reduce(math.max);
    final timeSpan = math.max(1, maxTime - minTime);
    final valueSpan = math.max(1e-9, maxValue - minValue);
    final chart = Rect.fromLTWH(
      12,
      10,
      math.max(1, size.width - 24),
      math.max(1, size.height - 24),
    );
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: .28)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = chart.top + chart.height * row / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    for (final item in series) {
      if (item.points.isEmpty) continue;
      final points = item.points
          .map(
            (point) => Offset(
              chart.left +
                  chart.width *
                      (point.time.millisecondsSinceEpoch - minTime) /
                      timeSpan,
              chart.bottom -
                  chart.height * (point.value - minValue) / valueSpan,
            ),
          )
          .toList(growable: false);
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var index = 1; index < points.length; index++) {
        final prior = points[index - 1];
        final current = points[index];
        final mid = (prior.dx + current.dx) / 2;
        path.cubicTo(mid, prior.dy, mid, current.dy, current.dx, current.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      for (final point in points)
        canvas.drawCircle(point, 3.5, Paint()..color = item.color);
    }
  }

  @override
  bool shouldRepaint(covariant _NazaTrendPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.grid != grid;
}

final class NazaAnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<NazaTrendSeries> series;
  final String emptyMessage;

  const NazaAnalyticsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.series,
    this.emptyMessage = 'Add more dated entries to reveal a useful trend.',
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          NazaTrendChart(series: series, emptyMessage: emptyMessage),
        ],
      ),
    ),
  );
}
