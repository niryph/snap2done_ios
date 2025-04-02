import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_settings_model.dart';
import '../models/task_model.dart';
import 'dart:developer' as developer;

class TodoService {
  static final TodoService _instance = TodoService._internal();
  static final _supabase = Supabase.instance.client;

  factory TodoService() {
    return _instance;
  }

  TodoService._internal();

  // Todo Settings Operations
  Future<TodoSettings?> getTodoSettings(String userId) async {
    try {
      final response = await _supabase
          .from('todo_settings')
          .select()
          .eq('user_id', userId)
          .single();
      
      if (response == null) return null;
      return TodoSettings.fromJson(response);
    } catch (e) {
      developer.log('Error getting todo settings: $e', name: 'TodoService');
      return null;
    }
  }

  Future<void> saveTodoSettings(TodoSettings settings) async {
    try {
      await _supabase
          .from('todo_settings')
          .upsert(settings.toJson());
    } catch (e) {
      developer.log('Error saving todo settings: $e', name: 'TodoService');
      rethrow;
    }
  }

  Future<void> updateTodoSettings(TodoSettings settings) async {
    try {
      await _supabase
          .from('todo_settings')
          .update(settings.toJson())
          .eq('id', settings.id);
    } catch (e) {
      developer.log('Error updating todo settings: $e', name: 'TodoService');
      rethrow;
    }
  }

  // Todo Entries Operations
  Future<List<TaskModel>> getTodoEntries(String userId, String cardId) async {
    try {
      final response = await _supabase
          .from('todo_entries')
          .select()
          .eq('user_id', userId)
          .eq('card_id', cardId)
          .order('position', ascending: true);
      
      return (response as List).map((map) => TaskModel.fromJson(map)).toList();
    } catch (e) {
      developer.log('Error getting todo entries: $e', name: 'TodoService');
      return [];
    }
  }

  Future<void> saveTodoEntry(String userId, String cardId, TaskModel task) async {
    try {
      final data = task.toJson();
      data['user_id'] = userId;
      data['card_id'] = cardId;
      
      await _supabase
          .from('todo_entries')
          .upsert(data);
    } catch (e) {
      developer.log('Error saving todo entry: $e', name: 'TodoService');
      rethrow;
    }
  }

  Future<void> updateTodoEntry(TaskModel task) async {
    try {
      await _supabase
          .from('todo_entries')
          .update(task.toJson())
          .eq('id', task.id);
    } catch (e) {
      developer.log('Error updating todo entry: $e', name: 'TodoService');
      rethrow;
    }
  }

  Future<void> deleteTodoEntry(String taskId) async {
    try {
      await _supabase
          .from('todo_entries')
          .delete()
          .eq('id', taskId);
    } catch (e) {
      developer.log('Error deleting todo entry: $e', name: 'TodoService');
      rethrow;
    }
  }

  Future<void> reorderTodoEntries(String cardId, List<TaskModel> tasks) async {
    try {
      // Create a batch of updates
      final updates = tasks.asMap().entries.map((entry) {
        final task = entry.value;
        return {
          'id': task.id,
          'position': entry.key,
        };
      }).toList();

      await _supabase
          .from('todo_entries')
          .upsert(updates);
    } catch (e) {
      developer.log('Error reordering todo entries: $e', name: 'TodoService');
      rethrow;
    }
  }

  // Batch Operations
  Future<void> saveTodoEntriesBatch(String userId, String cardId, List<TaskModel> tasks) async {
    try {
      final batchData = tasks.map((task) {
        final data = task.toJson();
        data['user_id'] = userId;
        data['card_id'] = cardId;
        return data;
      }).toList();

      await _supabase
          .from('todo_entries')
          .upsert(batchData);
    } catch (e) {
      developer.log('Error saving todo entries batch: $e', name: 'TodoService');
      rethrow;
    }
  }

  Future<void> deleteCardTodoEntries(String cardId) async {
    try {
      await _supabase
          .from('todo_entries')
          .delete()
          .eq('card_id', cardId);
    } catch (e) {
      developer.log('Error deleting card todo entries: $e', name: 'TodoService');
      rethrow;
    }
  }
} 