import 'dart:convert';
import 'package:uuid/uuid.dart';

class TodoSettings {
  final String id;
  final String userId;
  final String defaultPriority;
  final bool showCompletedTasks;
  final String sortBy; // 'priority', 'dueDate', 'created', 'custom'
  final bool sortAscending;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoSettings({
    String? id,
    required this.userId,
    this.defaultPriority = 'medium',
    this.showCompletedTasks = true,
    this.sortBy = 'created',
    this.sortAscending = true,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.id = id ?? const Uuid().v4(),
    this.metadata = metadata ?? {},
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  // Create from JSON (database)
  factory TodoSettings.fromJson(Map<String, dynamic> json) {
    return TodoSettings(
      id: json['id'],
      userId: json['user_id'],
      defaultPriority: json['default_priority'] ?? 'medium',
      showCompletedTasks: json['show_completed_tasks'] == 1,
      sortBy: json['sort_by'] ?? 'created',
      sortAscending: json['sort_ascending'] == 1,
      metadata: json['metadata'] != null 
          ? json['metadata'] is String 
              ? jsonDecode(json['metadata']) 
              : json['metadata']
          : {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Convert to JSON for database
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'default_priority': defaultPriority,
      'show_completed_tasks': showCompletedTasks ? 1 : 0,
      'sort_by': sortBy,
      'sort_ascending': sortAscending ? 1 : 0,
      'metadata': metadata is String ? metadata : jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  TodoSettings copyWith({
    String? userId,
    String? defaultPriority,
    bool? showCompletedTasks,
    String? sortBy,
    bool? sortAscending,
    Map<String, dynamic>? metadata,
  }) {
    return TodoSettings(
      id: this.id,
      userId: userId ?? this.userId,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      showCompletedTasks: showCompletedTasks ?? this.showCompletedTasks,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      metadata: metadata ?? Map<String, dynamic>.from(this.metadata),
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 