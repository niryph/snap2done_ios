import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../models/task_model.dart';

/// Model class for top priorities feature
class TopPrioritiesModel {
  static final _uuid = Uuid();

  /// Converts a date to a string key for storage
  static String dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Converts a date key back to a DateTime object
  static DateTime keyToDate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date key format: $key');
    }
    return DateTime(
      int.parse(parts[0]),  // year
      int.parse(parts[1]),  // month
      int.parse(parts[2]),  // day
    );
  }

  /// Formats a date for display in the UI
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    final tomorrow = now.add(Duration(days: 1));
    if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Gets the title for a specific date
  static String getTitleForDate(DateTime date) {
    return 'Top 3 Priorities for ${formatDate(date)}';
  }

  /// Creates default metadata for a new top priorities card
  static Map<String, dynamic> createDefaultMetadata() {
    final today = DateTime.now();
    final dateKey = dateToKey(today);
    
    return {
      'type': 'top_priorities',
      'priorities': {
        dateKey: {
          'tasks': getDefaultTasks(),
          'lastModified': today.toIso8601String(),
        },
      },
    };
  }

  /// Gets default tasks for a new day
  static List<Map<String, dynamic>> getDefaultTasks() {
    return List.generate(3, (index) {
      return {
        'id': _uuid.v4(),
        'description': 'Priority #${index + 1}',
        'notes': '',
        'isCompleted': false,
        'position': index,
        'metadata': {
          'type': 'top_priority',
          'order': index + 1,
          'placeholder': true,
        },
      };
    });
  }

  /// Converts a task to TaskModel format
  static TaskModel taskToModel(Map<String, dynamic> task, String cardId) {
    return TaskModel(
      id: task['id'] as String,
      cardId: cardId,
      description: task['description'] as String? ?? '',
      notes: task['notes'] as String? ?? '',
      isCompleted: task['isCompleted'] as bool? ?? false,
      position: task['position'] as int? ?? 0,
      metadata: {
        ...task['metadata'] as Map<String, dynamic>? ?? {},
        'type': 'top_priority',
        'order': task['metadata']?['order'] ?? (task['position'] as int? ?? 0) + 1,
      },
    );
  }

  /// Gets the priority color for a task
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.amber.shade100;
      case 'low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  /// Gets the priority icon for a task
  static IconData getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }
} 