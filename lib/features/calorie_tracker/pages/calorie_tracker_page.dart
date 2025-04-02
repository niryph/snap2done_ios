import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/calorie_tracker_models.dart';
import '../services/vision_service.dart';
import '../widgets/calorie_progress_circle.dart';
import '../widgets/calorie_graph_painter.dart';
import 'calorie_tracker_setup_page.dart';

class CalorieTrackerPage extends StatefulWidget {
  final String userId;
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const CalorieTrackerPage({
    Key? key,
    required this.userId,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<CalorieTrackerPage> createState() => _CalorieTrackerPageState();
}

class _CalorieTrackerPageState extends State<CalorieTrackerPage> {
  late DateTime _selectedDate;
  late List<FoodEntry> _currentDayEntries;
  late CalorieTrackerSettings _settings;
  bool _isAddingManually = false;
  bool _isScanning = false;
  String _selectedGraphType = 'daily';
  String _selectedMacroType = 'calories';
  List<MapEntry<DateTime, double>> _graphData = [];
  bool _showGraphView = false;
  
  // Text controllers for the form
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentDayEntries = [];
    _settings = CalorieTrackerSettings.fromMap(widget.metadata);
    _loadEntriesForSelectedDate();
    _loadGraphData();
  }
  
  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    await _loadEntriesForSelectedDate();
  }
  
