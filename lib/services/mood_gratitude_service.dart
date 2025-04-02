import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/mood_gratitude/models/mood_gratitude_models.dart';

class MoodGratitudeService {
  static final MoodGratitudeService _instance = MoodGratitudeService._internal();
  factory MoodGratitudeService() => _instance;
  MoodGratitudeService._internal();

  static SupabaseClient get _client => Supabase.instance.client;

  // Save a mood entry to both the database and card metadata
  static Future<Map<String, dynamic>> saveEntry(MoodEntry entry) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Save to mood_gratitude_entries table
      final response = await _client
          .from('mood_gratitude_entries')
          .insert({
            'user_id': userId,
            'date': entry.dateString,
            'mood': entry.mood,
            'mood_notes': entry.moodNotes,
            'gratitude_items': entry.gratitudeItems,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Return the entry with the new ID
      return {
        ...entry.toMap(),
        'id': response['id'],
      };
    } catch (e) {
      debugPrint('Error saving mood entry: $e');
      throw Exception('Failed to save mood entry: $e');
    }
  }

  static Future<Map<String, dynamic>> updateEntry(String id, MoodEntry entry) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('MoodGratitudeService: Updating entry with ID: $id');
      debugPrint('MoodGratitudeService: New mood: ${entry.mood}');

      // Update in mood_gratitude_entries table
      final response = await _client
          .from('mood_gratitude_entries')
          .update({
            'mood': entry.mood,
            'mood_notes': entry.moodNotes,
            'gratitude_items': entry.gratitudeItems,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();

      debugPrint('MoodGratitudeService: Entry updated in database');

      // Return the updated entry with its ID
      return {
        ...entry.toMap(),
        'id': response['id'],
        'updated_at': response['updated_at'],
      };
    } catch (e) {
      debugPrint('Error updating mood entry: $e');
      throw Exception('Failed to update mood entry: $e');
    }
  }

