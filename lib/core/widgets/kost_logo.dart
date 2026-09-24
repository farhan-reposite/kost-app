import 'package:flutter/material.dart';

/// The app's mark: a simple key in a rounded badge. Used in the main tab
/// app bars for a bit of brand identity; colors default to the current
/// theme so it adapts automatically between light and dark mode.
///
/// This is the in-app twin of assets/icon/icon.png (the launcher icon) -
/// same shape, drawn as a vector so it stays crisp at any size.
class KostLogo extends StatelessWidget {
  const KostLogo({super.key, this.size = 32, this.background, this.foreground});

  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _KostLogoPainter(
        background: background ?? scheme.primary,
        foreground: foreground ?? scheme.onPrimary,
      ),
    );
  }
}

class _KostLogoPainter extends CustomPainter {
  _KostLogoPainter({required this.background, required this.foreground});
  final Color background;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // Badge
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.28),
    );
    canvas.drawRRect(rrect, Paint()..color = background);

    // Key bow (a ring)
    final bowCenter = Offset(s * 0.40, s * 0.40);
    final bowOuterR = s * 0.185;
    final bowInnerR = s * 0.095;
    canvas.drawCircle(bowCenter, bowOuterR, Paint()..color = foreground);
    canvas.drawCircle(bowCenter, bowInnerR, Paint()..color = background);

    // Shaft
    final shaftPaint = Paint()
      ..color = foreground
      ..strokeWidth = s * 0.105
      ..strokeCap = StrokeCap.round;
    final shaftStart = bowCenter + Offset(bowOuterR, bowOuterR) * 0.55;
    final shaftEnd = Offset(s * 0.76, s * 0.76);
    canvas.drawLine(shaftStart, shaftEnd, shaftPaint);

    // Teeth
    final dir = shaftEnd - shaftStart;
    final unit = dir / dir.distance;
    final perp = Offset(-unit.dy, unit.dx);
    void tooth(double t, double length) {
      final base = shaftStart + unit * (dir.distance * t);
      final tip = base + perp * length;
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..color = foreground
          ..strokeWidth = s * 0.085
          ..strokeCap = StrokeCap.round,
      );
    }

    tooth(0.70, s * 0.095);
    tooth(0.90, s * 0.135);
  }

  @override
  bool shouldRepaint(covariant _KostLogoPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.foreground != foreground;
}