  Future<void> _loadEntriesForSelectedDate() async {
    try {
      final response = await Supabase.instance.client
          .from('calorie_entries')
          .select()
          .eq('user_id', widget.userId)
          .gte('timestamp', DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toUtc().toIso8601String())
          .lt('timestamp', DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1).toUtc().toIso8601String())
          .order('timestamp');

      if (mounted) {
        setState(() {
          _currentDayEntries = (response as List<dynamic>)
              .map((entry) => FoodEntry.fromMap(entry as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (error) {
      print('Error loading entries: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load food entries'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Calculate total calories consumed today
  double get _totalCalories {
    return _currentDayEntries.fold(0, (sum, entry) => sum + entry.calories);
  }
  
  // Calculate remaining calories for today
  double get _remainingCalories {
    return _settings.dailyGoal - _totalCalories;
  }
  
  // Calculate progress percentage
  double get progressPercentage {
    return (_totalCalories / _settings.dailyGoal).clamp(0.0, 1.0);
  }
  
  // Calculate total macros consumed today
  Map<String, double> get _totalMacros {
    double totalCarbs = 0;
    double totalProtein = 0;
    double totalFat = 0;
    
    for (var entry in _currentDayEntries) {
      totalCarbs += entry.carbs;
      totalProtein += entry.protein;
      totalFat += entry.fat;
    }
    
    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'fat': totalFat,
    };
  }
  
  // Add a new food entry
  void _addFoodEntry() async {
    if (_foodNameController.text.isEmpty || _caloriesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in at least the food name and calories')),
      );
      return;
    }

    final newEntry = FoodEntry(
      id: const Uuid().v4(),
      name: _foodNameController.text,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      timestamp: DateTime.now(),
    );

    setState(() {
      _currentDayEntries.add(newEntry);
      _isAddingManually = false;
    });

    // Clear the form
    _foodNameController.clear();
    _caloriesController.clear();
    _carbsController.clear();
    _proteinController.clear();
    _fatController.clear();

    // Save the entry to the database
    await _saveEntries();
    _updateTotalCalories();
  }

  Future<void> _saveEntries() async {
    try {
      // First, get all entries for this day from the database
      final response = await Supabase.instance.client
          .from('calorie_entries')
          .select()
          .eq('user_id', widget.userId)
          .gte('timestamp', DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toUtc().toIso8601String())
          .lt('timestamp', DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + 1).toUtc().toIso8601String());

      final existingEntries = (response as List<dynamic>)
          .map((entry) => entry['id'] as String)
          .toSet();

      final currentEntryIds = _currentDayEntries.map((e) => e.id).toSet();

      // Delete entries that are no longer in the current list
      final entriesToDelete = existingEntries.difference(currentEntryIds);
      if (entriesToDelete.isNotEmpty) {
        await Supabase.instance.client
            .from('calorie_entries')
            .delete()
            .inFilter('id', entriesToDelete.toList());
      }

      // Update or insert current entries
      for (var entry in _currentDayEntries) {
        final entryMap = entry.toMap();
        entryMap['user_id'] = widget.userId;

        await Supabase.instance.client
            .from('calorie_entries')
            .upsert(entryMap);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food entries updated successfully')),
        );
      }
    } catch (error) {
      print('Error saving food entries: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save food entries. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Remove a food entry
  Future<void> _removeFoodEntry(String entryId) async {
    try {
      await Supabase.instance.client
          .from('calorie_entries')
          .delete()
          .match({'id': entryId, 'user_id': widget.userId});

      setState(() {
        _currentDayEntries.removeWhere((entry) => entry.id == entryId);
      });
    } catch (error) {
      print('Error removing food entry: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove food entry. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanFood() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        setState(() {
          _isScanning = false;
        });
        return;
      }

      // Analyze the image using Vision Service
      final VisionService visionService = VisionService();
      final result = await visionService.analyzeFoodImage(image.path);

      if (mounted) {
        setState(() {
          _isScanning = false;
          _isAddingManually = true;
          
          // Pre-fill the form with the analysis results
          _foodNameController.text = result.name;
          _caloriesController.text = result.calories.toString();
          _carbsController.text = result.carbs.toString();
          _proteinController.text = result.protein.toString();
          _fatController.text = result.fat.toString();
        });

        // Show the manual entry form with pre-filled data
        _showAddFoodBottomSheet();
      }
    } catch (error) {
      print('Error scanning food: $error');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to scan food. Please try again or enter manually.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddFoodBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Food',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Food name
              TextField(
                controller: _foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Food Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              // Calories
              TextField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories (kcal)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Add button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _addFoodEntry();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add Food',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Calorie Tracker'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showGraphView ? Icons.show_chart : Icons.bar_chart),
            onPressed: () {
              setState(() {
                _showGraphView = !_showGraphView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CalorieTrackerSetupPage(
                    isEditing: true,
                    cardId: widget.cardId,
                    initialMetadata: widget.metadata,
                    onSave: widget.onMetadataChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showGraphView) ...[
                      _buildCalendarNavigation(),
                      _buildProgressSummary(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isScanning ? null : () {
                              setState(() {
                                _isAddingManually = true;
                              });
                              _showAddFoodBottomSheet();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Food'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scanFood,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Scan Food'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildCalorieGraphs(),
                      ),
                    ],
                  ],
                ),
              ),
              SliverFillRemaining(
                child: _buildFoodList(),
              ),
            ],
          ),
          if (_isScanning)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing food...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Build the daily calorie progress summary
  Widget _buildProgressSummary() {
    final macros = _totalMacros;
    // Default macro distribution if not set (40/30/30)
    final carbsGoal = _settings.macroGoals['carbs'] ?? 40;
    final proteinGoal = _settings.macroGoals['protein'] ?? 30;
    final fatGoal = _settings.macroGoals['fat'] ?? 30;
    
    final carbsTarget = (_settings.dailyGoal * carbsGoal / 100) / 4;
    final proteinTarget = (_settings.dailyGoal * proteinGoal / 100) / 4;
    final fatTarget = (_settings.dailyGoal * fatGoal / 100) / 9;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Circle
              SizedBox(
                width: 140,
                child: CalorieProgressCircle(
                  progress: (_totalCalories / _settings.dailyGoal).clamp(0.0, 1.0),
                  total: _settings.dailyGoal.toDouble(),
                  current: _totalCalories,
                  size: 140,
                ),
              ),
              const SizedBox(width: 16),
              // Macro breakdown with progress bars
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMacroProgressBar(
                      'Carbs',
                      macros['carbs']?.toInt() ?? 0,
                      carbsTarget.toInt(),
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroProgressBar(
                      'Protein',
                      macros['protein']?.toInt() ?? 0,
                      proteinTarget.toInt(),
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroProgressBar(
                      'Fat',
                      macros['fat']?.toInt() ?? 0,
                      fatTarget.toInt(),
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieGraphs() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: _buildGraph(),
            ),
            const SizedBox(height: 24),
            // Time period toggle and macro type selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time period toggle
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGraphType = _selectedGraphType == 'daily' ? 'weekly' : 'daily';
                      _loadGraphData();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedGraphType == 'daily' ? Icons.today : Icons.date_range,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedGraphType == 'daily' ? 'Daily' : 'Weekly',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Macro type selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMacroTypeButton('Calories', _selectedMacroType == 'calories', () {
                      setState(() => _selectedMacroType = 'calories');
                      _loadGraphData();
                    }),
                    const SizedBox(width: 8),
                    _buildMacroTypeButton('Carbs', _selectedMacroType == 'carbs', () {
                      setState(() => _selectedMacroType = 'carbs');
                      _loadGraphData();
                    }),
                    const SizedBox(width: 8),
                    _buildMacroTypeButton('Protein', _selectedMacroType == 'protein', () {
                      setState(() => _selectedMacroType = 'protein');
                      _loadGraphData();
                    }),
                    const SizedBox(width: 8),
                    _buildMacroTypeButton('Fat', _selectedMacroType == 'fat', () {
                      setState(() => _selectedMacroType = 'fat');
                      _loadGraphData();
                    }),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphTypeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMacroTypeButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _getMacroColor(label) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _getMacroColor(String macroType) {
    switch (macroType.toLowerCase()) {
      case 'calories':
        return Colors.orange;
      case 'carbs':
        return Colors.green;
      case 'protein':
        return Colors.blue;
      case 'fat':
        return Colors.orange.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildGraph() {
    if (_graphData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    double maxValue;
    switch (_selectedMacroType.toLowerCase()) {
      case 'calories':
        maxValue = _settings.dailyGoal.toDouble();
        break;
      case 'carbs':
        maxValue = (_settings.dailyGoal * (_settings.macroGoals['carbs'] ?? 40) / 100) / 4;
        break;
      case 'protein':
        maxValue = (_settings.dailyGoal * (_settings.macroGoals['protein'] ?? 30) / 100) / 4;
        break;
      case 'fat':
        maxValue = (_settings.dailyGoal * (_settings.macroGoals['fat'] ?? 30) / 100) / 9;
        break;
      default:
        maxValue = _settings.dailyGoal.toDouble();
    }

    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: CalorieGraphPainter(
        data: _graphData,
        maxValue: maxValue,
        isWeekly: _selectedGraphType == 'weekly',
        barColor: _getMacroColor(_selectedMacroType),
        targetLineColor: Colors.green.withOpacity(0.5),
        label: _selectedMacroType,
      ),
    );
  }

  Future<void> _loadGraphData() async {
    setState(() => _graphData.clear());
    
    try {
      final DateTime endDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final DateTime startDate = _selectedGraphType == 'daily'
          ? endDate
          : endDate.subtract(const Duration(days: 6));

      final response = await Supabase.instance.client
          .from('calorie_entries')
          .select()
          .eq('user_id', widget.userId)
          .gte('timestamp', startDate.toUtc().toIso8601String())
          .lte('timestamp', endDate.toUtc().toIso8601String())
          .order('timestamp');

      final entries = (response as List<dynamic>)
          .map((entry) => FoodEntry.fromMap(entry as Map<String, dynamic>))
          .toList();

      // Group entries by date and calculate totals
      final Map<DateTime, double> dailyTotals = {};
      for (var entry in entries) {
        final date = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        );
        
        double value;
        switch (_selectedMacroType.toLowerCase()) {
          case 'calories':
            value = entry.calories.toDouble();
            break;
          case 'carbs':
            value = entry.carbs;
            break;
          case 'protein':
            value = entry.protein;
            break;
          case 'fat':
            value = entry.fat;
            break;
          default:
            value = 0;
        }
        
        dailyTotals[date] = (dailyTotals[date] ?? 0) + value;
      }

      // Fill in missing dates with 0
      final List<MapEntry<DateTime, double>> graphData = [];
      for (int i = 0; i <= (_selectedGraphType == 'daily' ? 0 : 6); i++) {
        final date = startDate.add(Duration(days: i));
        if (date.compareTo(endDate) <= 0) {
          graphData.add(MapEntry(date, dailyTotals[date] ?? 0));
        }
      }

      setState(() => _graphData = graphData);
    } catch (error) {
      print('Error loading graph data: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load graph data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Build the list of today's food entries
  Widget _buildFoodList() {
    if (_currentDayEntries.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No food entries yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                      child: Text(
                        'Add your first meal by tapping the buttons above',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      itemCount: _currentDayEntries.length,
      itemBuilder: (context, index) {
        final entry = _currentDayEntries[index];
        return Dismissible(
          key: Key(entry.id),
          background: Container(
            color: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerRight,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Edit entry
              _showEditEntryDialog(entry);
              return false;
            } else {
              // Delete entry
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Delete Entry'),
                    content: const Text('Are you sure you want to delete this entry?'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            }
          },
          onDismissed: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Delete entry
              setState(() {
                _currentDayEntries.removeAt(index);
              });
              await _saveEntries(); // Save changes to database
              _updateTotalCalories();
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(entry.name),
              subtitle: Text('${entry.calories} calories'),
              trailing: Text(
                '${entry.protein}g P • ${entry.carbs}g C • ${entry.fat}g F',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditEntryDialog(FoodEntry entry) {
    final nameController = TextEditingController(text: entry.name);
    final caloriesController = TextEditingController(text: entry.calories.toString());
    final proteinController = TextEditingController(text: entry.protein.toString());
    final carbsController = TextEditingController(text: entry.carbs.toString());
    final fatController = TextEditingController(text: entry.fat.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Food Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Food Name'),
                ),
                TextField(
                  controller: caloriesController,
                  decoration: InputDecoration(labelText: 'Calories'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: proteinController,
                  decoration: InputDecoration(labelText: 'Protein (g)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: carbsController,
                  decoration: InputDecoration(labelText: 'Carbs (g)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: fatController,
                  decoration: InputDecoration(labelText: 'Fat (g)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updatedEntry = FoodEntry(
                  id: entry.id,
                  name: nameController.text,
                  calories: int.tryParse(caloriesController.text) ?? 0,
                  protein: double.tryParse(proteinController.text) ?? 0,
                  carbs: double.tryParse(carbsController.text) ?? 0,
                  fat: double.tryParse(fatController.text) ?? 0,
                  timestamp: entry.timestamp,
                );

                setState(() {
                  final index = _currentDayEntries.indexWhere((e) => e.id == entry.id);
                  if (index != -1) {
                    _currentDayEntries[index] = updatedEntry;
                  }
                });
                await _saveEntries(); // Save changes to database
                _updateTotalCalories();
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
              _loadEntriesForSelectedDate();
              _loadGraphData();
            },
          ),
          GestureDetector(
            onTap: () => _showDatePicker(),
            child: Text(
              DateFormat('MMM d, yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              _loadEntriesForSelectedDate();
              _loadGraphData();
            },
          ),
        ],
      ),
    );
  }

  void _updateTotalCalories() {
    setState(() {
      // The _totalCalories getter will automatically recalculate
      // based on the updated _currentDayEntries
    });
  }

  Widget _buildMacroProgressBar(String label, int current, int target, Color color) {
    final percentage = target > 0 ? (current / target * 100).clamp(0.0, 100.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$current/${target}g',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${percentage.toInt()}%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadEntriesForSelectedDate();
      _loadGraphData();
    }
  }
} 