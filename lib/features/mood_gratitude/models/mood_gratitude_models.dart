import 'package:flutter/material.dart';

class MoodEntry {
  final String? id;
  final DateTime date;
  final String mood;
  final String? moodNotes;
  final List<String> gratitudeItems;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MoodEntry({
    this.id,
    required this.date,
    required this.mood,
    this.moodNotes,
    required this.gratitudeItems,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mood': mood,
      'moodNotes': moodNotes,
      'gratitudeItems': gratitudeItems,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as String?,
      date: DateTime.parse(map['date'] as String),
      mood: map['mood'] as String,
      moodNotes: map['moodNotes'] as String?,
      gratitudeItems: List<String>.from(map['gratitudeItems'] ?? []),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }
  
  // Add a helper method to get just the date part for easier comparison
  String get dateString => 
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  
  // Override equality for better comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    
    final MoodEntry otherEntry = other as MoodEntry;
    return dateString == otherEntry.dateString && 
           mood == otherEntry.mood;
  }
  
  @override
  int get hashCode => dateString.hashCode ^ mood.hashCode;
}

class MoodGratitudeSettings {
  final String? id;
  final String? userId;
  final bool remindersEnabled;
  final TimeOfDay reminderTime;
  final int maxGratitudeItems;
  final List<String> favoriteMoods;
  final bool notificationEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MoodGratitudeSettings({
    this.id,
    this.userId,
    required this.remindersEnabled,
    required this.reminderTime,
    this.maxGratitudeItems = 3,
    this.favoriteMoods = const ["Happy", "Good", "Neutral", "Sad", "Angry"],
    this.notificationEnabled = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'reminders_enabled': remindersEnabled,
      'reminder_time': '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}',
      'max_gratitude_items': maxGratitudeItems,
      'favorite_moods': favoriteMoods,
      'notification_enabled': notificationEnabled,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // For inserting into the database, omitting id and timestamps
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'reminders_enabled': remindersEnabled,
      'reminder_time': '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}',
      'max_gratitude_items': maxGratitudeItems,
      'favorite_moods': favoriteMoods,
      'notification_enabled': notificationEnabled,
    };
  }

  factory MoodGratitudeSettings.fromMap(Map<String, dynamic> map) {
    final timeString = map['reminder_time'] ?? '9:00';
    final timeParts = timeString.toString().split(':');
    
    List<String> parseFavoriteMoods(dynamic moodsData) {
      if (moodsData == null) {
        return ["Happy", "Good", "Neutral", "Sad", "Angry"];
      }
      
      if (moodsData is List) {
        return List<String>.from(moodsData);
      }
      
      try {
        // Handle PostgreSQL array format if it comes as a string
        if (moodsData is String && moodsData.startsWith('{') && moodsData.endsWith('}')) {
          final trimmed = moodsData.substring(1, moodsData.length - 1);
          return trimmed.split(',').map((s) => s.trim().replaceAll('"', '')).toList();
        }
      } catch (e) {
        print('Error parsing favorite moods: $e');
      }
      
      return ["Happy", "Good", "Neutral", "Sad", "Angry"];
    }
    
    return MoodGratitudeSettings(
      id: map['id'],
      userId: map['user_id'],
      remindersEnabled: map['reminders_enabled'] ?? true,
      reminderTime: TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? 9, 
        minute: int.tryParse(timeParts[1]) ?? 0
      ),
      maxGratitudeItems: map['max_gratitude_items'] ?? 3,
      favoriteMoods: parseFavoriteMoods(map['favorite_moods']),
      notificationEnabled: map['notification_enabled'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  // Create settings with database-friendly field names
  factory MoodGratitudeSettings.fromDatabaseMap(Map<String, dynamic> map) {
    return MoodGratitudeSettings.fromMap(map);
  }

  // Create a copy with updated values
  MoodGratitudeSettings copyWith({
    String? id,
    String? userId,
    bool? remindersEnabled,
    TimeOfDay? reminderTime,
    int? maxGratitudeItems,
    List<String>? favoriteMoods,
    bool? notificationEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoodGratitudeSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      maxGratitudeItems: maxGratitudeItems ?? this.maxGratitudeItems,
      favoriteMoods: favoriteMoods ?? this.favoriteMoods,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MoodGratitudeSettings.defaultSettings() {
    return MoodGratitudeSettings(
      remindersEnabled: true,
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
      maxGratitudeItems: 3,
      favoriteMoods: const ["Happy", "Good", "Neutral", "Sad", "Angry"],
      notificationEnabled: true,
    );
  }
}