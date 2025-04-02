import 'package:flutter/material.dart';
import '../models/expense_tracker_models.dart';
import '../../../services/card_service.dart';
import '../../../services/expense_service.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/theme_provider.dart';

class ExpenseTrackerSetupPage extends StatefulWidget {
  final bool isEditing;
  final String? cardId;
  final Map<String, dynamic>? initialMetadata;
  final Function(Map<String, dynamic>)? onSave;

  const ExpenseTrackerSetupPage({
    Key? key, 
    this.isEditing = false,
    this.cardId,
    this.initialMetadata,
    this.onSave,
  }) : super(key: key);

  @override
  State<ExpenseTrackerSetupPage> createState() => _ExpenseTrackerSetupPageState();
}

class _ExpenseTrackerSetupPageState extends State<ExpenseTrackerSetupPage> {
  final TextEditingController _dailyBudgetController = TextEditingController(text: '100');
  bool _enableReminders = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _isCreating = false;
  final _uuid = Uuid();
  
  // Add missing variables
  String _selectedCurrency = 'USD';
  List<String> _selectedCategories = ['Food', 'Transport', 'Entertainment', 'Bills', 'Shopping', 'Other'];
  
  // Background widget with programmatically generated pattern
  Widget get backgroundWidget {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    return Container(
      color: themeProvider.isDarkMode ? Color(0xFF1E1E2E) : Colors.transparent,
      child: themeProvider.isDarkMode
          ? BackgroundPatterns.darkThemeBackground()
          : BackgroundPatterns.lightThemeBackground(),
    );
  }
  
  // Getter for daily budget
  double get _dailyBudget {
    return double.tryParse(_dailyBudgetController.text) ?? 0.0;
  }
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with existing data if editing
    if (widget.isEditing && widget.initialMetadata != null) {
      final metadata = widget.initialMetadata!;
      _dailyBudgetController.text = (metadata['daily_budget'] ?? 100.0).toString();
      
      // Load reminder settings
      _enableReminders = metadata['reminder_enabled'] ?? true;
      if (metadata['reminder_time'] != null) {
        final timeParts = metadata['reminder_time'].split(':');
        if (timeParts.length >= 2) {
          _reminderTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }
      }
      
      // Load currency and categories if available
      _selectedCurrency = metadata['currency'] ?? 'USD';
      _selectedCategories = List<String>.from(metadata['categories'] ?? ['Food', 'Transport', 'Entertainment', 'Bills', 'Shopping', 'Other']);
    }
  }
  
  @override
  void dispose() {
    _dailyBudgetController.dispose();
    super.dispose();
  }

  Future<void> _saveExpenseTrackerSettings() async {
    if (_isCreating) return; // Prevent multiple submissions
    
    setState(() {
      _isCreating = true;
    });
    
    try {
      // Validate inputs
      if (_dailyBudget <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid daily budget')),
        );
        setState(() {
          _isCreating = false;
        });
        return;
      }
      
      // Create settings object
      final settings = ExpenseSettings(
        dailyBudget: _dailyBudget,
        currency: _selectedCurrency,
        reminderEnabled: _enableReminders,
        reminderTime: _enableReminders ? _reminderTime : null,
      );

      // Save settings to database
      await ExpenseService.instance.updateExpenseSettings(settings);
      
      // Create metadata for the card
      final metadata = {
        'type': 'expense_tracker',
        'daily_budget': _dailyBudget,
        'currency': _selectedCurrency,
        'categories': _selectedCategories,
        'reminder_enabled': _enableReminders,
        'reminder_time': _enableReminders 
          ? '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}:00'
          : null,
      };
      
      if (widget.isEditing && widget.onSave != null) {
        // Update existing card
        widget.onSave!(metadata);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // Create new card
        final cardData = {
          'title': 'Daily Expense Tracker',
          'description': 'Track your daily spending and stay within budget',
          'color': '0xFF2E7D32', // Dark Green
          'tags': ['finance', 'budget'],
          'metadata': metadata,
          'tasks': [
            {
              'id': _uuid.v4(),
              'description': 'Log essential expenses',
              'notes': 'Food, transport, bills',
              'is_completed': false,
              'priority': 'high',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': _uuid.v4(),
              'description': 'Log discretionary spending',
              'notes': 'Entertainment, shopping',
              'is_completed': false,
              'priority': 'medium',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            {
              'id': _uuid.v4(),
              'description': 'Review daily spending',
              'notes': 'Check if within budget',
              'is_completed': false,
              'priority': 'low',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          ],
        };
        
        print('Creating expense tracker card with data: ${cardData['title']}');
        
        try {
          // Create the card
          final newCard = await CardService.createCard(cardData);
          print('Expense tracker card created successfully with ID: ${newCard.id}');
          
          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense Tracker created successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            // Return true to indicate success and navigate back to home
            print('Navigating back with result: true');
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          print('Error creating expense tracker card: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating card: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          rethrow; // Rethrow to be caught by the outer try-catch
        }
      }
    } catch (e) {
      print('Error in _saveExpenseTrackerSettings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${widget.isEditing ? 'updating' : 'creating'} card: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Stack(
      children: [
        // Background pattern
        Positioned.fill(child: backgroundWidget),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.isEditing ? 'Edit Expense Tracker' : 'Set Up Expense Tracker',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: isDarkMode 
              ? Color(0xFF282A40).withOpacity(0.7) 
              : Colors.white.withOpacity(0.7),
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Introduction
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDarkMode ? Color(0xFF282A40) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Expense Tracker',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track your daily spending to stay within budget and understand your spending habits.',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Set a daily budget and track your spending',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Snap photos of receipts to log expenses quickly',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'View spending breakdown by category',
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Daily Budget
                  Text(
                    'Set Your Daily Budget',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dailyBudgetController,
                    decoration: InputDecoration(
                      labelText: 'Daily Budget (\$)',
                      border: OutlineInputBorder(),
                      hintText: '100',
                      prefixIcon: Icon(
                        Icons.attach_money,
                        color: isDarkMode ? Colors.greenAccent : Colors.green,
                      ),
                      labelStyle: TextStyle(
                        color: isDarkMode ? Colors.white70 : null,
                      ),
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white30 : null,
                      ),
                      fillColor: isDarkMode ? Color(0xFF282A40) : null,
                      filled: isDarkMode,
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Reminder Settings
                  Text(
                    'Reminder Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDarkMode ? Color(0xFF282A40) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text(
                              'Enable Daily Reminders',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Get reminded to log your expenses',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            value: _enableReminders,
                            activeColor: isDarkMode ? Colors.greenAccent : Colors.green,
                            onChanged: (value) {
                              setState(() {
                                _enableReminders = value;
                              });
                            },
                          ),
                          if (_enableReminders) ...[
                            Divider(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            ListTile(
                              title: Text(
                                'Reminder Time',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              trailing: Icon(
                                Icons.access_time,
                                color: isDarkMode ? Colors.greenAccent : Colors.green,
                              ),
                              onTap: _selectReminderTime,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _saveExpenseTrackerSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDarkMode ? Colors.green.shade700 : Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                      child: _isCreating
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.isEditing ? 'Update Settings' : 'Create Expense Tracker',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
} 