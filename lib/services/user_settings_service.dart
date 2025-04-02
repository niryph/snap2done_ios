import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSettingsService {
  static final UserSettingsService _instance = UserSettingsService._internal();
  factory UserSettingsService() => _instance;
  UserSettingsService._internal();

  static SupabaseClient get _client => Supabase.instance.client;

  // Get all settings for the current user
  static Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // No settings yet, create default settings
        return _createDefaultSettings();
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error fetching user settings: $e');
      return {};
    }
  }

  // Create default settings for a new user
  static Future<Map<String, dynamic>> _createDefaultSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final defaultSettings = {
        'user_id': userId,
        'daily_budget': 100.00,
        'currency': 'USD',
        'reminder_enabled': false,
        'reminder_time': null,
        'mood_reminders_enabled': false,
        'mood_reminder_time': '09:00',
        'max_gratitude_items': 3,
      };

      final response = await _client
          .from('user_settings')
          .insert(defaultSettings)
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error creating default user settings: $e');
      return {};
    }
  }

  // Update specific settings
  static Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('user_settings')
          .update(newSettings)
          .eq('user_id', userId);

      debugPrint('User settings updated successfully');
    } catch (e) {
      debugPrint('Error updating user settings: $e');
      rethrow;
    }
  }

  // Update a single setting
  static Future<void> updateSetting(String key, dynamic value) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('user_settings')
          .update({key: value})
          .eq('user_id', userId);

      debugPrint('User setting "$key" updated successfully');
    } catch (e) {
      debugPrint('Error updating user setting "$key": $e');
      rethrow;
    }
  }

  // Get a specific setting value with a default fallback
  static Future<T> getSetting<T>(String key, T defaultValue) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return defaultValue;
      }

      final response = await _client
          .from('user_settings')
          .select(key)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || !response.containsKey(key) || response[key] == null) {
        return defaultValue;
      }

      return response[key] as T;
    } catch (e) {
      debugPrint('Error getting user setting "$key": $e');
      return defaultValue;
    }
  }
} 