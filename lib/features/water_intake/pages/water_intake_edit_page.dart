import 'package:flutter/material.dart';
import '../models/water_intake_models.dart';
import '../services/water_reminder_service.dart';
import '../../../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/theme_provider.dart';
import '../utils/unit_converter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WaterIntakeEditPage extends StatefulWidget {
  final String cardId;
  final Function(Map<String, dynamic>) onSave;

  const WaterIntakeEditPage({
    Key? key,
    required this.cardId,
    required this.onSave,
  }) : super(key: key);

  @override
  _WaterIntakeEditPageState createState() => _WaterIntakeEditPageState();
}

class _WaterIntakeEditPageState extends State<WaterIntakeEditPage> {
  late WaterIntakeSettings _settings;
  late double _dailyGoal;
  late TimeOfDay _wakeUpTime;
  late TimeOfDay _bedTime;
  late double _reminderInterval;
  late bool _enableWorkoutReminders;
  late bool _enableWeatherReminders;
  late bool _remindersEnabled;
  late UnitType _unitType;

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
    // Initialize with default values
    _settings = WaterIntakeSettings();
    _dailyGoal = 2000.0;
    _wakeUpTime = TimeOfDay(hour: 8, minute: 0);
    _bedTime = TimeOfDay(hour: 22, minute: 0);
    _reminderInterval = 2.0;
    _enableWorkoutReminders = false;
    _enableWeatherReminders = false;
    _remindersEnabled = false;
    _unitType = UnitType.milliliter;
    
    // Load actual settings
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final data = await Supabase.instance.client
            .from('water_intake_settings')
            .select()
            .eq('user_id', userId)
            .single();

