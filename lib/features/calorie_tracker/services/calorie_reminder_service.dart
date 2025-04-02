import 'package:flutter/material.dart';
import '../../../services/notification_service.dart';

class CalorieReminderService {
  // Singleton pattern
  static final CalorieReminderService _instance = CalorieReminderService._internal();
  factory CalorieReminderService() => _instance;
  CalorieReminderService._internal();
  
  static const String _reminderChannelId = 'calorie_tracker_reminders';
  static const String _reminderChannelName = 'Meal Reminders';
  static const String _reminderChannelDescription = 'Notifications for meal logging reminders';
  
  Future<void> initialize() async {
    await NotificationService().createNotificationChannel(
      _reminderChannelId,
      _reminderChannelName,
      _reminderChannelDescription,
    );
  }
  
  Future<void> scheduleReminders(String cardId, List<Map<String, int>> mealTimes, bool enabled) async {
    // Cancel existing reminders first
    await cancelReminders(cardId);
    
    if (!enabled) return;
    
    // Schedule new reminders
    for (int i = 0; i < mealTimes.length; i++) {
      final mealTime = mealTimes[i];
      final hour = mealTime['hour'] ?? 0;
      final minute = mealTime['minute'] ?? 0;
      
      String mealName = 'meal';
      if (i == 0) mealName = 'breakfast';
      else if (i == 1) mealName = 'lunch';
      else if (i == 2) mealName = 'dinner';
      else if (i == 3) mealName = 'snack';
      
      final notificationId = _getNotificationId(cardId, i);
      
      await NotificationService().scheduleRepeatingNotification(
        id: notificationId,
        title: 'Time to log your $mealName',
        body: 'Don\'t forget to track your calories and macros',
        channelId: _reminderChannelId,
        hour: hour,
        minute: minute,
        payload: {
          'type': 'calorie_tracker',
          'action': 'log_meal',
          'card_id': cardId,
          'meal_type': mealName,
        },
      );
    }
  }
  
  Future<void> cancelReminders(String cardId) async {
    // Cancel all possible meal reminders (up to 5)
    for (int i = 0; i < 5; i++) {
      final notificationId = _getNotificationId(cardId, i);
      await NotificationService().cancelNotification(notificationId);
    }
  }
  
  int _getNotificationId(String cardId, int index) {
    // Create a unique notification ID based on the card ID and meal index
    // This allows us to cancel specific reminders later
    final cardIdHash = cardId.hashCode;
    return cardIdHash + index;
  }
} 