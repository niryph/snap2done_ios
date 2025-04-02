import 'package:flutter/material.dart';
import '../models/calorie_tracker_models.dart';
import '../../../services/card_service.dart';
import '../../../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/theme_provider.dart';

class CalorieTrackerSetupPage extends StatefulWidget {
  final bool isEditing;
  final String? cardId;
  final Map<String, dynamic>? initialMetadata;
  final Function(Map<String, dynamic>)? onSave;

  const CalorieTrackerSetupPage({
    Key? key, 
    this.isEditing = false,
    this.cardId,
    this.initialMetadata,
    this.onSave,
  }) : super(key: key);

  @override
  State<CalorieTrackerSetupPage> createState() => _CalorieTrackerSetupPageState();
}

class _CalorieTrackerSetupPageState extends State<CalorieTrackerSetupPage> {
  final TextEditingController _dailyGoalController = TextEditingController(text: '2000');
  
  // Macro percentages
  double _carbsPercentage = 50.0;
  double _proteinPercentage = 30.0;
  double _fatPercentage = 20.0;
  
  bool _enableReminders = false;
  bool _isCreating = false;
  
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
  
  @override
  void initState() {
    super.initState();
    
    // Initialize with existing data if editing
    if (widget.isEditing && widget.initialMetadata != null) {
      final metadata = widget.initialMetadata!;
      _dailyGoalController.text = (metadata['dailyGoal'] ?? 2000.0).toString();
      
      // Load macro percentages
      if (metadata['macroGoals'] != null) {
        _carbsPercentage = metadata['macroGoals']['carbs'] ?? 50.0;
        _proteinPercentage = metadata['macroGoals']['protein'] ?? 30.0;
        _fatPercentage = metadata['macroGoals']['fat'] ?? 20.0;
      }
      
      // Load reminder settings
      if (metadata['reminderSettings'] != null) {
        _enableReminders = metadata['reminderSettings']['enabled'] ?? false;
      }
    }
  }
  
  @override
  void dispose() {
    _dailyGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveCalorieTrackerSettings() async {
    if (_isCreating) return;
    
    // Validate daily goal
    final dailyGoalText = _dailyGoalController.text.trim();
    if (dailyGoalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a daily calorie goal')),
      );
      return;
    }
    
    final dailyGoal = double.tryParse(dailyGoalText);
    if (dailyGoal == null || dailyGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number for daily goal')),
      );
      return;
    }
    
    setState(() {
      _isCreating = true;
    });
    
    try {
      // Create card metadata
      final metadata = widget.isEditing && widget.initialMetadata != null 
          ? Map<String, dynamic>.from(widget.initialMetadata!)
          : <String, dynamic>{
              'type': 'calorie_tracker',
              'dailyEntries': {},
            };
      
      // Update metadata
      metadata['dailyGoal'] = dailyGoal;
      metadata['macroGoals'] = {
        'carbs': _carbsPercentage,
        'protein': _proteinPercentage,
        'fat': _fatPercentage,
      };
      metadata['reminderSettings'] = {
        'enabled': _enableReminders,
        'mealTimes': [
          {'hour': 8, 'minute': 0},
          {'hour': 12, 'minute': 30},
          {'hour': 18, 'minute': 0},
        ],
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
          'title': 'Calorie Tracker',
          'description': 'Track your daily calorie intake and macronutrients',
          'color': '0xFFF9A825', // Orange color for food theme
          'tags': ['health', 'nutrition'],
          'metadata': metadata,
        };
        
        final newCard = await CardService.createCard(cardData);
        
        if (mounted) {
          // Show success message before popping
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Calorie Tracker created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Return true to indicate success
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${widget.isEditing ? 'updating' : 'creating'} card: $e')),
        );
        setState(() {
          _isCreating = false;
        });
      }
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
              widget.isEditing ? 'Edit Calorie Tracker' : 'Set Up Calorie Tracker',
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
                            'Calorie & Nutrition Tracker',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track your daily food intake, calories, and macronutrients to maintain a healthy diet.',
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
                                  'Log meals with calories and macros',
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
                                  'Scan food with your camera to automatically log nutrition',
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
                                  'Track your progress toward daily goals',
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
                  
                  // Daily Calorie Goal
                  Text(
                    'Set Your Daily Calorie Goal',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _dailyGoalController,
                    decoration: InputDecoration(
                      labelText: 'Daily Calorie Goal (kcal)',
                      border: OutlineInputBorder(),
                      hintText: '2000',
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
                  
                  // Macronutrient Distribution
                  Text(
                    'Macronutrient Distribution',
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
                          // Carbs
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Carbohydrates',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_carbsPercentage.toInt()}%',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.green,
                              thumbColor: Colors.green,
                              overlayColor: Colors.green.withAlpha(32),
                              valueIndicatorColor: isDarkMode ? Color(0xFF282A40) : Colors.white,
                              valueIndicatorTextStyle: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            child: Slider(
                              value: _carbsPercentage,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '${_carbsPercentage.toInt()}%',
                              onChanged: (value) {
                                setState(() {
                                  _carbsPercentage = value;
                                  // Adjust other percentages to maintain 100% total
                                  final remaining = 100 - _carbsPercentage;
                                  final ratio = _proteinPercentage / (_proteinPercentage + _fatPercentage);
                                  _proteinPercentage = remaining * ratio;
                                  _fatPercentage = remaining * (1 - ratio);
                                });
                              },
                            ),
                          ),
                          
                          // Protein
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Protein',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_proteinPercentage.toInt()}%',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.blue,
                              thumbColor: Colors.blue,
                              overlayColor: Colors.blue.withAlpha(32),
                              valueIndicatorColor: isDarkMode ? Color(0xFF282A40) : Colors.white,
                              valueIndicatorTextStyle: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            child: Slider(
                              value: _proteinPercentage,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '${_proteinPercentage.toInt()}%',
                              onChanged: (value) {
                                setState(() {
                                  _proteinPercentage = value;
                                  // Adjust other percentages to maintain 100% total
                                  final remaining = 100 - _proteinPercentage;
                                  final ratio = _carbsPercentage / (_carbsPercentage + _fatPercentage);
                                  _carbsPercentage = remaining * ratio;
                                  _fatPercentage = remaining * (1 - ratio);
                                });
                              },
                            ),
                          ),
                          
                          // Fat
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fat',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_fatPercentage.toInt()}%',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.orange,
                              thumbColor: Colors.orange,
                              overlayColor: Colors.orange.withAlpha(32),
                              valueIndicatorColor: isDarkMode ? Color(0xFF282A40) : Colors.white,
                              valueIndicatorTextStyle: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            child: Slider(
                              value: _fatPercentage,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '${_fatPercentage.toInt()}%',
                              onChanged: (value) {
                                setState(() {
                                  _fatPercentage = value;
                                  // Adjust other percentages to maintain 100% total
                                  final remaining = 100 - _fatPercentage;
                                  final ratio = _carbsPercentage / (_carbsPercentage + _proteinPercentage);
                                  _carbsPercentage = remaining * ratio;
                                  _proteinPercentage = remaining * (1 - ratio);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Reminders
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
                            'Meal Reminders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            title: Text(
                              'Enable Meal Reminders',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Get notifications to log your meals',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            value: _enableReminders,
                            activeColor: isDarkMode ? Colors.orangeAccent : Colors.orange,
                            onChanged: (value) {
                              setState(() {
                                _enableReminders = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _saveCalorieTrackerSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        backgroundColor: isDarkMode ? Colors.orange.shade700 : Colors.orange,
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
                              widget.isEditing ? 'Update Calorie Tracker' : 'Create Calorie Tracker',
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