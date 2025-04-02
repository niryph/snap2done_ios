import 'package:uuid/uuid.dart';

class TopPriorityEntry {
  final String id;
  final String userId;
  final DateTime date;
  final List<TopPriorityTask> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  TopPriorityEntry({
    String? id,
    required this.userId,
    required this.date,
    required this.tasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.id = id ?? Uuid().v4(),
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'tasks': tasks.map((task) => task.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TopPriorityEntry.fromMap(Map<String, dynamic> map) {
    return TopPriorityEntry(
      id: map['id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']),
      tasks: (map['tasks'] as List)
          .map((task) => TopPriorityTask.fromMap(task))
          .toList(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class TopPriorityTask {
  final String id;
  final String description;
  final String? notes;
  final bool isCompleted;
  final int position;
  final String? reminderTime;

  TopPriorityTask({
    String? id,
    required this.description,
    this.notes,
    this.isCompleted = false,
    required this.position,
    this.reminderTime,
  }) : this.id = id ?? Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'notes': notes,
      'is_completed': isCompleted,
      'position': position,
      'reminder_time': reminderTime,
    };
  }

  factory TopPriorityTask.fromMap(Map<String, dynamic> map) {
    return TopPriorityTask(
      id: map['id'],
      description: map['description'] ?? '',
      notes: map['notes'],
      isCompleted: map['is_completed'] ?? false,
      position: map['position'] ?? 0,
      reminderTime: map['reminder_time'],
    );
  }

  TopPriorityTask copyWith({
    String? description,
    String? notes,
    bool? isCompleted,
    int? position,
    String? reminderTime,
  }) {
    return TopPriorityTask(
      id: this.id,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
} 