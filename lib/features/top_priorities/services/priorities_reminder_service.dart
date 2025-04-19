import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../../services/notification_service.dart';

class PrioritiesReminderService {
  static final PrioritiesReminderService _instance = PrioritiesReminderService._internal();
  final NotificationService _notificationService = NotificationService();
  
  factory PrioritiesReminderService() {
    return _instance;
  }
  
  PrioritiesReminderService._internal() {
    // Initialize timezone data
    tz_data.initializeTimeZones();
  }
  
  /// Schedule a daily reminder for top priorities
  Future<void> scheduleDailyReminder({
    required String cardId,
    required TimeOfDay reminderTime,
  }) async {
    // Cancel any existing reminders for this card
    await cancelReminder(cardId);
    
    // Get the next occurrence of the reminder time
    final now = DateTime.now();
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      reminderTime.hour,
      reminderTime.minute,
    );
    
    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(Duration(days: 1));
    }
    
    // Schedule the notification
    await _notificationService.scheduleTaskReminder(
      taskId: 'top_priorities_$cardId',
      title: 'Daily Top Priorities',
      body: 'Set your top priorities for today',
      scheduledDate: scheduledDate,
    );
    
    print('Scheduled top priorities reminder for ${scheduledDate.toString()}');
  }
  
  /// Cancel the daily reminder for top priorities
  Future<void> cancelReminder(String cardId) async {
    await _notificationService.cancelNotification('top_priorities_$cardId');
  }
  
  /// Parse a time string in format 'HH:MM' to TimeOfDay
  TimeOfDay parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
  
  /// Format TimeOfDay to a string in format 'HH:MM'
  String formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
} 