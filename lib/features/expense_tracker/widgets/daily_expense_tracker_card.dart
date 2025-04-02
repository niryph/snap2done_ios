import 'package:flutter/material.dart';
import '../models/expense_tracker_models.dart';
import 'daily_expense_tracker_card_content.dart';

class DailyExpenseTrackerCard extends StatelessWidget {
  final List<ExpenseEntry> expenses;
  final ExpenseSettings settings;
  final Function(ExpenseEntry) onAddExpense;
  final Function(ExpenseEntry) onEditExpense;
  final Function(String) onDeleteExpense;
  final Function(ExpenseSettings) onUpdateSettings;
  final Function(DateTime) onDateChange;
  final Function(ExpenseViewType) onViewTypeChange;
  final DateTime selectedDate;
  final ExpenseViewType viewType;

  const DailyExpenseTrackerCard({
    super.key,
    required this.expenses,
    required this.settings,
    required this.onAddExpense,
    required this.onEditExpense,
    required this.onDeleteExpense,
    required this.onUpdateSettings,
    required this.onDateChange,
    required this.onViewTypeChange,
    required this.selectedDate,
    required this.viewType,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DailyExpenseTrackerCardContent(
        expenses: expenses,
        settings: settings,
        onAddExpense: onAddExpense,
        onEditExpense: onEditExpense,
        onDeleteExpense: onDeleteExpense,
        onUpdateSettings: onUpdateSettings,
        onDateChange: onDateChange,
        onViewTypeChange: onViewTypeChange,
        selectedDate: selectedDate,
        viewType: viewType,
      ),
    );
  }
} 