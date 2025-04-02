import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class CalorieGraphPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> data;
  final double maxValue;
  final bool isWeekly;
  final Color barColor;
  final Color targetLineColor;
  final String label;

  CalorieGraphPainter({
    required this.data,
    required this.maxValue,
    required this.isWeekly,
    required this.barColor,
    required this.targetLineColor,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = barColor;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = targetLineColor
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Calculate bar width and spacing
    final barCount = data.length;
    final totalSpacing = (barCount + 1) * 8.0;
    final barWidth = (size.width - totalSpacing) / barCount;

    // Draw target line
    final targetY = size.height - (size.height * (maxValue / maxValue));
    canvas.drawLine(
      Offset(0, targetY),
      Offset(size.width, targetY),
      linePaint,
    );

    // Draw bars and labels
    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      final x = 8.0 + i * (barWidth + 8.0);
      final barHeight = size.height * (entry.value / maxValue);
      final y = size.height - barHeight;

      // Draw bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );

      // Draw date label
      final dateText = isWeekly
          ? '${entry.key.day}/${entry.key.month}'
          : '${entry.key.hour}:00';
      textPainter.text = TextSpan(
        text: dateText,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x + (barWidth - textPainter.width) / 2,
          size.height + 4,
        ),
      );

      // Draw value label if bar is tall enough
      if (barHeight > 25) {
        final valueText = entry.value.toStringAsFixed(
          label.toLowerCase() == 'calories' ? 0 : 1,
        );
        textPainter.text = TextSpan(
          text: valueText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x + (barWidth - textPainter.width) / 2,
            y + (barHeight - textPainter.height) / 2,
          ),
        );
      }
    }

    // Draw Y-axis labels
    final yLabels = [0, maxValue / 2, maxValue];
    for (var value in yLabels) {
      final y = size.height - (size.height * (value / maxValue));
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(
          label.toLowerCase() == 'calories' ? 0 : 1,
        ) + (label.toLowerCase() == 'calories' ? '' : 'g'),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 10,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-4, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 