        if (data != null) {
          final settings = WaterIntakeSettings.fromJson(data);
          if (mounted) {
            setState(() {
              _settings = settings;
              _dailyGoal = settings.dailyGoal;
              _wakeUpTime = settings.startTime;
              _bedTime = settings.endTime;
              _remindersEnabled = settings.remindersEnabled;
              _reminderInterval = settings.reminderIntervalHours.toDouble();
              _unitType = settings.unitType;
            });
          }
        }
      } catch (error) {
        print('Error loading settings: $error');
      }
    }
  }

  void _saveSettings() {
    // Save settings to Supabase
    // ...

    widget.onSave(_settings.toJson());
    Navigator.pop(context);
  }

  // Convert goal value when unit type changes
  void _handleUnitTypeChange(UnitType newUnitType) {
    if (newUnitType != _unitType) {
      double convertedGoal;
      
      if (newUnitType == UnitType.fluidOunce) {
        // Convert from ml to fl oz
        convertedGoal = UnitConverter.mlToFlOz(_dailyGoal);
        // Clamp to valid fl oz range
        convertedGoal = convertedGoal.clamp(30.0, 170.0);
      } else {
        // Convert from fl oz to ml
        convertedGoal = UnitConverter.flOzToMl(_dailyGoal);
        // Clamp to valid ml range
        convertedGoal = convertedGoal.clamp(1000.0, 5000.0);
      }
      
      setState(() {
        _unitType = newUnitType;
        _dailyGoal = convertedGoal;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Stack(
      children: [
        // Make sure the background covers the entire screen
        Positioned.fill(child: backgroundWidget),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: false,
          appBar: AppBar(
            title: Text(
              'Edit Hydration Settings',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: isDarkMode ? Color(0xFF282A40).withOpacity(0.7) : Colors.white.withOpacity(0.7),
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDailyGoalSection(),
                  _buildReminderSection(),
                  _buildActivityRemindersSection(),
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF282A40) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _saveSettings();
                      },
                      child: const Text('Save'),
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

  // Update cards to respect dark theme
  Widget _buildDailyGoalSection() {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    // Determine min, max, and divisions based on unit type
    final double minValue = _unitType == UnitType.fluidOunce ? 30.0 : 1000.0;
    final double maxValue = _unitType == UnitType.fluidOunce ? 170.0 : 5000.0;
    final int divisions = _unitType == UnitType.fluidOunce ? 28 : 40;
    
    // Determine recommended values based on unit type
    final double maleValue = _unitType == UnitType.fluidOunce ? 125.0 : 3700.0;
    final double femaleValue = _unitType == UnitType.fluidOunce ? 91.0 : 2700.0;
    
    // Format the goal value based on unit type
    final String formattedGoal = UnitConverter.formatAmount(_dailyGoal, _unitType);
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: isDarkMode ? Color(0xFF282A40) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Water Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _unitType == UnitType.fluidOunce
                  ? 'The recommended intake is 125 fl oz for men and 91 fl oz for women.'
                  : 'The recommended intake is 3.7L for men and 2.7L for women.',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Unit selection
            Row(
              children: [
                Text(
                  'Measurement Unit:', 
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                SegmentedButton<UnitType>(
                  segments: const [
                    ButtonSegment<UnitType>(
                      value: UnitType.fluidOunce,
                      label: Text('fl oz'),
                    ),
                    ButtonSegment<UnitType>(
                      value: UnitType.milliliter,
                      label: Text('ml/L'),
                    ),
                  ],
                  selected: {_unitType},
                  onSelectionChanged: (Set<UnitType> selection) {
                    _handleUnitTypeChange(selection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _dailyGoal = maleValue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dailyGoal == maleValue ? Color(0xFF6C5CE7) : isDarkMode ? Colors.grey[800] : null,
                    foregroundColor: _dailyGoal == maleValue ? Colors.white : isDarkMode ? Colors.white : null,
                  ),
                  child: Text(_unitType == UnitType.fluidOunce 
                      ? 'Male (125 fl oz)' 
                      : 'Male (3.7L)'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => setState(() => _dailyGoal = femaleValue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dailyGoal == femaleValue ? Color(0xFF6C5CE7) : isDarkMode ? Colors.grey[800] : null,
                    foregroundColor: _dailyGoal == femaleValue ? Colors.white : isDarkMode ? Colors.white : null,
                  ),
                  child: Text(_unitType == UnitType.fluidOunce 
                      ? 'Female (91 fl oz)' 
                      : 'Female (2.7L)'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _dailyGoal,
                    min: minValue,
                    max: maxValue,
                    divisions: divisions,
                    label: formattedGoal,
                    activeColor: Color(0xFF6C5CE7),
                    onChanged: (value) => setState(() => _dailyGoal = value),
                  ),
                ),
                Container(
                  width: 90,
                  alignment: Alignment.center,
                  child: Text(
                    formattedGoal,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection() {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: isDarkMode ? Color(0xFF282A40) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reminder Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                'Enable Reminders',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              ),
              value: _remindersEnabled,
              activeColor: Color(0xFF6C5CE7),
              onChanged: (value) => setState(() => _remindersEnabled = value),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              title: Text(
                'Wake-up Time',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _wakeUpTime,
                  );
                  if (time != null) {
                    setState(() => _wakeUpTime = time);
                  }
                },
                child: Text(
                  '${_wakeUpTime.hour.toString().padLeft(2, '0')}:${_wakeUpTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
            ),
            ListTile(
              title: Text(
                'Bedtime',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _bedTime,
                  );
                  if (time != null) {
                    setState(() => _bedTime = time);
                  }
                },
                child: Text(
                  '${_bedTime.hour.toString().padLeft(2, '0')}:${_bedTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Color(0xFF6C5CE7)),
                ),
              ),
            ),
            const Divider(color: Colors.grey),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Reminder Interval',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _reminderInterval,
                    min: 1.0,
                    max: 4.0,
                    divisions: 6,
                    label: '${_reminderInterval.toStringAsFixed(1)} hours',
                    activeColor: Color(0xFF6C5CE7),
                    onChanged: _remindersEnabled 
                        ? (value) => setState(() => _reminderInterval = value)
                        : null,
                  ),
                ),
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  child: Text(
                    '${_reminderInterval.toStringAsFixed(1)} hours',
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
    );
  }

  Widget _buildActivityRemindersSection() {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: isDarkMode ? Color(0xFF282A40) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity-Based Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                'Workout Reminders',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Extra reminders after exercise',
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
              value: _enableWorkoutReminders && _remindersEnabled,
              activeColor: Color(0xFF6C5CE7),
              onChanged: _remindersEnabled 
                  ? (value) => setState(() => _enableWorkoutReminders = value)
                  : null,
            ),
            SwitchListTile(
              title: Text(
                'Weather-Based Reminders',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Extra reminders during hot weather',
                style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
              value: _enableWeatherReminders && _remindersEnabled,
              activeColor: Color(0xFF6C5CE7),
              onChanged: _remindersEnabled 
                  ? (value) => setState(() => _enableWeatherReminders = value)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}