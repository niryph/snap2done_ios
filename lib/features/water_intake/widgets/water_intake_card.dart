import 'package:flutter/material.dart';
import '../models/water_intake_models.dart';
import '../pages/water_intake_page.dart';
import '../../../utils/background_patterns.dart';
import './water_gauge.dart';
import 'package:intl/intl.dart';
import '../utils/unit_converter.dart';

class WaterIntakeCard extends StatelessWidget {
  final String cardId;
  final WaterIntakeMetadata? metadata;
  final VoidCallback onTapSettings;

  const WaterIntakeCard({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onTapSettings,
  }) : super(key: key);

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  double _calculateCurrentAmount() {
    if (metadata == null) return 0.0;
    
    final today = DateTime.now();
    final dateKey = _dateToKey(today);
    
    // Check if dailyEntries contains entries for today
    if (!metadata!.dailyEntries.containsKey(dateKey)) return 0.0;
    
    final entries = metadata!.dailyEntries[dateKey]!;
    
    // Sum up all entries for today
    double totalAmount = 0.0;
    for (final entry in entries) {
      try {
        if (entry is WaterEntry) {
          totalAmount += entry.amount;
        } else if (entry is Map<String, dynamic>) {
          // Explicitly cast to Map to avoid type errors
          final entryMap = entry as Map<String, dynamic>;
          if (entryMap.containsKey('amount')) {
            totalAmount += (entryMap['amount'] as num).toDouble();
          }
        } else {
          // Handle dynamic object using reflection safely
          dynamic amountValue;
          try {
            amountValue = entry.amount;
            if (amountValue is num) {
              totalAmount += amountValue.toDouble();
            }
          } catch (_) {
            // Cannot access amount property
          }
        }
      } catch (e) {
        // Skip this entry if any error occurs
      }
    }
    
    return totalAmount;
  }

  String _getUnitLabel() {
    if (metadata == null) return 'fl oz';
    return metadata!.unitType == UnitType.fluidOunce ? 'fl oz' : 'ml';
  }

  @override
  Widget build(BuildContext context) {
    if (metadata == null) {
      return _buildEmptyCard();
    }

    final currentAmount = _calculateCurrentAmount();
    final dailyGoal = metadata!.dailyGoal;
    final percentage = (currentAmount / dailyGoal * 100).clamp(0, 100).round();
    final unitLabel = _getUnitLabel();
    final amountLeft = dailyGoal - currentAmount > 0 ? dailyGoal - currentAmount : 0;

    return GestureDetector(
      onTap: onTapSettings,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: const Color(0xFFF8FAFF),
        child: Stack(
          children: [
            // Background with subtle water bubbles
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: WaterBubblePattern(),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Left side with water icon and progress
                  Expanded(
                    child: Row(
                      children: [
                        // Water drop icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.water_drop,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Current/total amount and percentage
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${currentAmount.toStringAsFixed(0)} / ${dailyGoal.toStringAsFixed(0)} $unitLabel',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D3142),
                              ),
                            ),
                            Text(
                              '$percentage% complete',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Right side - amount left
                  Text(
                    '${amountLeft.toStringAsFixed(0)} $unitLabel left',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3142),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return GestureDetector(
      onTap: onTapSettings,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: const Color(0xFFF8FAFF),
        child: Stack(
          children: [
            // Background with subtle water bubbles
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: WaterBubblePattern(),
                ),
              ),
            ),
            // Onboarding content
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Tap to set up your hydration tracking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D3142),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for water bubble background
class WaterBubblePattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C5CE7).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Create bubbles at different positions
    _drawBubble(canvas, paint, Offset(size.width * 0.1, size.height * 0.2), size.width * 0.05);
    _drawBubble(canvas, paint, Offset(size.width * 0.3, size.height * 0.6), size.width * 0.08);
    _drawBubble(canvas, paint, Offset(size.width * 0.6, size.height * 0.3), size.width * 0.07);
    _drawBubble(canvas, paint, Offset(size.width * 0.8, size.height * 0.7), size.width * 0.06);
    _drawBubble(canvas, paint, Offset(size.width * 0.9, size.height * 0.4), size.width * 0.04);
  }

  void _drawBubble(Canvas canvas, Paint paint, Offset center, double radius) {
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 