import 'package:flutter/material.dart';
import 'dart:math';

class CalorieProgressCircle extends StatelessWidget {
  final double progress;
  final double total;
  final double current;
  final double size;

  const CalorieProgressCircle({
    Key? key,
    required this.progress,
    required this.total,
    required this.current,
    this.size = 120, // Default size, but can be overridden
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the inner circle size to ensure text fits inside
    final innerSize = size * 0.75;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: size * 0.06, // Scale stroke width with size
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade300),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: size * 0.06, // Scale stroke width with size
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progress)),
            ),
          ),
          // Center text - contained in a constrained box to ensure it stays inside the circle
          Container(
            width: innerSize,
            height: innerSize,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${current.toInt()} / ${total.toInt()}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.14, // Scale font size with circle size
                        ),
                  ),
                  SizedBox(height: size * 0.02), // Scale spacing with size
                  Text(
                    'kcal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: size * 0.08, // Scale font size with circle size
                        ),
                  ),
                  SizedBox(height: size * 0.03), // Scale spacing with size
                  Text(
                    _getRemainingText(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getProgressColor(progress),
                          fontWeight: FontWeight.bold,
                          fontSize: size * 0.09, // Scale font size with circle size
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) {
      return Colors.green;
    } else if (progress < 0.75) {
      return Colors.orange;
    } else if (progress < 1.0) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  String _getRemainingText() {
    final remaining = total - current;
    if (remaining > 0) {
      return '${remaining.toInt()} kcal left';
    } else if (remaining == 0) {
      return 'Goal reached!';
    } else {
      return '${(-remaining).toInt()} kcal over';
    }
  }
} 