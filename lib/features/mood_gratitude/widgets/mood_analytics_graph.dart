import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/mood_gratitude_models.dart';

class MoodAnalyticsGraph extends StatelessWidget {
  final List<MoodEntry> entries;
  final String timeRange; // 'week', 'month', 'year'

  const MoodAnalyticsGraph({
    Key? key,
    required this.entries,
    this.timeRange = 'week',
  }) : super(key: key);

  List<MoodEntry> _getFilteredEntries() {
    final now = DateTime.now();
    final DateTime startDate;
    
    switch (timeRange) {
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
    }

    return entries
        .where((entry) => entry.date.isAfter(startDate) || entry.date.isAtSameMomentAs(startDate))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  double _getMoodValue(String mood) {
    switch (mood) {
      case 'Happy': return 5;
      case 'Good': return 4;
      case 'Neutral': return 3;
      case 'Sad': return 2;
      case 'Angry': return 1;
      default: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredEntries = _getFilteredEntries();
    if (filteredEntries.isEmpty) {
      return const Center(
        child: Text('No data available for the selected time range'),
      );
    }

    final spots = filteredEntries.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        _getMoodValue(entry.value.mood),
      );
    }).toList();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mood Trends - Last ${timeRange[0].toUpperCase()}${timeRange.substring(1)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          String mood = '';
                          switch (value.toInt()) {
                            case 5: mood = '😊';
                            case 4: mood = '🙂';
                            case 3: mood = '😐';
                            case 2: mood = '😔';
                            case 1: mood = '😡';
                          }
                          return Text(mood);
                        },
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= filteredEntries.length) return const Text('');
                          final date = filteredEntries[value.toInt()].date;
                          return Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 25,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: (filteredEntries.length - 1).toDouble(),
                  minY: 0,
                  maxY: 6,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 