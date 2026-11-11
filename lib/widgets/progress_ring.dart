import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// İlerleme halkası: `border` renkli tam daire üstünde `accent` yay; `progress`'i tween'siz çizer.
class ProgressRing extends StatelessWidget {
  const ProgressRing({required this.progress, required this.size, super.key});

  /// 0..1; dışı kırpılır.
  final double progress;

  /// Halkanın çapı (kenar kalınlığı dahil), ölçekli px.
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(
        progress: progress.clamp(0.0, 1.0),
        trackColor: AppColors.border,
        arcColor: context.accent,
        strokeWidth: AppSizes.ringStroke,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Kenar çizgisi kutunun içinde kalsın diye yarıçaptan yarım kalınlık düşülür.
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawOval(rect, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
