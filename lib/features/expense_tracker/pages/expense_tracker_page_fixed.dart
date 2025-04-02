import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/expense_tracker_models.dart';
import '../../../services/card_service.dart';
import '../widgets/expense_category_chart.dart';
import '../widgets/expense_entry_item.dart';

class ExpenseTrackerPage extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onUpdate;

  const ExpenseTrackerPage({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<ExpenseTrackerPage> createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final _uuid = Uuid();
  bool _isLoading = false;
  List<ExpenseEntry> _expenses = [];
  double _dailyBudget = 100.0;
  double _totalSpent = 0.0;
  
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'Food';
  
  @override
  void initState() {
    super.initState();
    _loadExpenseData();
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  void _loadExpenseData() {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load budget
      _dailyBudget = widget.metadata['dailyBudget'] ?? 100.0;
      
      // Load expenses
      final expensesData = widget.metadata['expenses'] as List<dynamic>? ?? [];
      _expenses = expensesData.map((e) => ExpenseEntry.fromMap(e as Map<String, dynamic>)).toList();
      
      // Calculate total spent
      _totalSpent = _expenses.fold(0, (sum, expense) => sum + expense.amount);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading expense data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _addExpense() async {
    // Validate amount
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount')),
      );
      return;
    }
    
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    
    // Validate description
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create new expense entry
      final newExpense = ExpenseEntry(
        id: _uuid.v4(),
        amount: amount,
        category: _selectedCategory,
        description: description,
        timestamp: DateTime.now(),
      );
      
      // Add to local list
      setState(() {
        _expenses.add(newExpense);
        _totalSpent += amount;
      });
      
      // Update metadata
      final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
      updatedMetadata['expenses'] = _expenses.map((e) => e.toMap()).toList();
      
      // Save to database
      await CardService.updateCardMetadata(widget.cardId, updatedMetadata);
      
      // Notify parent
      widget.onUpdate(updatedMetadata);
      
      // Clear form
      _amountController.clear();
      _descriptionController.clear();
      
      // Close bottom sheet if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding expense: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _deleteExpense(String id) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Find expense
      final expense = _expenses.firstWhere((e) => e.id == id);
      
      // Remove from local list
      setState(() {
        _expenses.removeWhere((e) => e.id == id);
        _totalSpent -= expense.amount;
      });
      
      // Update metadata
      final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
      updatedMetadata['expenses'] = _expenses.map((e) => e.toMap()).toList();
      
      // Save to database
      await CardService.updateCardMetadata(widget.cardId, updatedMetadata);
      
      // Notify parent
      widget.onUpdate(updatedMetadata);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting expense: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ExpenseCategories.categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.name,
                    child: Row(
                      children: [
                        Icon(category.icon, color: category.color, size: 20),
                        const SizedBox(width: 8),
                        Text(category.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addExpense,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Add Expense'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  void _showSnapReceiptSheet() {
    // This would be implemented with camera integration and OCR
    // For now, just show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt scanning coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings page
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Header
                    Card(
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
                                Row(
                                  children: [
                                    Text(
                                      '\$${_totalSpent.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _totalSpent > _dailyBudget
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    Text(
                                      ' / \$${_dailyBudget.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _totalSpent / _dailyBudget,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _totalSpent > _dailyBudget ? Colors.red : Colors.green,
                              ),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Expense'),
                            onPressed: _showAddExpenseSheet,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Snap Receipt'),
                            onPressed: _showSnapReceiptSheet,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Category Breakdown
                    if (_expenses.isNotEmpty) ...[
                      Text(
                        'Spending by Category',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ExpenseCategoryChart(expenses: _expenses),
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                    
                    // Expense List
                    Text(
                      'Recent Expenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _expenses.isEmpty
                        ? const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No expenses recorded yet. Add your first expense!',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _expenses.length,
                            itemBuilder: (context, index) {
                              final expense = _expenses[_expenses.length - 1 - index];
                              return ExpenseEntryItem(
                                expense: expense,
                                onDelete: () => _deleteExpense(expense.id),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSnapReceiptSheet,
        child: const Icon(Icons.camera_alt),
        tooltip: 'Snap Receipt',
      ),
    );
  }
}