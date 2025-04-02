import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/expense_tracker_models.dart';
import '../../../services/expense_service.dart';
import 'expense_category_chart.dart';
import 'expense_entry_item.dart';
import 'package:uuid/uuid.dart';
import '../../../services/card_service.dart';

class DailyExpenseTrackerCardContent extends StatefulWidget {
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

  const DailyExpenseTrackerCardContent({
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
  State<DailyExpenseTrackerCardContent> createState() => _DailyExpenseTrackerCardContentState();
}

class _DailyExpenseTrackerCardContentState extends State<DailyExpenseTrackerCardContent> {
  late List<ExpenseEntry> _expenses;
  late ExpenseSettings _settings;
  late double _totalSpent;
  bool _isLoading = false;
  late DateTime _selectedDate;
  late ExpenseViewType _viewType;

  @override
  void initState() {
    super.initState();
    _expenses = widget.expenses;
    _settings = widget.settings;
    _selectedDate = widget.selectedDate;
    _viewType = widget.viewType;
    _calculateTotalSpent();
  }

  @override
  void didUpdateWidget(DailyExpenseTrackerCardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expenses != oldWidget.expenses) {
      setState(() {
        _expenses = widget.expenses;
        _calculateTotalSpent();
      });
    }
    if (widget.settings != oldWidget.settings) {
      setState(() {
        _settings = widget.settings;
      });
    }
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() {
        _selectedDate = widget.selectedDate;
      });
    }
    if (widget.viewType != oldWidget.viewType) {
      setState(() {
        _viewType = widget.viewType;
      });
    }
  }

  void _calculateTotalSpent() {
    _totalSpent = _expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  void _showAddExpenseSheet() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = ExpenseCategories.categories.first.name;
    
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add New Expense',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: _settings.currency,
                    helperText: 'Maximum amount: 100,000.00',
                    errorStyle: const TextStyle(color: Colors.red),
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      // Only allow numbers and one decimal point
                      final text = newValue.text;
                      
                      // Check if the text matches our desired format
                      if (text.isEmpty) return newValue;
                      
                      // Handle decimal numbers
                      if (text.contains('.')) {
                        // Split by decimal point
                        final parts = text.split('.');
                        // Only allow one decimal point
                        if (parts.length > 2) return oldValue;
                        // Limit decimal places to 2
                        if (parts[1].length > 2) return oldValue;
                        // Limit whole number part to 6 digits (for 100,000 max)
                        if (parts[0].length > 6) return oldValue;
                        // Check if the number would exceed 100,000
                        final number = double.tryParse(text);
                        if (number != null && number > 100000) return oldValue;
                      } else {
                        // For whole numbers, limit to 6 digits
                        if (text.length > 6) return oldValue;
                        // Check if the number would exceed 100,000
                        final number = double.tryParse(text);
                        if (number != null && number > 100000) return oldValue;
                      }
                      
                      // Only allow digits and decimal point
                      if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;
                      
                      return newValue;
                    }),
                  ],
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      final amount = double.tryParse(value);
                      if (amount != null && amount > 100000) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Amount cannot exceed 100,000'),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.red,
        ),
      );
    }
  }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null) {
                      return 'Please enter a valid number';
                    }
                    if (amount <= 0) {
                      return 'Amount must be greater than 0';
                    }
                    if (amount > 100000) {
                      return 'Amount must be less than 100,000';
                    }
                    return null;
                  },
                    ),
                    const SizedBox(height: 16),
                TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                  items: ExpenseCategories.categories
                      .map((category) => DropdownMenuItem(
                          value: category.name,
                          child: Row(
                            children: [
                                Icon(
                                  category.icon,
                                  size: 16,
                                  color: category.color,
                                ),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                          ))
                      .toList(),
                      onChanged: (value) {
                    if (value != null) {
                      selectedCategory = value;
                    }
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newExpense = ExpenseEntry(
                        id: const Uuid().v4(),
                        amount: double.parse(amountController.text),
                        description: descriptionController.text,
                        category: selectedCategory,
                        timestamp: selectedDateTime,
                      );
                      
                      Navigator.pop(context);
                      
                      // Add the expense through the parent widget
                      await widget.onAddExpense(newExpense);
                      
                      // Don't refresh here - let the parent widget handle it through didUpdateWidget
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Add Expense'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnapReceiptSheet() {
    // Implementation for showing snap receipt sheet
  }

  String _getDateRangeText() {
    final dateFormat = DateFormat('MMM d, y');
    final monthFormat = DateFormat('MMMM y');
    
    switch (_viewType) {
      case ExpenseViewType.daily:
        return dateFormat.format(_selectedDate);
      case ExpenseViewType.weekly:
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(startOfWeek)} - ${dateFormat.format(endOfWeek)}';
      case ExpenseViewType.monthly:
        return monthFormat.format(_selectedDate);
    }
  }

  void _onPreviousDate() {
    DateTime newDate;
    switch (_viewType) {
      case ExpenseViewType.daily:
        newDate = _selectedDate.subtract(const Duration(days: 1));
        break;
      case ExpenseViewType.weekly:
        newDate = _selectedDate.subtract(const Duration(days: 7));
        break;
      case ExpenseViewType.monthly:
        newDate = DateTime(_selectedDate.year, _selectedDate.month - 1, _selectedDate.day);
        break;
    }
    setState(() {
      _selectedDate = newDate;
      _isLoading = true;
    });
    widget.onDateChange(newDate);
  }

  void _onNextDate() {
    DateTime newDate;
    switch (_viewType) {
      case ExpenseViewType.daily:
        newDate = _selectedDate.add(const Duration(days: 1));
        break;
      case ExpenseViewType.weekly:
        newDate = _selectedDate.add(const Duration(days: 7));
        break;
      case ExpenseViewType.monthly:
        newDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
        break;
    }
    setState(() {
      _selectedDate = newDate;
      _isLoading = true;
    });
    widget.onDateChange(newDate);
  }

  void _onViewTypeChanged(Set<ExpenseViewType> selected) {
    final newViewType = selected.first;
    if (newViewType != _viewType) {
      widget.onViewTypeChange(newViewType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Budget Header and Progress
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Budget',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${_settings.currency}${_totalSpent.toStringAsFixed(2)} / ${_settings.currency}${_settings.dailyBudget.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _totalSpent > _settings.dailyBudget ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _settings.dailyBudget > 0 ? (_totalSpent / _settings.dailyBudget).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _totalSpent > _settings.dailyBudget ? Colors.red : Colors.green,
                    ),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Calendar Navigation
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _onPreviousDate,
                  ),
                  Text(
                    _getDateRangeText(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _onNextDate,
                  ),
                ],
              ),
              if (_expenses.isNotEmpty) ...[
                const SizedBox(height: 8),
                SegmentedButton<ExpenseViewType>(
                  segments: ExpenseViewType.values.map((type) => 
                    ButtonSegment<ExpenseViewType>(
                      value: type,
                      label: Text(type.label),
                    )
                  ).toList(),
                  selected: {_viewType},
                  onSelectionChanged: _onViewTypeChanged,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Expense Chart
          if (_expenses.isNotEmpty) ...[
            SizedBox(
              height: 200,
              child: ExpenseCategoryChart(
                expenses: _expenses,
                currency: _settings.currency,
                viewType: _viewType,
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Action Buttons
          Row(
                            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddExpenseSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSnapReceiptSheet,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Snap Receipt'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Expense List
          if (_expenses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No expenses recorded for ${_viewType.label.toLowerCase()}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _expenses.length,
                itemBuilder: (context, index) {
                  final expense = _expenses[index];
                  return ExpenseEntryItem(
                    expense: expense,
                    onEdit: widget.onEditExpense,
                    onDelete: () => widget.onDeleteExpense(expense.id),
                    currency: _settings.currency,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
} 