import 'package:flutter/material.dart';
import 'task_model.dart';
import 'dart:convert';

class CardModel {
  final String id;
  final String userId;
  String title;
  String? description;
  String sourceType;
  String? imageId;
  String? aiResponseId;
  bool isArchived;
  bool isFavorited;
  final String color;
  final DateTime createdAt;
  DateTime updatedAt;
  String progress;
  int taskCount;
  final List<String> tags;
  List<TaskModel> tasks;
  final dynamic metadata;

  CardModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.sourceType = 'manual',
    this.imageId,
    this.aiResponseId,
    this.isArchived = false,
    this.isFavorited = false,
    required this.color,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.progress = '0%',
    this.taskCount = 0,
    List<TaskModel>? tasks,
    this.metadata,
  }) : tasks = tasks ?? [];

  // Create from database map
  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: map['description'] != null ? map['description'] as String : '',
      sourceType: map['source_type'] ?? 'manual',
      imageId: map['image_id'],
      aiResponseId: map['ai_response_id'],
      isArchived: map['is_archived'] ?? false,
      isFavorited: map['is_favorited'] ?? false,
      color: map['color'] != null ? map['color'] as String : '0xFF6C5CE7', // Default purple if null
      tags: map['tags'] != null ? List<String>.from(map['tags'] as List<dynamic>) : [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      progress: map['progress'] ?? '0%',
      taskCount: map['task_count'] ?? 0,
      tasks: [],
      metadata: map['metadata'],
    );
  }

  // Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'source_type': sourceType,
      'image_id': imageId,
      'ai_response_id': aiResponseId,
      'is_archived': isArchived,
      'is_favorited': isFavorited,
      'color': color,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'progress': progress,
      'task_count': taskCount,
      'metadata': metadata,
    };
  }

  // Convert to UI map (for backward compatibility)
  Map<String, dynamic> toUiMap() {
    return {
      'id': id,
      'title': title,
      'progress': progress,
      'taskCount': taskCount,
      'date': createdAt.toString().substring(0, 10),
      'tags': tags,
      'color': color,
      'tasks': tasks.map((task) => task.toUiMap()).toList(),
      'metadata': metadata,
    };
  }

  // Helper to get color as a Flutter Color
  Color getColor() {
    try {
      // Handle both formats: with or without '0x' prefix
      final colorValue = color.startsWith('0x') ? color : '0x$color';
      return Color(int.parse(colorValue));
    } catch (e) {
      return const Color(0xFF6C5CE7); // Default purple
    }
  }
} 