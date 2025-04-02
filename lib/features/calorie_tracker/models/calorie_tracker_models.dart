import 'package:flutter/material.dart';

class CalorieTrackerMetadata {
  final double dailyGoal;
  final Map<String, List<FoodEntry>> dailyEntries;
  final ReminderSettings reminderSettings;
  final Map<String, double> macroGoals; // Percentages for carbs, protein, fat

  CalorieTrackerMetadata({
    this.dailyGoal = 2000.0, // Default 2000 kcal
    Map<String, List<FoodEntry>>? dailyEntries,
    ReminderSettings? reminderSettings,
    Map<String, double>? macroGoals,
  })  : dailyEntries = dailyEntries ?? {},
        reminderSettings = reminderSettings ?? ReminderSettings(),
        macroGoals = macroGoals ?? {'carbs': 50.0, 'protein': 30.0, 'fat': 20.0};

  Map<String, dynamic> toJson() => {
        'dailyGoal': dailyGoal,
        'dailyEntries': dailyEntries.map(
          (key, value) => MapEntry(
            key,
            value.map((entry) => entry.toMap()).toList(),
          ),
        ),
        'reminderSettings': reminderSettings.toJson(),
        'macroGoals': macroGoals,
      };

  factory CalorieTrackerMetadata.fromJson(Map<String, dynamic> json) {
    return CalorieTrackerMetadata(
      dailyGoal: json['dailyGoal'] is int 
          ? (json['dailyGoal'] as int).toDouble() 
          : json['dailyGoal'] as double? ?? 2000.0,
      dailyEntries: (json['dailyEntries'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List)
                  .map((e) => FoodEntry.fromMap(e as Map<String, dynamic>))
                  .toList(),
            ),
          ) ??
          {},
      reminderSettings: json['reminderSettings'] != null
          ? ReminderSettings.fromJson(
              json['reminderSettings'] as Map<String, dynamic>)
          : ReminderSettings(),
      macroGoals: (json['macroGoals'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key, 
              value is int ? value.toDouble() : value as double
            ),
          ) ??
          {'carbs': 50.0, 'protein': 30.0, 'fat': 20.0},
    );
  }
}

class FoodEntry {
  final String id;
  final String name;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final DateTime timestamp;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  factory FoodEntry.fromMap(Map<String, dynamic> map) {
    return FoodEntry(
      id: map['id'] as String,
      name: map['name'] as String,
      calories: map['calories'] as int,
      carbs: (map['carbs'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String).toLocal(),
    );
  }
}

class ReminderSettings {
  final bool enabled;
  final List<TimeOfDay> mealTimes; // Times for breakfast, lunch, dinner reminders

  ReminderSettings({
    this.enabled = false,
    List<TimeOfDay>? mealTimes,
  }) : mealTimes = mealTimes ?? [
          const TimeOfDay(hour: 8, minute: 0),  // Breakfast
          const TimeOfDay(hour: 12, minute: 30), // Lunch
          const TimeOfDay(hour: 18, minute: 0),  // Dinner
        ];

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'mealTimes': mealTimes.map((time) => {
              'hour': time.hour,
              'minute': time.minute,
            }).toList(),
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      mealTimes: json['mealTimes'] != null
          ? (json['mealTimes'] as List).map((time) => TimeOfDay(
                hour: time['hour'] as int,
                minute: time['minute'] as int,
              )).toList()
          : null,
    );
  }
}

// Predefined meal types for quick logging
class MealType {
  static const String breakfast = 'Breakfast';
  static const String lunch = 'Lunch';
  static const String dinner = 'Dinner';
  static const String snack = 'Snack';
  
  static List<String> values = [breakfast, lunch, dinner, snack];
}

class CalorieTrackerSettings {
  final int dailyGoal;
  final Map<String, double> macroGoals;
  final bool enableReminders;
  final List<String> reminderTimes;

  CalorieTrackerSettings({
    this.dailyGoal = 2000,
    Map<String, double>? macroGoals,
    this.enableReminders = false,
    List<String>? reminderTimes,
  }) : macroGoals = macroGoals ?? {
          'carbs': 50.0,
          'protein': 30.0,
          'fat': 20.0,
        },
       reminderTimes = reminderTimes ?? ['09:00', '13:00', '19:00'];

  Map<String, dynamic> toMap() {
    return {
      'daily_goal': dailyGoal,
      'macro_goals': macroGoals,
      'enable_reminders': enableReminders,
      'reminder_times': reminderTimes,
    };
  }

  factory CalorieTrackerSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return CalorieTrackerSettings();
    
    return CalorieTrackerSettings(
      dailyGoal: map['daily_goal'] as int? ?? 2000,
      macroGoals: Map<String, double>.from(map['macro_goals'] as Map? ?? {}),
      enableReminders: map['enable_reminders'] as bool? ?? false,
      reminderTimes: List<String>.from(map['reminder_times'] as List? ?? []),
    );
  }
} 