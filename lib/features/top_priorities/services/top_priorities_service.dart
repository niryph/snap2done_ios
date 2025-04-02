import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/top_priorities_entry_model.dart';
import '../../../services/auth_service.dart';

class TopPrioritiesService {
  static final _supabase = Supabase.instance.client;
  static const String _table = 'top_priorities_entries';

  // Get entries for a specific date
  static Future<List<Map<String, dynamic>>> getEntriesForDate(DateTime date) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from(_table)
        .select()
        .eq('user_id', user.id)
        .eq('date', date.toIso8601String())
        .order('position');

    return List<Map<String, dynamic>>.from(response);
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
    required String notes,
    required int position,
    required bool isCompleted,
    String? reminderTime,
  }) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final data = {
      'id': id,
      'user_id': user.id,
      'date': date.toIso8601String(),
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
  static Future<void> savePriorityEntries(DateTime date, List<Map<String, dynamic>> entries) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Delete existing entries for this date
    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('date', date.toIso8601String());

    // Insert new entries
    if (entries.isNotEmpty) {
      final data = entries.map((entry) => {
        'id': entry['id'],
        'user_id': user.id,
        'date': date.toIso8601String(),
        'description': entry['description'] ?? '',
        'notes': entry['notes'] ?? '',
        'position': entry['position'] ?? 0,
        'is_completed': entry['isCompleted'] ?? false,
        'reminder_time': entry['reminderTime'],
      }).toList();

      await _supabase
          .from(_table)
          .upsert(data);
    }
  }

  // Delete entries for a specific date
  static Future<void> deleteEntriesForDate(DateTime date) async {
    final user = AuthService.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase
        .from(_table)
        .delete()
        .eq('user_id', user.id)
        .eq('date', date.toIso8601String());
  }

  // Get default tasks for a new entry
  static List<TopPriorityTask> getDefaultTasks() {
    return List.generate(3, (index) => TopPriorityTask(
      description: '',
      position: index,
    ));
  }
} 