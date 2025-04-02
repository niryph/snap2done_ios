import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/water_intake_models.dart';

class WaterReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    _initialized = true;
  }

  static Future<void> scheduleReminders(ReminderSettings settings) async {
    await initialize();
    await _notifications.cancelAll(); // Clear existing reminders

    if (!settings.enabled) return;

    final now = DateTime.now();
    final startTime = DateTime(
      now.year,
      now.month,
      now.day,
      settings.startTime.hour,
      settings.startTime.minute,
    );
    final endTime = DateTime(
      now.year,
      now.month,
      now.day,
      settings.endTime.hour,
      settings.endTime.minute,
    );

    final intervalMinutes = (settings.intervalHours * 60).round();
    var currentTime = startTime;

    int id = 0;
    while (currentTime.isBefore(endTime)) {
      if (currentTime.isAfter(now)) {
        await _scheduleNotification(
          id++,
          currentTime,
          'Time to Hydrate!',
          'Pour yourself a glass of water and stay refreshed. 💧',
        );
      }
      currentTime = currentTime.add(Duration(minutes: intervalMinutes));
    }
  }

  static Future<void> _scheduleNotification(
    int id,
    DateTime scheduledDate,
    String title,
    String body,
  ) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_reminders',
          'Water Reminders',
          channelDescription: 'Reminders to drink water throughout the day',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
} 