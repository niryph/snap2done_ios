import 'package:flutter/material.dart';
import '../models/expense_tracker_models.dart';
import '../../../services/expense_service.dart';
import '../widgets/daily_expense_tracker_card.dart';
import 'expense_tracker_setup_page.dart';

class ExpenseTrackerPage extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const ExpenseTrackerPage({
    super.key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  });

  @override
  State<ExpenseTrackerPage> createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final _expenseService = ExpenseService.instance;
  List<ExpenseEntry>? _expenses;
  ExpenseSettings? _settings;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  ExpenseViewType _viewType = ExpenseViewType.daily;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseTrackerSetupPage(
          isEditing: true,
          initialMetadata: _settings != null ? _settings!.toMap() : null,
          onSave: (metadata) async {
            // Convert metadata to ExpenseSettings
            final newSettings = ExpenseSettings.fromMap(metadata);
            await _handleUpdateSettings(newSettings);
            if (mounted) {
              setState(() {
                _settings = newSettings;
              });
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      DateTime startDate;
      DateTime endDate;

      // Calculate date range based on view type
      switch (_viewType) {
        case ExpenseViewType.daily:
          startDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
        case ExpenseViewType.weekly:
          // Start from Monday of the week
          startDate = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
          endDate = startDate.add(const Duration(days: 7));
          break;
        case ExpenseViewType.monthly:
          startDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
          endDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          break;
      }

      final results = await Future.wait([
        ExpenseService.instance.getExpenses(
          startDate: startDate,
          endDate: endDate,
        ),
        ExpenseService.instance.getExpenseSettings(),
      ]);

      if (!mounted) return;

      setState(() {
        _expenses = results[0] as List<ExpenseEntry>;
        _settings = results[1] as ExpenseSettings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleAddExpense(ExpenseEntry expense) async {
    try {
      final newExpense = await _expenseService.createExpense(expense);
      
      // After creating the expense, reload the data for the selected date
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final expenses = await _expenseService.getExpenses(
        startDate: startOfDay,
        endDate: endOfDay,
      );
      
      setState(() {
        _expenses = expenses;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to add expense: $e';
      });
    }
  }

  Future<void> _handleEditExpense(ExpenseEntry expense) async {
    try {
      final updatedExpense = await _expenseService.updateExpense(expense);
      
      // After editing the expense, reload the data for the selected date
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final expenses = await _expenseService.getExpenses(
        startDate: startOfDay,
        endDate: endOfDay,
      );
      
      setState(() {
        _expenses = expenses;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to update expense: $e';
      });
    }
  }

  Future<void> _handleDeleteExpense(String id) async {
    try {
      await _expenseService.deleteExpense(id);
      
      // After deleting the expense, reload the data for the selected date
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final expenses = await _expenseService.getExpenses(
        startDate: startOfDay,
        endDate: endOfDay,
      );
      
      setState(() {
        _expenses = expenses;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to delete expense: $e';
      });
    }
  }

  Future<void> _handleUpdateSettings(ExpenseSettings settings) async {
    try {
      final updatedSettings = await _expenseService.updateExpenseSettings(settings);
      setState(() {
        _settings = updatedSettings;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to update settings: $e';
      });
    }
  }

  void _onDateChange(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadData();
  }

  void _onViewTypeChange(ExpenseViewType viewType) {
    setState(() {
      _viewType = viewType;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _settings == null ? null : _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_settings == null) {
      return const Center(
        child: Text('No settings found. Please configure your expense settings.'),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: DailyExpenseTrackerCard(
          expenses: _expenses!,
          settings: _settings!,
          onAddExpense: _handleAddExpense,
          onEditExpense: _handleEditExpense,
          onDeleteExpense: _handleDeleteExpense,
          onUpdateSettings: _handleUpdateSettings,
          onDateChange: _onDateChange,
          onViewTypeChange: _onViewTypeChange,
          selectedDate: _selectedDate,
          viewType: _viewType,
        ),
      ),
    );
  }
} 