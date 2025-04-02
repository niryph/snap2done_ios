import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  final SupabaseClient _client;
  
  SupabaseService._() : _client = Supabase.instance.client;
  
  static final String supabaseUrl = 'https://hbqptvpyvjrfggeqfuav.supabase.co';
  static final String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhicXB0dnB5dmpyZmdnZXFmdWF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA3NDc5MzEsImV4cCI6MjA1NjMyMzkzMX0.wdu8e9LXqM6PWOkRlU4tA6GPLs2Ql4yzRst1SU3Rz9o';
  
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
      );
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Supabase: $e');
      rethrow;
    }
  }
  
  // Todo operations
  Future<List<Map<String, dynamic>>> getTodos() async {
    try {
      final response = await _client
          .from('todos')
          .select()
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching todos: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> createTodo({
    required String title,
    required String description,
    String? priority,
    int? estimatedTime,
    String? imageUrl,
    String? status,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final data = {
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priority ?? 'medium',
        'estimated_time': estimatedTime,
        'image_url': imageUrl,
        'status': status ?? 'pending',
      };
      
      final response = await _client
          .from('todos')
          .insert(data)
          .select()
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error creating todo: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> updateTodo({
    required String id,
    String? title,
    String? description,
    String? priority,
    int? estimatedTime,
    String? imageUrl,
    String? status,
  }) async {
    try {
      final data = {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (priority != null) 'priority': priority,
        if (estimatedTime != null) 'estimated_time': estimatedTime,
        if (imageUrl != null) 'image_url': imageUrl,
        if (status != null) 'status': status,
      };
      
      final response = await _client
          .from('todos')
          .update(data)
          .eq('id', id)
          .select()
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error updating todo: $e');
      rethrow;
    }
  }
  
  Future<void> deleteTodo(String id) async {
    try {
      await _client
          .from('todos')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting todo: $e');
      rethrow;
    }
  }
  
  // User profile operations
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      rethrow;
    }
  }
  
  // API keys operations
  Future<Map<String, String>> getAPIKeys() async {
    try {
      final response = await _client
          .from('api_keys')
          .select('name, value');
      
      final Map<String, String> keys = {};
      for (final item in response) {
        keys[item['name']] = item['value'];
      }
      
      return keys;
    } catch (e) {
      debugPrint('Error fetching API keys: $e');
      rethrow;
    }
  }
  
  // Storage operations
  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final path = 'images/$userId/$fileName';
      
      await _client.storage
          .from('todo_images')
          .uploadBinary(path, bytes);
      
      final imageUrl = _client.storage
          .from('todo_images')
          .getPublicUrl(path);
      
      return imageUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  // Expense Entry Operations
  Future<List<Map<String, dynamic>>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query = _client
          .from('expense_entries')
          .select()
          .eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        query = query.lt('timestamp', endDate.toIso8601String());
      }

      final response = await query.order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      data['user_id'] = userId;

      final response = await _client
        .from('expense_entries')
        .insert(data)
        .select()
        .single();
        
      return response;
    } catch (e) {
      debugPrint('Error creating expense: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateExpense(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
        .from('expense_entries')
        .update(data)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
        
      return response;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
        .from('expense_entries')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }

  // User Settings Operations
  Future<Map<String, dynamic>> getUserSettings() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
        .from('expense_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
        
      if (response == null) {
        // Create default settings if none exist
        final defaultSettings = {
          'user_id': userId,
          'daily_budget': 0.0,
          'currency': 'USD',
          'reminder_enabled': false,
          'reminder_time': null,
        };

        final newSettings = await _client
          .from('expense_settings')
          .insert(defaultSettings)
          .select()
          .single();

        return newSettings;
      }

      return response;
    } catch (e) {
      debugPrint('Error fetching expense settings: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserSettings(Map<String, dynamic> data) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      data['user_id'] = userId;

      final response = await _client
        .from('expense_settings')
        .upsert(data)
        .eq('user_id', userId)
        .select()
        .single();
        
      return response;
    } catch (e) {
      debugPrint('Error updating expense settings: $e');
      rethrow;
    }
  }
}