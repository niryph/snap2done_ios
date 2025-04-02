import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/env_config.dart';

class OpenAIServiceProdClient {
  static final supabase = Supabase.instance.client;
  
  static Future<Map<String, dynamic>> generateTodoList(String text, {String? imageId}) async {
    try {
      final processingStartTime = DateTime.now();
      
      final url = Uri.parse('https://api.openai.com/v1/chat/completions');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${EnvConfig.openaiApiKey}',
        },
        body: jsonEncode({
          'model': EnvConfig.gptModel,
          'messages': [
            {
              'role': 'system',
              'content': EnvConfig.gptPrompt,
            },
            {
              'role': 'user',
              'content': text,
            },
          ],
        }),
      );
      
      final processingTime = DateTime.now().difference(processingStartTime).inMilliseconds;
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final content = jsonResponse['choices'][0]['message']['content'];
        
        // 2. Store the response in Supabase directly
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          // Insert into ai_responses table
          final { data: aiResponse, error: aiError } = await supabase
            .from('ai_responses')
            .insert({
              'user_id': userId,
              'image_id': imageId,
              'prompt_used': EnvConfig.gptPrompt,
              'response': jsonResponse,
              'model_version': EnvConfig.gptModel,
              'processing_time_ms': processingTime,
              'status': 'success'
            })
            .select()
            .single();
            
          if (aiError != null) {
            print('Error storing AI response: ${aiError.message}');
          }
          
          return {
            'success': true,
            'aiResponseId': aiResponse?['id'] ?? 'client-${DateTime.now().millisecondsSinceEpoch}',
            'content': content
          };
        }
        
        return {
          'success': true,
          'aiResponseId': 'client-${DateTime.now().millisecondsSinceEpoch}',
          'content': content
        };
      } else {
        // Generate user-friendly error message based on status code
        String errorMessage;
        switch (response.statusCode) {
          case 400:
            errorMessage = 'Invalid request. Please check your input.';
            break;
          case 401:
            errorMessage = 'Authentication failed. Please check your API key.';
            break;
          case 429:
            errorMessage = 'Too many requests. Please try again later.';
            break;
          case 500:
            errorMessage = 'OpenAI service error. Please try again later.';
            break;
          default:
            errorMessage = 'An unexpected error occurred. Please try again.';
        }
        
        // Log the error for debugging
        print('OpenAI API Error: ${response.statusCode} - ${response.body}');
        
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      print('Exception in OpenAI service: $e');
      return {
        'success': false,
        'error': 'Network error. Please check your internet connection.'
      };
    }
  }
} 