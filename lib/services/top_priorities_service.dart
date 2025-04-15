import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TopPrioritiesService {
  static final _supabase = Supabase.instance.client;
  static final _uuid = Uuid();
  static const _table = 'top_priorities_entries';

  /// Checks if a task exists in the database
  static Future<bool> checkTaskExists(String taskId) async {
    try {
      final result = await _supabase
          .from(_table)
          .select('id')
          .eq('id', taskId)
          .limit(1)
          .maybeSingle();
      return result != null;
    } catch (e) {
      print('Error checking task existence: $e');
      return false;
    }
  }

  /// Gets entries for a specific date
  static Future<List<Map<String, dynamic>>> getEntriesForDate(DateTime date) async {
    try {
      final result = await _supabase
          .from(_table)
          .select()
          .eq('date', date.toIso8601String().split('T')[0])
          .order('position');
      
      // Convert database format to app format
      return List<Map<String, dynamic>>.from(result).map((entry) => {
        'id': entry['id'],
        'description': entry['description'] ?? '',
        'notes': entry['notes'] ?? '',
        'position': entry['position'] ?? 0,
        'isCompleted': entry['is_completed'] ?? false,
        'reminderTime': entry['reminder_time'],
      }).toList();
    } catch (e) {
      print('Error getting entries: $e');
      return [];
    }
  }

  /// Save a single priority entry
  static Future<void> savePriorityEntry(DateTime date, Map<String, dynamic> entry) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Ensure task has an ID
      if (entry['id'] == null) {
        entry['id'] = _uuid.v4();
      }

      // Create task data
      final taskData = {
        'id': entry['id'],
        'user_id': user.id,
        'date': date.toIso8601String().split('T')[0],
        'description': entry['description'] ?? '',
        'notes': entry['notes'] ?? '',
        'position': entry['position'] ?? 0,
        'is_completed': entry['isCompleted'] ?? false,
        'reminder_time': entry['reminderTime'],
      };

      // Upsert the task
      await _supabase
          .from(_table)
          .upsert(taskData);
    } catch (e) {
      print('Error saving entry: $e');
      throw Exception('Failed to save entry: $e');
    }
  }

  /// Saves priority entries for a specific date
  static Future<void> savePriorityEntries(DateTime date, List<Map<String, dynamic>> entries) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // If only one entry is provided, use savePriorityEntry
      if (entries.length == 1) {
        await savePriorityEntry(date, entries[0]);
        return;
      }

      // Delete existing entries for this date and user
      await _supabase
          .from(_table)
          .delete()
          .eq('user_id', user.id)
          .eq('date', date.toIso8601String().split('T')[0]);

      // Prepare tasks for insertion
      final tasksToInsert = entries.map((entry) {
        // Ensure each task has an ID
        if (entry['id'] == null) {
          entry['id'] = _uuid.v4();
        }
        
        return {
          'id': entry['id'],
          'user_id': user.id,
          'date': date.toIso8601String().split('T')[0],
          'description': entry['description'] ?? '',
          'notes': entry['notes'] ?? '',
          'position': entry['position'] ?? 0,
          'is_completed': entry['isCompleted'] ?? false,
          'reminder_time': entry['reminderTime'],
        };
      }).toList();

      // Insert or update tasks
      if (tasksToInsert.isNotEmpty) {
        await _supabase
            .from(_table)
            .upsert(tasksToInsert);
      }
    } catch (e) {
      print('Error saving entries: $e');
      throw Exception('Failed to save entries: $e');
    }
  }

  /// Deletes entries for a specific card
  static Future<void> deleteEntriesForCard(String cardId) async {
    try {
      await _supabase
          .from(_table)
          .delete()
          .eq('card_id', cardId);
    } catch (e) {
      print('Error deleting entries: $e');
      throw Exception('Failed to delete entries: $e');
    }
  }

  /// Deletes a priority entry
  static Future<void> deletePriorityEntry(String id) async {
    try {
      await _supabase
          .from(_table)
          .delete()
          .eq('id', id);
    } catch (e) {
      print('Error deleting entry: $e');
      throw Exception('Failed to delete entry: $e');
    }
  }
} 