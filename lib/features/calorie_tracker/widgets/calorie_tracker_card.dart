import 'package:flutter/material.dart';
import '../models/calorie_tracker_models.dart';
import 'calorie_progress_circle.dart';

class CalorieTrackerCard extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic>? metadata;
  final VoidCallback onTapSettings;

  const CalorieTrackerCard({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onTapSettings,
  }) : super(key: key);

  @override
  State<CalorieTrackerCard> createState() => _CalorieTrackerCardState();
}

class _CalorieTrackerCardState extends State<CalorieTrackerCard> {
  late DateTime _selectedDate;
  late List<Map<String, dynamic>> _currentDayEntries;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadEntriesForSelectedDate();
  }

  void _loadEntriesForSelectedDate() {
    final dateKey = _dateToKey(_selectedDate);
    _currentDayEntries = List<Map<String, dynamic>>.from(
      widget.metadata?['dailyEntries']?[dateKey] ?? []
    );
    setState(() {});
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  double get _totalCalories {
    return _currentDayEntries.fold(0.0, (sum, entry) => sum + (entry['calories'] as num));
  }

  double get _progressPercentage {
    final goal = widget.metadata?['dailyGoal'] ?? 2000.0;
    return (_totalCalories / goal).clamp(0.0, 1.0);
  }

  // Calculate macronutrient totals
  Map<String, double> get _macroTotals {
    double totalCarbs = 0.0;
    double totalProtein = 0.0;
    double totalFat = 0.0;
    
    for (var entry in _currentDayEntries) {
      totalCarbs += entry['carbs'] as double;
      totalProtein += entry['protein'] as double;
      totalFat += entry['fat'] as double;
    }
    
    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'fat': totalFat,
    };
  }

  // Calculate macronutrient percentages
  Map<String, double> get _macroPercentages {
    final totals = _macroTotals;
    final totalGrams = totals['carbs']! + totals['protein']! + totals['fat']!;
    
    if (totalGrams == 0) {
      return {
        'carbs': 0.0,
        'protein': 0.0,
        'fat': 0.0,
      };
    }
    
    return {
      'carbs': (totals['carbs']! / totalGrams * 100).roundToDouble(),
      'protein': (totals['protein']! / totalGrams * 100).roundToDouble(),
      'fat': (totals['fat']! / totalGrams * 100).roundToDouble(),
    };
  }

  void _navigateDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (!newDate.isAfter(DateTime.now())) {
      setState(() {
        _selectedDate = newDate;
        _loadEntriesForSelectedDate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metadata == null) {
      return Card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tap to set up your calorie tracking',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _navigateDate(-1),
                ),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                        _loadEntriesForSelectedDate();
                      });
                    }
                  },
                  child: Row(
                    children: [
                      Text(
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _selectedDate.day == DateTime.now().day ? null : () => _navigateDate(1),
                ),
              ],
            ),
            
            // Calorie Progress Circle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Center(
                child: CalorieProgressCircle(
                  progress: _progressPercentage,
                  total: widget.metadata!['dailyGoal'],
                  current: _totalCalories,
                ),
              ),
            ),

            // Macronutrient Breakdown
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Macronutrients',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _buildMacroIndicator(
                        context, 
                        'Carbs', 
                        _macroPercentages['carbs']!, 
                        Colors.green
                      ),
                      _buildMacroIndicator(
                        context, 
                        'Protein', 
                        _macroPercentages['protein']!, 
                        Colors.blue
                      ),
                      _buildMacroIndicator(
                        context, 
                        'Fat', 
                        _macroPercentages['fat']!, 
                        Colors.orange
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Recent Entries
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s Food Log',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Food', style: TextStyle(fontSize: 10)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: widget.onTapSettings,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: _currentDayEntries.isEmpty
                        ? Center(
                            child: Text(
                              'No entries yet for today',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _currentDayEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _currentDayEntries[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                minLeadingWidth: 20,
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: _getMealTypeColor(entry['mealType']),
                                  child: Icon(
                                    _getMealTypeIcon(entry['mealType']),
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                                title: Text(
                                  entry['food'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                                subtitle: Text(
                                  'C: ${entry['carbs']}g | P: ${entry['protein']}g | F: ${entry['fat']}g',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                trailing: Text(
                                  '${entry['calories']} kcal',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
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

  Widget _buildMacroIndicator(
    BuildContext context, 
    String label, 
    double percentage, 
    Color color
  ) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${percentage.toInt()}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Color _getMealTypeColor(String? mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Colors.orange;
      case 'Lunch':
        return Colors.green;
      case 'Dinner':
        return Colors.blue;
      case 'Snack':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String? mealType) {
    switch (mealType) {
      case 'Breakfast':
        return Icons.breakfast_dining;
      case 'Lunch':
        return Icons.lunch_dining;
      case 'Dinner':
        return Icons.dinner_dining;
      case 'Snack':
        return Icons.cookie;
      default:
        return Icons.food_bank;
    }
  }
}
