import 'package:flutter/material.dart';
import '../utils/unit_converter.dart';

enum UnitType {
  fluidOunce,  // US customary (fl oz)
  milliliter   // Metric (ml)
}

class WaterIntakeMetadata {
  final double dailyGoal;
  final Map<String, List<WaterEntry>> dailyEntries;
  final ReminderSettings reminderSettings;
  final UnitType unitType;

  WaterIntakeMetadata({
    this.dailyGoal = 2000.0, // Default 2000ml
    Map<String, List<WaterEntry>>? dailyEntries,
    ReminderSettings? reminderSettings,
    this.unitType = UnitType.fluidOunce, // Default to fluid ounces
  })  : dailyEntries = dailyEntries ?? {},
        reminderSettings = reminderSettings ?? ReminderSettings();

  Map<String, dynamic> toJson() => {
        'dailyGoal': dailyGoal,
        'dailyEntries': dailyEntries.map(
          (key, value) => MapEntry(
            key,
            value.map((entry) => entry.toJson()).toList(),
          ),
        ),
        'reminderSettings': reminderSettings.toJson(),
        'unitType': unitType.index,
      };

  factory WaterIntakeMetadata.fromJson(Map<String, dynamic> json) {
    return WaterIntakeMetadata(
      dailyGoal: json['dailyGoal'] as double? ?? 2000.0,
      dailyEntries: (json['dailyEntries'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List)
                  .map((e) => WaterEntry.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ) ??
          {},
      reminderSettings: json['reminderSettings'] != null
          ? ReminderSettings.fromJson(
              json['reminderSettings'] as Map<String, dynamic>)
          : ReminderSettings(),
      unitType: json['unitType'] != null 
          ? UnitType.values[json['unitType'] as int]
          : UnitType.fluidOunce,
    );
  }
}

class WaterEntry {
  final double amount;
  final DateTime timestamp;

  WaterEntry({
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    return WaterEntry(
      amount: (json['amount'] is int) 
          ? (json['amount'] as int).toDouble() 
          : json['amount'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }
}

class ReminderSettings {
  final bool enabled;
  final int intervalHours;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  ReminderSettings({
    this.enabled = false,
    this.intervalHours = 2,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  })  : startTime = startTime ?? const TimeOfDay(hour: 8, minute: 0),
        endTime = endTime ?? const TimeOfDay(hour: 22, minute: 0);

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'intervalHours': intervalHours,
        'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
        'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
      };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      intervalHours: json['intervalHours'] as int? ?? 2,
      startTime: json['startTime'] != null
          ? TimeOfDay(
              hour: json['startTime']['hour'] as int,
              minute: json['startTime']['minute'] as int,
            )
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay(
              hour: json['endTime']['hour'] as int,
              minute: json['endTime']['minute'] as int,
            )
          : null,
    );
  }
}

class WaterIntakeSettings {
  final double dailyGoal;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final UnitType unitType;
  final bool remindersEnabled;
  final int reminderIntervalHours;

  WaterIntakeSettings({
    this.dailyGoal = 91.0, // Default 91 fl oz
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    this.unitType = UnitType.fluidOunce,
    this.remindersEnabled = false,
    this.reminderIntervalHours = 2,
  })  : startTime = startTime ?? const TimeOfDay(hour: 8, minute: 0),
        endTime = endTime ?? const TimeOfDay(hour: 22, minute: 0);

  Map<String, dynamic> toJson() => {
        'dailyGoal': dailyGoal,
        'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
        'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
        'unitType': unitType.index,
        'remindersEnabled': remindersEnabled,
        'reminderIntervalHours': reminderIntervalHours,
      };

  factory WaterIntakeSettings.fromJson(Map<String, dynamic> json) {
    return WaterIntakeSettings(
      dailyGoal: json['dailyGoal'] as double? ?? 91.0,
      startTime: json['startTime'] != null
          ? TimeOfDay(
              hour: json['startTime']['hour'] as int,
              minute: json['startTime']['minute'] as int,
            )
          : null,
      endTime: json['endTime'] != null
          ? TimeOfDay(
              hour: json['endTime']['hour'] as int,
              minute: json['endTime']['minute'] as int,
            )
          : null,
      unitType: json['unitType'] != null
          ? UnitType.values[json['unitType'] as int]
          : UnitType.fluidOunce,
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      reminderIntervalHours: json['reminderIntervalHours'] as int? ?? 2,
    );
  }
} 