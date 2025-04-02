import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense_tracker_models.dart';

class ExpenseCategoryChart extends StatelessWidget {
  final List<ExpenseEntry> expenses;
  final String currency;
  final ExpenseViewType viewType;

  const ExpenseCategoryChart({
    Key? key,
    required this.expenses,
    required this.currency,
    required this.viewType,
  }) : super(key: key);

  String get _chartTitle {
    switch (viewType) {
      case ExpenseViewType.daily:
        return 'Today\'s Expenses';
      case ExpenseViewType.weekly:
        return 'Weekly Expenses';
      case ExpenseViewType.monthly:
        return 'Monthly Expenses';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate category totals
    final Map<String, double> categoryTotals = {};
    double totalAmount = 0;
    
    for (final expense in expenses) {
      categoryTotals[expense.category] = (categoryTotals[expense.category] ?? 0) + expense.amount;
      totalAmount += expense.amount;
    }
    
    // Sort categories by amount (descending)
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Create pie chart sections
    final sections = <PieChartSectionData>[];
    
    for (int i = 0; i < sortedCategories.length; i++) {
      final entry = sortedCategories[i];
      final category = ExpenseCategories.getCategoryByName(entry.key);
      final percentage = (entry.value / totalAmount) * 100;
      
      sections.add(
        PieChartSectionData(
          color: category.color.withOpacity(0.8),
          value: entry.value,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    return Column(
      children: [
        Text(
          _chartTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              // Pie Chart
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        // Handle touch events if needed
                      },
                    ),
                  ),
                ),
              ),
              
              // Legend
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedCategories.map((entry) {
                    final category = ExpenseCategories.getCategoryByName(entry.key);
                    final percentage = (entry.value / totalAmount) * 100;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: category.color.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$currency${entry.value.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 