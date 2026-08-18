import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:naza_one/naza_rev_recall/app/app_theme.dart';
import 'package:naza_one/naza_rev_recall/models/car_profile.dart';

class CarWheel extends StatelessWidget {
  const CarWheel({
    required this.cars,
    required this.centerLabel,
    this.highlightedCarId,
    this.onCarTap,
    this.enabled = true,
    this.size = 300,
    super.key,
  });

  final List<CarProfile> cars;
  final String centerLabel;
  final String? highlightedCarId;
  final ValueChanged<String>? onCarTap;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled && onCarTap != null
            ? (details) {
                final center = Offset(size / 2, size / 2);
                final delta = details.localPosition - center;
                final radius = delta.distance;
                if (radius < size * 0.19 ||
                    radius > size * 0.49 ||
                    cars.isEmpty) {
                  return;
                }
                var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
                if (angle < 0) {
                  angle += math.pi * 2;
                }
                final index =
                    (angle / (math.pi * 2 / cars.length)).floor() % cars.length;
                onCarTap!(cars[index].id);
              }
            : null,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(highlightedCarId),
          tween: Tween(begin: 0.88, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: CustomPaint(
            painter: _CarWheelPainter(
              cars: cars,
              highlightedCarId: highlightedCarId,
              centerLabel: centerLabel,
              enabled: enabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _CarWheelPainter extends CustomPainter {
  const _CarWheelPainter({
    required this.cars,
    required this.highlightedCarId,
    required this.centerLabel,
    required this.enabled,
  });

  final List<CarProfile> cars;
  final String? highlightedCarId;
  final String centerLabel;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (cars.isEmpty) {
      return;
    }
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide * 0.43;
    final ringWidth = size.shortestSide * 0.19;
    final ringRect = Rect.fromCircle(
      center: center,
      radius: outerRadius - ringWidth / 2,
    );
    final segmentAngle = math.pi * 2 / cars.length;
    final gap = math.min(0.045, segmentAngle * 0.1);

    canvas.drawCircle(
      center,
      outerRadius + 8,
      Paint()
        ..color = AppColors.panel
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    for (var index = 0; index < cars.length; index++) {
      final car = cars[index];
      final start = -math.pi / 2 + index * segmentAngle + gap;
      final sweep = segmentAngle - gap * 2;
      final selected = car.id == highlightedCarId;
      final color = enabled ? car.color : car.color.withValues(alpha: 0.45);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: selected ? 0.95 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = ringWidth + (selected ? 8 : 1)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, selected ? 14 : 7);
      canvas.drawArc(ringRect, start, sweep, false, glowPaint);

      final segmentPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: selected ? 0.95 : 0.62),
            color.withValues(alpha: selected ? 0.65 : 0.20),
          ],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt
        ..strokeWidth = ringWidth;
      canvas.drawArc(ringRect, start, sweep, false, segmentPaint);

      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.6 : 1.2;
      canvas.drawArc(ringRect, start, sweep, false, borderPaint);

      final mid = start + sweep / 2;
      final iconRadius = outerRadius - ringWidth / 2;
      final iconCenter =
          center + Offset(math.cos(mid), math.sin(mid)) * iconRadius;
      final iconText = String.fromCharCode(car.icon.codePoint);
      final iconPainter = TextPainter(
        text: TextSpan(
          text: iconText,
          style: TextStyle(
            fontSize: selected
                ? size.shortestSide * 0.094
                : size.shortestSide * 0.078,
            fontFamily: car.icon.fontFamily,
            package: car.icon.fontPackage,
            color: Colors.white,
            shadows: [Shadow(color: color, blurRadius: 12)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        iconCenter - Offset(iconPainter.width / 2, iconPainter.height / 2),
      );
    }

    final hubRadius = size.shortestSide * 0.205;
    canvas.drawCircle(
      center,
      hubRadius + 5,
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1C1735), Color(0xFF070B14)],
        ).createShader(Rect.fromCircle(center: center, radius: hubRadius)),
    );
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..color = AppColors.purple.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final labelPainter = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size.shortestSide * (centerLabel.length > 3 ? 0.08 : 0.16),
          shadows: const [Shadow(color: AppColors.purple, blurRadius: 14)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: hubRadius * 1.55);
    labelPainter.paint(
      canvas,
      center - Offset(labelPainter.width / 2, labelPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CarWheelPainter oldDelegate) {
    return oldDelegate.highlightedCarId != highlightedCarId ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.enabled != enabled ||
        oldDelegate.cars != cars;
  }
}
