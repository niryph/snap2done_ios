import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final BehaviorSubject<String?> onNotificationClick = BehaviorSubject();
  
  // Permission status
  bool _permissionGranted = false;
  
  NotificationService._internal();
  
  // Initialize the notification service
  Future<void> initialize() async {
    developer.log('Initializing notification service', name: 'NotificationService');
    
    try {
      // Initialize timezone
      tz_init.initializeTimeZones();
      final String timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      
      // Initialize notification settings
      const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      final darwinInitSettings = DarwinInitializationSettings(
        requestAlertPermission: false,  // We'll request permissions separately
        requestBadgePermission: false,
        requestSoundPermission: false,
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );
      
      final initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: darwinInitSettings,
        macOS: darwinInitSettings,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      
      // For macOS, try to show a test notification to check permission
      if (Platform.isMacOS) {
        try {
          await flutterLocalNotificationsPlugin.show(
            -999,  // Use a unique ID for permission test
            '',
            '',
            null,
          );
          _permissionGranted = true;
          developer.log('macOS notifications are allowed', name: 'NotificationService');
          
          // Clean up the test notification
          await flutterLocalNotificationsPlugin.cancel(-999);
          
          // Save the permission status
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('notification_permission_granted', true);
        } catch (e) {
          _permissionGranted = false;
          developer.log('macOS notifications are not allowed: $e', name: 'NotificationService');
          
          // Save the permission status
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('notification_permission_granted', false);
        }
      } else {
        // For other platforms, check saved permission status
        final prefs = await SharedPreferences.getInstance();
        _permissionGranted = prefs.getBool('notification_permission_granted') ?? false;
      }
      
      developer.log('Notification service initialized, permission granted: $_permissionGranted', name: 'NotificationService');
    } catch (e) {
      developer.log('Error initializing notification service: $e', name: 'NotificationService');
      rethrow;  // Rethrow to let the caller handle the error
    }
  }
  
  // Request permission for notifications
  Future<bool> requestPermission() async {
    developer.log('Requesting notification permission', name: 'NotificationService');
    
    try {
      if (Platform.isMacOS) {
        // For macOS, try to show a test notification to verify permission
        try {
          await flutterLocalNotificationsPlugin.show(
            -998,  // Use a unique ID for permission test
            '',
            '',
            null,
          );
          
          // If we get here, notifications are allowed
          _permissionGranted = true;
          
          // Clean up the test notification
          await flutterLocalNotificationsPlugin.cancel(-998);
          
          // Save the permission status
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('notification_permission_granted', true);
          
          developer.log('macOS notification permission granted', name: 'NotificationService');
          return true;
        } catch (e) {
          _permissionGranted = false;
          
          // Save the permission status
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('notification_permission_granted', false);
          
          developer.log('macOS notification permission denied: $e', name: 'NotificationService');
          return false;
        }
      } else if (Platform.isIOS) {
        // Request permissions using IOSFlutterLocalNotificationsPlugin
        final settings = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            ) ?? false;
            
        _permissionGranted = settings;
        
        // Save the permission status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notification_permission_granted', settings);
        
        developer.log('iOS notification permission result: $settings', name: 'NotificationService');
        return settings;
      } else if (Platform.isAndroid) {
        // For Android, we need to check if notification channel exists
        final androidImplementation = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
            
        // On Android, we'll create the notification channel which implicitly enables notifications
        const androidChannel = AndroidNotificationChannel(
          'task_reminder_channel',
          'Task Reminders',
          description: 'Notifications for task reminders',
          importance: Importance.high,
        );

        await androidImplementation?.createNotificationChannel(androidChannel);
        
        // On Android, creating the channel is enough to enable notifications
        _permissionGranted = true;
        
        // Save the permission status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notification_permission_granted', true);
        
        developer.log('Android notification channel created', name: 'NotificationService');
        return true;
      }
      
      // For other platforms, assume permission is granted
      _permissionGranted = true;
      
      // Save the permission status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_granted', true);
      
      developer.log('Permission granted for other platform', name: 'NotificationService');
      return true;
    } catch (e) {
      developer.log('Error requesting notification permission: $e', name: 'NotificationService');
      return false;
    }
  }
  
  // Save permission status to shared preferences
  Future<void> _savePermissionStatus() async {
    try {
      developer.log('Saving notification permission status: $_permissionGranted', name: 'NotificationService');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_permission_granted', _permissionGranted);
      developer.log('Successfully saved notification permission status', name: 'NotificationService');
    } catch (e) {
      developer.log('Error saving notification permission status: $e', name: 'NotificationService');
    }
  }
  
  // Check if permission is granted
  bool get isPermissionGranted => _permissionGranted;
  
  // Ensure permissions are granted before scheduling notifications
  Future<bool> ensurePermissionsGranted() async {
    developer.log('Ensuring notification permissions are granted', name: 'NotificationService');
    
    // Always request permission to ensure it's up to date
    final permissionGranted = await requestPermission();
    
    if (permissionGranted) {
      developer.log('Successfully granted notification permissions', name: 'NotificationService');
    } else {
      developer.log('Failed to grant notification permissions', name: 'NotificationService');
    }
    
    return permissionGranted;
  }
  
  // Handle notification when app is in foreground (iOS)
  void _onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) {
    developer.log('Received local notification: $title', name: 'NotificationService');
    onNotificationClick.add(payload);
  }
  
  // Handle notification response when user taps on notification
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    developer.log('Notification clicked: ${response.payload}', name: 'NotificationService');
    onNotificationClick.add(response.payload);
  }
  
  // Schedule a notification for a task
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      developer.log('Attempting to schedule notification for task $taskId', name: 'NotificationService');
      
      // Double-check permission status
      if (!_permissionGranted) {
        developer.log('Permission not granted, requesting permission...', name: 'NotificationService');
        final permissionGranted = await requestPermission();
        if (!permissionGranted) {
          developer.log('Permission request failed, cannot schedule notification', name: 'NotificationService');
          return;
        }
        developer.log('Permission granted after request', name: 'NotificationService');
      }
      
      developer.log('Scheduling notification for task $taskId at $scheduledDate', name: 'NotificationService');
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'task_reminder_channel',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('completion'),
        playSound: true,
      );
      
      final iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'completion.mp3',
      );
      
      // Add macOS notification details
      final macOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'completion.mp3',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
        macOS: macOSDetails, // Add macOS details
      );
      
      // Schedule the notification
      final notificationId = taskId.hashCode;
      developer.log('Using notification ID: $notificationId for task $taskId', name: 'NotificationService');
      
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId, // Use task ID hash as notification ID
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: taskId,
      );
      
      developer.log('Successfully scheduled notification for task $taskId at $scheduledDate', name: 'NotificationService');
    } catch (e) {
      developer.log('Error scheduling notification: $e', name: 'NotificationService');
    }
  }
  
  // Cancel a specific notification
  Future<void> cancelNotification(String taskId) async {
    await flutterLocalNotificationsPlugin.cancel(taskId.hashCode);
    developer.log('Cancelled notification for task $taskId', name: 'NotificationService');
  }
  
  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    developer.log('Cancelled all notifications', name: 'NotificationService');
  }
  
  // Show an immediate test notification
  Future<void> showTestNotification() async {
    try {
      developer.log('Attempting to show test notification', name: 'NotificationService');
      
      // Double-check permission status
      if (!_permissionGranted) {
        developer.log('Permission not granted, requesting permission...', name: 'NotificationService');
        final permissionGranted = await requestPermission();
        if (!permissionGranted) {
          developer.log('Permission request failed, cannot show test notification', name: 'NotificationService');
          return;
        }
        developer.log('Permission granted after request', name: 'NotificationService');
      }
      
      developer.log('Showing test notification', name: 'NotificationService');
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'task_reminder_channel',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('completion'),
        playSound: true,
      );
      
      final iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'completion.mp3',
      );
      
      final macOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'completion.mp3',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
        macOS: macOSDetails, // Add macOS details
      );
      
      // Show the notification immediately
      await flutterLocalNotificationsPlugin.show(
        0, // Use a fixed ID for test notifications
        'Test Notification',
        'This is a test notification from Snap2Done',
        notificationDetails,
        payload: 'test_notification',
      );
      
      developer.log('Successfully showed test notification', name: 'NotificationService');
    } catch (e) {
      developer.log('Error showing test notification: $e', name: 'NotificationService');
    }
  }
  
  // Schedule a test notification with countdown
  Future<void> scheduleTestNotification(int seconds) async {
    try {
      developer.log('Attempting to schedule test notification', name: 'NotificationService');
      
      // Double-check permission status
      if (!_permissionGranted) {
        developer.log('Permission not granted, requesting permission...', name: 'NotificationService');
        final permissionGranted = await requestPermission();
        if (!permissionGranted) {
          developer.log('Permission request failed, cannot schedule test notification', name: 'NotificationService');
          return;
        }
        developer.log('Permission granted after request', name: 'NotificationService');
      }
      
      developer.log('Scheduling test notification for $seconds seconds from now', name: 'NotificationService');
      
      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'task_reminder_channel',
        'Task Reminders',
        channelDescription: 'Notifications for task reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('completion'),
        playSound: true,
      );
      
      final iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'completion.mp3',
      );
      
      final macOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'completion.mp3',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
        macOS: macOSDetails, // Add macOS details
      );
      
      // Schedule the notification
      final scheduledDate = DateTime.now().add(Duration(seconds: seconds));
      developer.log('Scheduled date: $scheduledDate', name: 'NotificationService');
      
      // First try to show an immediate notification as a fallback
      await flutterLocalNotificationsPlugin.show(
        998, // Use a different ID for immediate test notification
        'Test Notification (Immediate)',
        'This is an immediate test notification from Snap2Done',
        notificationDetails,
        payload: 'test_notification_immediate',
      );
      
      developer.log('Successfully showed immediate test notification', name: 'NotificationService');
      
      // Then try to schedule the notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        999, // Use a fixed ID for test notifications
        'Test Notification (Scheduled)',
        'This is a scheduled test notification from Snap2Done',
        tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_notification_scheduled',
      );
      
      developer.log('Successfully scheduled test notification for $seconds seconds from now', name: 'NotificationService');
    } catch (e) {
      developer.log('Error scheduling test notification: $e', name: 'NotificationService');
      // Try one more time with a simpler approach
      try {
        await flutterLocalNotificationsPlugin.show(
          997, // Use a different ID for fallback notification
          'Test Notification (Fallback)',
          'This is a fallback test notification from Snap2Done',
          null, // Use default notification details
          payload: 'test_notification_fallback',
        );
        developer.log('Successfully showed fallback test notification', name: 'NotificationService');
      } catch (innerError) {
        developer.log('Error showing fallback notification: $innerError', name: 'NotificationService');
      }
    }
  }
  
  // Get time remaining until a scheduled notification (for UI display)
  String getTimeRemainingText(DateTime scheduledDate) {
    final now = DateTime.now();
    final difference = scheduledDate.difference(now);
    
    if (difference.isNegative) {
      return 'Overdue';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d remaining';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h remaining';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m remaining';
    } else {
      return 'Less than a minute';
    }
  }
} 