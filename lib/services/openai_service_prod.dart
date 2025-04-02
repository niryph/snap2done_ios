import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config_service.dart';
import 'openai_service.dart' as openai_interface;

/// Production implementation of OpenAIService
class OpenAIServiceProd implements openai_interface.OpenAIService {
  @override
  Future<List<Map<String, dynamic>>> generateTodoList(String text) async {
    try {
      developer.log('Generating todo list from text (${text.length} chars)', name: 'OpenAIServiceProd');
      
      // Get the Supabase client
      final supabase = Supabase.instance.client;
      
      // Get the OpenAI API key from ConfigService
      final apiKey = await ConfigService.getSecureConfig('OPENAI_API_KEY');
      final gptModel = await ConfigService.getSecureConfig('GPT_MODEL') ?? 'gpt-3.5-turbo';
      
      if (apiKey == null || apiKey.isEmpty) {
        developer.log('No OpenAI API key found, using fallback todo generation', name: 'OpenAIServiceProd');
        return _generateFallbackTodos(text);
      }
      
      try {
        // Invoke the Supabase Edge Function
        final response = await supabase.functions.invoke(
          'openai-process-text',
          body: {
            'text': text,
            'apiKey': apiKey,
            'model': gptModel,
          },
        );
        
        // Check if the response is successful
        if (response.status != 200) {
          developer.log('Error from Edge Function: ${response.status}', name: 'OpenAIServiceProd');
          return _generateFallbackTodos(text);
        }
        
        // Parse the response data
        final data = response.data;
        if (data == null || data is! List) {
          developer.log('Invalid response format from Edge Function', name: 'OpenAIServiceProd');
          return _generateFallbackTodos(text);
        }
        
        // Convert the data to the expected format
        final todoList = data.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else {
            return {'task': item.toString(), 'priority': 'medium'};
          }
        }).toList();
        
        developer.log('Successfully generated ${todoList.length} todos', name: 'OpenAIServiceProd');
        return todoList;
      } catch (e) {
        developer.log('Error invoking Edge Function: $e', name: 'OpenAIServiceProd');
        return _generateFallbackTodos(text);
      }
    } catch (e) {
      developer.log('Error in generateTodoList: $e', name: 'OpenAIServiceProd');
      return _generateFallbackTodos(text);
    }
  }
  
  /// Generate fallback todos based on simple text parsing
  List<Map<String, dynamic>> _generateFallbackTodos(String text) {
    developer.log('Using fallback todo generation', name: 'OpenAIServiceProd');
    
    final List<Map<String, dynamic>> todos = [];
    
    // Simple approach: split by common delimiters
    List<String> lines = [];
    
    // Try splitting by newlines first
    if (text.contains('\n')) {
      lines = text.split('\n');
    } 
    // Then try periods (for inputs like "1.2.3.4")
    else if (text.contains('.')) {
      lines = text.split('.');
    }
    // Then try commas
    else if (text.contains(',')) {
      lines = text.split(',');
    }
    // If no delimiters found, treat the whole text as one item
    else {
      lines = [text];
    }
    
    // Process each line
    for (var line in lines) {
      final trimmedLine = line.trim();
      
      // Skip empty lines
      if (trimmedLine.isEmpty) {
        continue;
      }
      
      // Determine priority based on keywords
      String priority = 'medium';
      if (trimmedLine.toLowerCase().contains('urgent') || 
          trimmedLine.toLowerCase().contains('important') ||
          trimmedLine.toLowerCase().contains('asap')) {
        priority = 'high';
      } else if (trimmedLine.toLowerCase().contains('later') ||
                trimmedLine.toLowerCase().contains('eventually') ||
                trimmedLine.toLowerCase().contains('when possible')) {
        priority = 'low';
      }
      
      todos.add({
        'task': trimmedLine,
        'priority': priority,
      });
    }
    
    developer.log('Generated ${todos.length} fallback todos', name: 'OpenAIServiceProd');
    return todos;
  }
} 