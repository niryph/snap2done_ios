import 'package:flutter/material.dart';
import '../models/water_intake_models.dart';
import '../services/water_reminder_service.dart';
import '../utils/unit_converter.dart';
import 'water_intake_page.dart';

class WaterIntakeOnboarding extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const WaterIntakeOnboarding({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<WaterIntakeOnboarding> createState() => _WaterIntakeOnboardingState();
}

class _WaterIntakeOnboardingState extends State<WaterIntakeOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _dailyGoal = 91.0; // Default for women in fl oz
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _bedTime = const TimeOfDay(hour: 22, minute: 0);
  double _reminderInterval = 1.5;
  bool _enableWorkoutReminders = false;
  bool _enableWeatherReminders = false;
  UnitType _unitType = UnitType.fluidOunce; // Default to fluid ounces

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 6) { // Updated to include unit selection page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    final metadata = {
      'dailyGoal': _dailyGoal,
      'dailyEntries': {},
      'unitType': _unitType.index,
      'reminderSettings': {
        'enabled': true,
        'intervalHours': _reminderInterval.toInt(),
        'startTime': {'hour': _wakeUpTime.hour, 'minute': _wakeUpTime.minute},
        'endTime': {'hour': _bedTime.hour, 'minute': _bedTime.minute},
      },
      'type': 'water_intake', // Add type to metadata
    };

    try {
      // Call the onComplete callback with metadata and wait for the result
      final result = await widget.onComplete(metadata);
      
      // Pop the onboarding page with the result
      Navigator.pop(context, result);
    } catch (e) {
      print("Error completing water intake onboarding: $e");
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating water intake card: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Pop the onboarding page with false to indicate failure
      Navigator.pop(context, false);
    }
  }

  // Handle unit type change
  void _handleUnitTypeChange(UnitType newUnitType) {
    if (newUnitType != _unitType) {
      double convertedGoal;
      
      if (newUnitType == UnitType.fluidOunce) {
        // Convert from ml to fl oz
        convertedGoal = UnitConverter.mlToFlOz(_dailyGoal);
      } else {
        // Convert from fl oz to ml
        convertedGoal = UnitConverter.flOzToMl(_dailyGoal);
      }
      
      setState(() {
        _unitType = newUnitType;
        _dailyGoal = convertedGoal;
      });
    }
  }

  Widget _buildWelcomeScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.water_drop,
          size: 80,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),
        Text(
          'Stay Hydrated, Stay Healthy!',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            'Let\'s set up your daily hydration goal and reminders to keep you on track.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _nextPage,
          child: const Text('Get Started'),
        ),
      ],
    );
  }

  Widget _buildUnitSelectionScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Choose Your Preferred Unit',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Select the measurement unit you prefer to track your hydration.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleUnitTypeChange(UnitType.fluidOunce),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _unitType == UnitType.fluidOunce ? Colors.blue : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: _unitType == UnitType.fluidOunce ? Colors.white : Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      const Text('Fluid Ounces (fl oz)'),
                      const SizedBox(height: 4),
                      const Text('US Customary', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleUnitTypeChange(UnitType.milliliter),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _unitType == UnitType.milliliter ? Colors.blue : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.water_drop,
                        color: _unitType == UnitType.milliliter ? Colors.white : Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      const Text('Milliliters (ml)'),
                      const SizedBox(height: 4),
                      const Text('Metric', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalScreen() {
    // Determine min, max, and divisions based on unit type
    final double minValue = _unitType == UnitType.fluidOunce ? 30.0 : 1000.0;
    final double maxValue = _unitType == UnitType.fluidOunce ? 170.0 : 5000.0;
    final int divisions = _unitType == UnitType.fluidOunce ? 28 : 40;
    
    // Determine recommended values based on unit type
    final double maleValue = _unitType == UnitType.fluidOunce ? 125.0 : 3700.0;
    final double femaleValue = _unitType == UnitType.fluidOunce ? 91.0 : 2700.0;
    
    // Format the goal value based on unit type
    final String formattedGoal = UnitConverter.formatAmount(_dailyGoal, _unitType);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'What\'s Your Daily Water Goal?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _unitType == UnitType.fluidOunce
                ? 'The recommended intake is 125 fl oz for men and 91 fl oz for women.'
                : 'The recommended intake is 3.7L for men and 2.7L for women.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _dailyGoal = maleValue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dailyGoal == maleValue ? Colors.blue : null,
                ),
                child: Text(_unitType == UnitType.fluidOunce 
                    ? 'Male (125 fl oz)' 
                    : 'Male (3.7L)'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => setState(() => _dailyGoal = femaleValue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dailyGoal == femaleValue ? Colors.blue : null,
                ),
                child: Text(_unitType == UnitType.fluidOunce 
                    ? 'Female (91 fl oz)' 
                    : 'Female (2.7L)'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Slider(
            value: _dailyGoal,
            min: minValue,
            max: maxValue,
            divisions: divisions,
            label: formattedGoal,
            onChanged: (value) => setState(() => _dailyGoal = value),
          ),
          Text(
            formattedGoal,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'When Do You Wake Up and Sleep?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'We\'ll create reminders between these times to keep you hydrated.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ListTile(
            title: const Text('Wake-up Time'),
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
              ),
            ),
          ),
          ListTile(
            title: const Text('Bedtime'),
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
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderIntervalScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'How Often Should We Remind You?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'We recommend reminders every 1.5–2 hours, but you can adjust this.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _reminderInterval = 1.5),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _reminderInterval == 1.5 ? Colors.blue : null,
                ),
                child: const Text('Every 1.5 hours'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => setState(() => _reminderInterval = 2.0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _reminderInterval == 2.0 ? Colors.blue : null,
                ),
                child: const Text('Every 2 hours'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Slider(
            value: _reminderInterval,
            min: 1.0,
            max: 4.0,
            divisions: 6,
            label: '${_reminderInterval.toStringAsFixed(1)} hours',
            onChanged: (value) => setState(() => _reminderInterval = value),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRemindersScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Do You Want Activity-Based Reminders?',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'We can remind you to drink more after workouts or during hot weather.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SwitchListTile(
            title: const Text('Enable workout reminders'),
            value: _enableWorkoutReminders,
            onChanged: (value) => setState(() => _enableWorkoutReminders = value),
          ),
          SwitchListTile(
            title: const Text('Enable weather-based reminders'),
            value: _enableWeatherReminders,
            onChanged: (value) => setState(() => _enableWeatherReminders = value),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextPage,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re All Set!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your daily goal is ${UnitConverter.formatAmount(_dailyGoal, _unitType)} and your first reminder is at ${_wakeUpTime.hour.toString().padLeft(2, '0')}:${_wakeUpTime.minute.toString().padLeft(2, '0')}. Stay hydrated and crush your goals!',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _completeOnboarding,
            child: const Text('Start Hydrating'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (page) => setState(() => _currentPage = page),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomeScreen(),
            _buildUnitSelectionScreen(),
            _buildDailyGoalScreen(),
            _buildScheduleScreen(),
            _buildReminderIntervalScreen(),
            _buildActivityRemindersScreen(),
            _buildConfirmationScreen(),
          ],
        ),
      ),
    );
  }
} 