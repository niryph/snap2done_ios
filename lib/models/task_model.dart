import 'dart:convert';

class TaskModel {
  final String id;
  final String cardId;
  final String description;
  final String? notes;
  final String priority;
  final bool isCompleted;
  final int position;
  final DateTime? reminderDate;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.cardId,
    required this.description,
    this.notes,
    this.priority = 'medium',
    this.isCompleted = false,
    this.position = 0,
    this.reminderDate,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.metadata = metadata ?? {},
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  // Create from JSON (database)
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      cardId: json['card_id'],
      description: json['description'],
      notes: json['notes'],
      priority: json['priority'] ?? 'medium',
      isCompleted: json['is_completed'] == 1,
      position: json['position'] ?? 0,
      reminderDate: json['reminder_date'] != null ? DateTime.parse(json['reminder_date']) : null,
      metadata: json['metadata'] != null 
          ? json['metadata'] is String 
              ? jsonDecode(json['metadata']) 
              : json['metadata']
          : {},
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  // Convert to JSON for database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'card_id': cardId,
      'description': description,
      'notes': notes,
      'priority': priority,
      'is_completed': isCompleted ? 1 : 0,
      'position': position,
      'reminder_date': reminderDate?.toIso8601String(),
      'metadata': metadata is String ? metadata : jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  TaskModel copyWith({
    String? id,
    String? cardId,
    String? description,
    String? notes,
    String? priority,
    bool? isCompleted,
    int? position,
    DateTime? reminderDate,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      reminderDate: reminderDate ?? this.reminderDate,
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Create from database map
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      cardId: map['card_id'] as String,
      description: map['description'] != null ? map['description'] as String : 'Task',
      notes: map['notes'] as String?,
      priority: map['priority'] != null ? map['priority'] as String : 'medium',
      isCompleted: map['is_completed'] ?? false,
      position: map['position'] != null ? (map['position'] as num).toInt() : 0,
      reminderDate: map['reminder_date'] != null ? DateTime.parse(map['reminder_date'] as String) : null,
      metadata: map['metadata'] != null 
          ? map['metadata'] is String 
              ? jsonDecode(map['metadata']) 
              : map['metadata']
          : {},
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'card_id': cardId,
      'description': description,
      'notes': notes,
      'priority': priority,
      'is_completed': isCompleted,
      'position': position,
      'reminder_date': reminderDate?.toIso8601String(),
      'metadata': metadata is String ? metadata : jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Convert to UI map (for backward compatibility)
  Map<String, dynamic> toUiMap() {
    return {
      'id': id,
      'title': description,
      'description': notes ?? 'Priority: $priority',
      'icon': getPriorityIcon(priority),
      'isCompleted': isCompleted,
      'priority': priority,
      'position': position,
      'reminderDate': reminderDate,
      'metadata': metadata,
    };
  }

  // Helper to get priority icon
  String getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }
} 