  static Future<void> deleteEntry(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('mood_gratitude_entries')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting mood entry: $e');
      throw Exception('Failed to delete mood entry: $e');
    }
  }

  // Get mood entries for a user
  static Future<List<MoodEntry>> getEntries({DateTime? startDate}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = _client
          .from('mood_gratitude_entries')
          .select()
          .eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((map) {
        return MoodEntry(
          id: map['id'],
          date: DateTime.parse(map['date']),
          mood: map['mood'],
          moodNotes: map['mood_notes'],
          gratitudeItems: List<String>.from(map['gratitude_items'] ?? []),
          createdAt: DateTime.parse(map['created_at']),
          updatedAt: DateTime.parse(map['updated_at']),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting mood entries: $e');
      throw Exception('Failed to get mood entries: $e');
    }
  }

  // Get mood entry for a specific date
  static Future<MoodEntry?> getEntryForDate(DateTime date) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      // Normalize to just the date part - YYYY-MM-DD format
      final dateString = date.toIso8601String().split('T')[0];
      
      // Use select() and limit(1) to avoid the PostgrestException
      // if multiple entries exist for the same date
      final response = await _client
          .from('mood_gratitude_entries')
          .select()
          .eq('user_id', userId)
          .eq('date', dateString)
          .order('created_at', ascending: false) // Get the most recent entry
          .limit(1) // Only get one entry
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // Use the MoodEntry constructor with normalized date
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      return MoodEntry(
        date: normalizedDate,
        mood: response['mood'],
        moodNotes: response['mood_notes'],
        gratitudeItems: List<String>.from(response['gratitude_items']),
        createdAt: DateTime.parse(response['created_at']),
      );
    } catch (e) {
      debugPrint('Error fetching mood entry for date: $e');
      return null;
    }
  }

  // Save mood gratitude settings
  static Future<MoodGratitudeSettings> saveMoodGratitudeSettings(MoodGratitudeSettings settings) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Update the user ID in settings if not already set
      final updatedSettings = settings.userId == null 
          ? settings.copyWith(userId: userId)
          : settings;
      
      debugPrint('MoodGratitudeService: Saving settings for user: $userId');

      // Check if settings exist for this user
      final existingSettings = await _client
          .from('mood_gratitude_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      Map<String, dynamic> response;
      
      if (existingSettings == null) {
        // Insert new settings
        debugPrint('MoodGratitudeService: Creating new settings');
        response = await _client
            .from('mood_gratitude_settings')
            .insert(updatedSettings.toInsertMap())
            .select()
            .single();
      } else {
        // Update existing settings
        debugPrint('MoodGratitudeService: Updating existing settings with ID: ${existingSettings['id']}');
        response = await _client
            .from('mood_gratitude_settings')
            .update({
              'reminders_enabled': updatedSettings.remindersEnabled,
              'reminder_time': '${updatedSettings.reminderTime.hour.toString().padLeft(2, '0')}:${updatedSettings.reminderTime.minute.toString().padLeft(2, '0')}',
              'max_gratitude_items': updatedSettings.maxGratitudeItems,
              'favorite_moods': updatedSettings.favoriteMoods,
              'notification_enabled': updatedSettings.notificationEnabled,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .select()
            .single();
      }

      debugPrint('MoodGratitudeService: Settings saved successfully');
      
      // Return the updated settings from the database
      return MoodGratitudeSettings.fromDatabaseMap(response);
    } catch (e) {
      debugPrint('Error saving mood gratitude settings: $e');
      rethrow;
    }
  }

  // Get mood gratitude settings
  static Future<MoodGratitudeSettings> getMoodGratitudeSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('MoodGratitudeService: User not authenticated, returning default settings');
        return MoodGratitudeSettings.defaultSettings();
      }

      debugPrint('MoodGratitudeService: Fetching settings for user: $userId');
      
      final response = await _client
          .from('mood_gratitude_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('MoodGratitudeService: No settings found, creating default');
        // No settings found, create and save default settings
        final defaultSettings = MoodGratitudeSettings.defaultSettings().copyWith(userId: userId);
        return await saveMoodGratitudeSettings(defaultSettings);
      }

      debugPrint('MoodGratitudeService: Settings found: ${response.toString()}');
      return MoodGratitudeSettings.fromDatabaseMap(response);
    } catch (e) {
      debugPrint('Error fetching mood gratitude settings: $e');
      return MoodGratitudeSettings.defaultSettings();
    }
  }
  
  // Delete mood gratitude settings
  static Future<void> deleteMoodGratitudeSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('MoodGratitudeService: User not authenticated, cannot delete settings');
        throw Exception('User not authenticated');
      }

      debugPrint('MoodGratitudeService: Deleting settings for user: $userId');
      
      await _client
          .from('mood_gratitude_settings')
          .delete()
          .eq('user_id', userId);
          
      debugPrint('MoodGratitudeService: Settings deleted successfully');
    } catch (e) {
      debugPrint('Error deleting mood gratitude settings: $e');
      rethrow;
    }
  }
  
  // Migrate settings from user_settings to mood_gratitude_settings
  static Future<MoodGratitudeSettings?> migrateSettingsFromUserSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('MoodGratitudeService: User not authenticated, cannot migrate settings');
        return null;
      }
      
      // First check if settings already exist in the dedicated table
      final existingSettings = await _client
          .from('mood_gratitude_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
          
      if (existingSettings != null) {
        debugPrint('MoodGratitudeService: Settings already exist in dedicated table, no migration needed');
        return MoodGratitudeSettings.fromDatabaseMap(existingSettings);
      }
      
      // Get settings from user_settings table
      final userSettings = await _client
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
          
      if (userSettings == null) {
        debugPrint('MoodGratitudeService: No user_settings found, creating default in dedicated table');
        return await saveMoodGratitudeSettings(MoodGratitudeSettings.defaultSettings().copyWith(userId: userId));
      }
      
      // Parse settings from user_settings
      final timeString = userSettings['mood_reminder_time'] as String? ?? '09:00';
      final timeParts = timeString.split(':');
      final hour = int.tryParse(timeParts[0]) ?? 9;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      
      final settings = MoodGratitudeSettings(
        userId: userId,
        remindersEnabled: userSettings['mood_reminders_enabled'] ?? false,
        reminderTime: TimeOfDay(hour: hour, minute: minute),
        maxGratitudeItems: userSettings['max_gratitude_items'] ?? 3,
      );
      
      // Save to dedicated table
      debugPrint('MoodGratitudeService: Migrating settings from user_settings to dedicated table');
      return await saveMoodGratitudeSettings(settings);
    } catch (e) {
      debugPrint('Error migrating mood gratitude settings: $e');
      return null;
    }
  }
} 