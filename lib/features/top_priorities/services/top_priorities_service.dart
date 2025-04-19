import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/top_priorities_entry_model.dart';
import '../models/top_priorities_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/card_service.dart';

class TopPrioritiesService {
  static final _supabase = Supabase.instance.client;
  static const String _table = 'top_priorities_entries';

  // Get entries for a specific date
  static Future<List<Map<String, dynamic>>> getEntriesForDate(DateTime date, {String? cardId}) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Format date as YYYY-MM-DD to match the format used in savePriorityEntries
    final dateStr = date.toIso8601String().split('T')[0];
    print('Getting entries for date: $dateStr');

    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', user.id)
        .eq('date', dateStr)
        .order('position');

    print('Found ${response.length} entries for date $dateStr');

    // Convert database format to app format
    final result = List<Map<String, dynamic>>.from(response).map((entry) => {
      'id': entry['id'],
      'description': entry['description'] ?? '',
      'notes': entry['notes'] ?? [],
      'position': entry['position'] ?? 0,
      'isCompleted': entry['is_completed'] ?? false,
      'reminderTime': entry['reminder_time'],
      'metadata': {
        'type': 'top_priority',
        'order': (entry['position'] ?? 0) + 1,
      },
    }).toList();

    return result;
  }

  // Get entries for a date range
  static Future<List<Map<String, dynamic>>> getEntriesForDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', user.id)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String())
        .order('date')
        .order('position');

    return List<Map<String, dynamic>>.from(response);
  }

  // Save a single priority entry
  static Future<void> savePriorityEntry({
    required String id,
    required DateTime date,
    required String description,
    required dynamic notes,
    required int position,
    required bool isCompleted,
    String? reminderTime,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Format date as YYYY-MM-DD for consistency
    final dateStr = date.toIso8601String().split('T')[0];

    final data = {
      'id': id,
      'user_id': user.id,
      'date': dateStr,
      'description': description,
      'notes': notes,
      'position': position,
      'is_completed': isCompleted,
      'reminder_time': reminderTime,
    };

    await _supabase
        .from(_table)
        .upsert(data)
        .select()
        .single();
  }

  // Save multiple priority entries for a date
  static Future<void> savePriorityEntries(
    DateTime date,
    List<Map<String, dynamic>> entries,
  ) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Format date as YYYY-MM-DD for consistency
    final dateStr = date.toIso8601String().split('T')[0];
    print('Saving ${entries.length} entries for date: $dateStr');

    // Delete existing entries for this date and user
    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('date', dateStr);

    // Insert new entries
    if (entries.isNotEmpty) {
      final data = entries.map((entry) => {
        'id': entry['id'],
        'user_id': user.id,
        'date': dateStr,
        'description': entry['description'] ?? '',
        'notes': entry['notes'] ?? [],
        'position': entry['position'] ?? 0,
        'is_completed': entry['isCompleted'] ?? false,
        'reminder_time': entry['reminderTime'],
      }).toList();

      await _supabase
          .from(_table)
          .upsert(data);

      print('Saved ${entries.length} entries for date $dateStr');
    }
  }

  // Delete entries for a specific date
  static Future<void> deleteEntriesForDate(DateTime date) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Format date as YYYY-MM-DD for consistency
    final dateStr = date.toIso8601String().split('T')[0];

    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('date', dateStr);
  }

  // Delete entries for a specific card
  static Future<void> deleteEntriesForCard(String cardId) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Since we don't have card_id column, we'll need to rely on metadata in the card
    // to find the dates for which we need to delete entries
    final card = await CardService.getCardById(cardId);
    if (card?.metadata != null && card!.metadata!['priorities'] != null) {
      final priorities = card.metadata!['priorities'] as Map<String, dynamic>;
      for (final dateKey in priorities.keys) {
        final date = TopPrioritiesModel.keyToDate(dateKey);
        await deleteEntriesForDate(date);
      }
    }
  }

  // Get default tasks for a new entry
  static List<TopPriorityTask> getDefaultTasks() {
    return List.generate(3, (index) => TopPriorityTask(
      description: '',
      position: index,
    ));
  }
}