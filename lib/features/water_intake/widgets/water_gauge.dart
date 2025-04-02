import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaterGauge extends StatelessWidget {
  final double currentAmount;
  final double dailyGoal;

  const WaterGauge({
    Key? key,
    required this.currentAmount,
    required this.dailyGoal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (currentAmount / dailyGoal).clamp(0.0, 1.0);

    return CustomPaint(
      painter: _WaterGaugePainter(
        percentage: percentage,
        backgroundColor: const Color(0xFFE3F2FD),
        progressColor: const Color(0xFF4C6FFF),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentAmount.round().toString(),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            Text(
              'of ${dailyGoal.round()} fl oz',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF9A9CAA),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(percentage * 100).round()}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4C6FFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterGaugePainter extends CustomPainter {
  final double percentage;
  final Color backgroundColor;
  final Color progressColor;

  _WaterGaugePainter({
    required this.percentage,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.4;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * percentage;

    // Draw background arc
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi,
      false,
      backgroundPaint,
    );

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_WaterGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor;
  }
} 