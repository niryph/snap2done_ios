import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/env_config.dart';

class OpenAIServiceDev {
  static Future<Map<String, dynamic>> generateTodoList(String inputText) async {
    // This is the same code as in your Edge Function, but runs client-side during development
    try {
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
              'content': inputText,
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'success': true,
          'aiResponseId': 'dev-${DateTime.now().millisecondsSinceEpoch}',
          'content': jsonResponse['choices'][0]['message']['content']
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