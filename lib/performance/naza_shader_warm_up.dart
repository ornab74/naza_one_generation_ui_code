import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Compiles the small set of solid Skia primitives used by the shell before
/// the first interactive frame. This avoids a one-time shader compile while a
/// boot animation or first tap is already consuming the frame budget.
final class NazaShaderWarmUp extends ShaderWarmUp {
  const NazaShaderWarmUp();

  @override
  ui.Size get size => const ui.Size(128, 128);

  @override
  Future<void> warmUpOnCanvas(ui.Canvas canvas) async {
    final solid = ui.Paint()..color = const ui.Color(0xFF183B2D);
    final translucent = ui.Paint()..color = const ui.Color(0x668DFFC4);
    final stroke = ui.Paint()
      ..color = const ui.Color(0xFF8DFFC4)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawColor(const ui.Color(0xFF020806), ui.BlendMode.srcOver);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 128, 128), solid);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(8, 8, 112, 48),
        const ui.Radius.circular(18),
      ),
      translucent,
    );
    final card = ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(6, 6, 116, 52),
      const ui.Radius.circular(22),
    );
    canvas.drawRRect(card, stroke);
    canvas.drawDRRect(
      card,
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(8, 8, 112, 48),
        const ui.Radius.circular(20),
      ),
      translucent,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(12, 12, 104, 32),
        const ui.Radius.circular(999),
      ),
      stroke,
    );
    canvas.drawCircle(const ui.Offset(64, 88), 22, solid);
    canvas.drawCircle(const ui.Offset(64, 88), 24, stroke);
    canvas.drawArc(
      const ui.Rect.fromLTWH(36, 60, 56, 56),
      -math.pi / 2,
      math.pi * 1.35,
      false,
      stroke,
    );
    canvas.drawLine(
      const ui.Offset(16, 120),
      const ui.Offset(112, 120),
      stroke,
    );

    // Boot cards use clipped rounded surfaces and text before the steady
    // state shell is visible. Exercise both paths while the engine is still
    // warming up, rather than on the first user-visible frame.
    canvas.save();
    canvas.clipRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(12, 12, 104, 32),
        const ui.Radius.circular(12),
      ),
    );
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 128, 128), translucent);
    canvas.restore();

    for (final (text, fontFamily, offset) in <(String, String, ui.Offset)>[
      ('Naza One', 'Inter', const ui.Offset(8, 4)),
      ('ready', 'JetBrainsMono', const ui.Offset(8, 28)),
    ]) {
      final label = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: const ui.Color(0xFFE9FFF2),
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 112);
      label.paint(canvas, offset);
    }

    // The shell uses rounded Material icons in the top bar and navigation
    // rail. Warm the icon font separately from the app text fonts.
    final icon = Icons.spa_rounded;
    final iconLabel = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: const ui.Color(0xFFE9FFF2),
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 22,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconLabel.paint(canvas, const ui.Offset(100, 4));
  }
}
