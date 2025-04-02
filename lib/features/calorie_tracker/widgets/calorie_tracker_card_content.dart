import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/calorie_tracker_models.dart';
import 'calorie_progress_circle.dart';
import '../../../services/vision_service.dart';
import '../../../services/service_factory.dart';
import '../../../services/image_service.dart';

class CalorieTrackerCardContent extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const CalorieTrackerCardContent({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<CalorieTrackerCardContent> createState() => _CalorieTrackerCardContentState();
}

class _CalorieTrackerCardContentState extends State<CalorieTrackerCardContent> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late List<Map<String, dynamic>> _currentDayEntries;
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _dailyGoalController = TextEditingController();
  
  String? _selectedMealType;
  bool _isExpanded = true;
  bool _isUpdating = false;
  bool _isAddingFood = false;
  bool _isEditingGoal = false;
  bool _isScanning = false;
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadEntriesForSelectedDate();
    _dailyGoalController.text = (widget.metadata['dailyGoal'] ?? 2000.0).toString();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _dailyGoalController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadEntriesForSelectedDate() {
    final dateKey = _dateToKey(_selectedDate);
    _currentDayEntries = List<Map<String, dynamic>>.from(
      widget.metadata['dailyEntries']?[dateKey] ?? []
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
    final goal = widget.metadata['dailyGoal'] ?? 2000.0;
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

  Future<void> _addFoodEntry() async {
    if (_isUpdating) return;
    
    // Validate inputs
    final foodName = _foodNameController.text.trim();
    final caloriesText = _caloriesController.text.trim();
    final carbsText = _carbsController.text.trim();
    final proteinText = _proteinController.text.trim();
    final fatText = _fatController.text.trim();
    
    if (foodName.isEmpty || caloriesText.isEmpty || 
        carbsText.isEmpty || proteinText.isEmpty || fatText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    
    final calories = double.tryParse(caloriesText);
    final carbs = double.tryParse(carbsText);
    final protein = double.tryParse(proteinText);
    final fat = double.tryParse(fatText);
    
    if (calories == null || carbs == null || protein == null || fat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
      return;
    }
    
    // Set updating flag
    setState(() {
      _isUpdating = true;
    });
    
    final dateKey = _dateToKey(_selectedDate);
    final entry = {
      'food': foodName,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'timestamp': DateTime.now().toIso8601String(),
      'mealType': _selectedMealType ?? 'Other',
    };
    
    // Add entry to current day
    _currentDayEntries.add(entry);
    
    // Update metadata
    final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
    if (updatedMetadata['dailyEntries'] == null) {
      updatedMetadata['dailyEntries'] = {};
    }
    updatedMetadata['dailyEntries'][dateKey] = _currentDayEntries;
    
    // Reset form fields first
    _foodNameController.clear();
    _caloriesController.clear();
    _carbsController.clear();
    _proteinController.clear();
    _fatController.clear();
    
    // Update UI state before saving to prevent flicker
    setState(() {
      _isUpdating = false;
      _isAddingFood = false;
    });
    
    // Save changes after UI is updated
    await widget.onMetadataChanged(updatedMetadata);
  }

  Future<void> _updateDailyGoal() async {
    if (_isUpdating) return;
    
    final goalText = _dailyGoalController.text.trim();
    if (goalText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a daily goal')),
      );
      return;
    }
    
    final goal = double.tryParse(goalText);
    if (goal == null || goal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number')),
      );
      return;
    }
    
    // Set updating flag
    setState(() {
      _isUpdating = true;
    });
    
    // Update metadata
    final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
    updatedMetadata['dailyGoal'] = goal;
    
    // Update UI state before saving to prevent flicker
    setState(() {
      _isUpdating = false;
      _isEditingGoal = false;
    });
    
    // Save changes after UI is updated
    await widget.onMetadataChanged(updatedMetadata);
  }

  Future<void> _scanFood() async {
    setState(() {
      _isScanning = true;
    });
    
    try {
      // Capture image
      final imageFile = await ImageService.captureImage();
      if (imageFile == null) {
        setState(() {
          _isScanning = false;
        });
        return;
      }
      
      // Process with Vision API
      final visionResult = await VisionService.performOCR(imageFile.path);
      if (visionResult == null || visionResult.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to analyze image')),
        );
        setState(() {
          _isScanning = false;
        });
        return;
      }
      
      // Process with OpenAI
      final prompt = '''
      Based on this image of food, please provide:
      1. Food name
      2. Estimated calories (kcal)
      3. Estimated macronutrients (grams of carbs, protein, fat)
      
      Format your response as JSON:
      {
        "food": "Food name",
        "calories": 000,
        "carbs": 00,
        "protein": 00,
        "fat": 00
      }
      
      Image description: $visionResult
      ''';
      
      try {
        final openAIResponse = await ServiceFactory.generateTodoList(prompt);
        
        // Parse JSON response
        try {
          // Extract JSON from the response (it might be wrapped in markdown code blocks)
          final jsonStr = openAIResponse.toString();
          final jsonRegExp = RegExp(r'{[\s\S]*}');
          final match = jsonRegExp.firstMatch(jsonStr);
          
          Map<String, dynamic> nutritionData;
          if (match == null) {
            // If no JSON found, use default values
            nutritionData = {
              'food': 'Unknown Food Item',
              'calories': 200,
              'carbs': 20,
              'protein': 10,
              'fat': 5
            };
          } else {
            final jsonData = match.group(0);
            nutritionData = json.decode(jsonData!);
          }
          
          // Populate form fields
          setState(() {
            _foodNameController.text = nutritionData['food'] ?? 'Unknown Food';
            _caloriesController.text = (nutritionData['calories'] ?? 200).toString();
            _carbsController.text = (nutritionData['carbs'] ?? 20).toString();
            _proteinController.text = (nutritionData['protein'] ?? 10).toString();
            _fatController.text = (nutritionData['fat'] ?? 5).toString();
            _isAddingFood = true;
            _isScanning = false;
          });
        } catch (e) {
          // If parsing fails, use default values
          setState(() {
            _foodNameController.text = 'Unknown Food Item';
            _caloriesController.text = '200';
            _carbsController.text = '20';
            _proteinController.text = '10';
            _fatController.text = '5';
            _isAddingFood = true;
            _isScanning = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not analyze food details: $e. Using default values.')),
          );
        }
      } catch (e) {
        // If OpenAI service fails, use default values
        setState(() {
          _foodNameController.text = 'Unknown Food Item';
          _caloriesController.text = '200';
          _carbsController.text = '20';
          _proteinController.text = '10';
          _fatController.text = '5';
          _isAddingFood = true;
          _isScanning = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not analyze food details: $e. Using default values.')),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _deleteFoodEntry(int index) {
    // Remove entry locally first
    _currentDayEntries.removeAt(index);
    
    // Update UI immediately
    setState(() {});
    
    // Then update metadata and notify parent
    final dateKey = _dateToKey(_selectedDate);
    final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
    updatedMetadata['dailyEntries'][dateKey] = _currentDayEntries;
    
    // Save changes after UI is updated
    widget.onMetadataChanged(updatedMetadata);
  }

  @override
  Widget build(BuildContext context) {
    // Sort entries by date in descending order (newest first)
    _currentDayEntries.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp']);
      final bTime = DateTime.parse(b['timestamp']);
      return bTime.compareTo(aTime); // Descending order
    });
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _selectedDate.day == DateTime.now().day ? null : () => _navigateDate(1),
                ),
              ],
            ),
            
            // Combined Calorie Progress Circle and Macronutrient Breakdown
            if (!_isAddingFood)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left side: Calorie Progress Circle
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: CalorieProgressCircle(
                            progress: _progressPercentage,
                            total: widget.metadata['dailyGoal'] ?? 2000.0,
                            current: _totalCalories,
                            size: 150,
                          ),
                        ),
                      ),
                      
                      // Right side: Macronutrient Breakdown
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildMacroIndicator(
                                    context, 
                                    'Carbs', 
                                    _macroPercentages['carbs']!, 
                                    Colors.green,
                                    _macroTotals['carbs']!
                                  ),
                                  _buildMacroIndicator(
                                    context, 
                                    'Protein', 
                                    _macroPercentages['protein']!, 
                                    Colors.blue,
                                    _macroTotals['protein']!
                                  ),
                                  _buildMacroIndicator(
                                    context, 
                                    'Fat', 
                                    _macroPercentages['fat']!, 
                                    Colors.orange,
                                    _macroTotals['fat']!
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Add Food Button
            if (!_isAddingFood)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Food Manually'),
                        onPressed: () {
                          setState(() {
                            _isAddingFood = true;
                            _tabController.index = 0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Scan Food'),
                        onPressed: _isScanning ? null : _scanFood,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Add Food Form
            if (_isAddingFood)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Food',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isAddingFood = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Meal Type Selection
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Meal Type',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedMealType,
                        items: [
                          ...MealType.values.map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMealType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Food Name
                      TextField(
                        controller: _foodNameController,
                        decoration: const InputDecoration(
                          labelText: 'Food Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Calories
                      TextField(
                        controller: _caloriesController,
                        decoration: const InputDecoration(
                          labelText: 'Calories (kcal)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      
                      // Macros
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _carbsController,
                              decoration: const InputDecoration(
                                labelText: 'Carbs (g)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _proteinController,
                              decoration: const InputDecoration(
                                labelText: 'Protein (g)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _fatController,
                              decoration: const InputDecoration(
                                labelText: 'Fat (g)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Add Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _addFoodEntry,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Text('Add Food'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Food Log
            if (!_isAddingFood)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _currentDayEntries.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No entries for today'),
                              ),
                            )
                          : Container(
                              constraints: BoxConstraints(
                                // Calculate height based on number of entries
                                // Each entry is approximately 80 pixels high (including margins)
                                // Show all entries if 5 or fewer, otherwise set fixed height for 5 entries plus extra space
                                maxHeight: _currentDayEntries.length <= 5 
                                    ? _currentDayEntries.length * 80.0 + 20.0 
                                    : 5 * 80.0 + 20.0,
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                // Only enable scrolling if more than 5 entries
                                physics: _currentDayEntries.length > 5 
                                    ? const AlwaysScrollableScrollPhysics() 
                                    : const NeverScrollableScrollPhysics(),
                                itemCount: _currentDayEntries.length,
                                itemBuilder: (context, index) {
                                  final entry = _currentDayEntries[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    elevation: 1,
                                    child: InkWell(
                                      onTap: () => _editFoodEntry(index, entry),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor: _getMealTypeColor(entry['mealType']),
                                            child: Icon(
                                              _getMealTypeIcon(entry['mealType']),
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(entry['food']),
                                          subtitle: Text(
                                            'C: ${entry['carbs']}g | P: ${entry['protein']}g | F: ${entry['fat']}g',
                                          ),
                                          trailing: Padding(
                                            padding: const EdgeInsets.only(right: 16.0),
                                            child: Text(
                                              '${entry['calories']} kcal',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
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

  Widget _buildMacroIndicator(
    BuildContext context, 
    String label, 
    double percentage, 
    Color color,
    double grams
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${percentage.toInt()}%',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '${grams.toInt()}g',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
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

  // Method to edit a food entry
  void _editFoodEntry(int index, Map<String, dynamic> entry) {
    // Set up controllers with existing values
    _foodNameController.text = entry['food'];
    _caloriesController.text = entry['calories'].toString();
    _carbsController.text = entry['carbs'].toString();
    _proteinController.text = entry['protein'].toString();
    _fatController.text = entry['fat'].toString();
    _selectedMealType = entry['mealType'];
    
    // Show edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Food Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Meal Type Selection
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Meal Type',
                  border: OutlineInputBorder(),
                ),
                value: _selectedMealType,
                items: [
                  ...MealType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMealType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Food Name
              TextField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Calories
              TextField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              // Macros
              TextField(
                controller: _carbsController,
                decoration: const InputDecoration(
                  labelText: 'Carbs (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _proteinController,
                decoration: const InputDecoration(
                  labelText: 'Protein (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fatController,
                decoration: const InputDecoration(
                  labelText: 'Fat (g)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          // Delete button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFoodEntry(index);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _updateFoodEntry(index);
              Navigator.of(context).pop();
            },
            child: Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Clear controllers after dialog is closed
      _foodNameController.clear();
      _caloriesController.clear();
      _carbsController.clear();
      _proteinController.clear();
      _fatController.clear();
      _selectedMealType = null;
    });
  }

  // Method to update a food entry
  void _updateFoodEntry(int index) {
    // Validate inputs
    final foodName = _foodNameController.text.trim();
    final caloriesText = _caloriesController.text.trim();
    final carbsText = _carbsController.text.trim();
    final proteinText = _proteinController.text.trim();
    final fatText = _fatController.text.trim();
    
    if (foodName.isEmpty || caloriesText.isEmpty || 
        carbsText.isEmpty || proteinText.isEmpty || fatText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    
    final calories = double.tryParse(caloriesText);
    final carbs = double.tryParse(carbsText);
    final protein = double.tryParse(proteinText);
    final fat = double.tryParse(fatText);
    
    if (calories == null || carbs == null || protein == null || fat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
      return;
    }
    
    // Update entry
    final updatedEntry = {
      'food': foodName,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'timestamp': _currentDayEntries[index]['timestamp'], // Keep original timestamp
      'mealType': _selectedMealType ?? 'Other',
    };
    
    // Update locally first
    setState(() {
      _currentDayEntries[index] = updatedEntry;
    });
    
    // Then update metadata and notify parent
    final dateKey = _dateToKey(_selectedDate);
    final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
    if (updatedMetadata['dailyEntries'] == null) {
      updatedMetadata['dailyEntries'] = {};
    }
    updatedMetadata['dailyEntries'][dateKey] = _currentDayEntries;
    
    // Save changes after UI is updated
    widget.onMetadataChanged(updatedMetadata);
  }
} 