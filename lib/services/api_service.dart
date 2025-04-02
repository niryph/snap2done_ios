import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  final Map<String, String> _defaultHeaders;

  ApiService({
    required this.baseUrl,
    Map<String, String>? headers,
  }) : _defaultHeaders = headers ?? {'Content-Type': 'application/json'};

  // Helper method to generate user-friendly error messages
  String _getReadableErrorMessage(int statusCode, String responseBody) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input and try again.';
      case 401:
        return 'Authentication failed. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource could not be found.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service is currently unavailable. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers ?? _defaultHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(_getReadableErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error. Please check your internet connection.');
    }
  }

  Future<dynamic> post(
    String endpoint, 
    Map<String, dynamic> data, 
    {Map<String, String>? headers}
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers ?? _defaultHeaders,
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(_getReadableErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error. Please check your internet connection.');
    }
  }
  
  Future<dynamic> uploadImage(
    String endpoint, 
    Uint8List imageBytes, 
    {Map<String, String>? headers, String filename = 'image.jpg'}
  ) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/$endpoint'));
      
      // Add headers
      request.headers.addAll(headers ?? _defaultHeaders);
      
      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: filename,
      ));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(_getReadableErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error. Please check your internet connection.');
    }
  }
}

// Specialized service for Google Vision API
class GoogleVisionService {
  final ApiService _apiService;
  static const String _visionApiEndpoint = 'https://vision.googleapis.com/v1/images:annotate';
  
  GoogleVisionService(String apiKey) 
    : _apiService = ApiService(
        baseUrl: _visionApiEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
        }
      );
  
  Future<Map<String, dynamic>> detectText(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    
    final requestData = {
      'requests': [
        {
          'image': {
            'content': base64Image,
          },
          'features': [
            {
              'type': 'TEXT_DETECTION',
              'maxResults': 10,
            },
          ],
        },
      ],
    };
    
    return await _apiService.post('', requestData);
  }
}

// Specialized service for OpenAI API
class OpenAIService {
  final ApiService _apiService;
  static const String _openAIApiEndpoint = 'https://api.openai.com/v1';
  
  OpenAIService(String apiKey)
    : _apiService = ApiService(
        baseUrl: _openAIApiEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        }
      );
  
  Future<Map<String, dynamic>> extractTodoItems(String text) async {
    final requestData = {
      'model': 'gpt-4',
      'messages': [
        {
          'role': 'system',
          'content': 'You are a helpful assistant that extracts actionable todo items from text. Return the items in a JSON array format with fields: task, priority (high, medium, low), and estimated_time (in minutes).'
        },
        {
          'role': 'user',
          'content': text
        }
      ],
      'temperature': 0.7,
    };
    
    return await _apiService.post('chat/completions', requestData);
  }
}

// Specialized service for Supabase
class SupabaseService {
  final ApiService _apiService;
  final String _supabaseUrl;
  final String _supabaseKey;
  
  SupabaseService({
    required String supabaseUrl,
    required String supabaseKey,
  }) : _supabaseUrl = supabaseUrl,
       _supabaseKey = supabaseKey,
       _apiService = ApiService(
         baseUrl: supabaseUrl,
         headers: {
           'apikey': supabaseKey,
           'Authorization': 'Bearer $supabaseKey',
           'Content-Type': 'application/json',
           'Prefer': 'return=representation'
         }
       );
  
  // Todo operations
  Future<List<dynamic>> getTodos() async {
    return await _apiService.get('rest/v1/todos?select=*');
  }
  
  Future<Map<String, dynamic>> createTodo(Map<String, dynamic> todoData) async {
    return await _apiService.post('rest/v1/todos', todoData);
  }
  
  Future<Map<String, dynamic>> updateTodo(String id, Map<String, dynamic> todoData) async {
    return await _apiService.post(
      'rest/v1/todos?id=eq.$id',
      todoData,
      headers: {
        'apikey': _supabaseKey,
        'Authorization': 'Bearer $_supabaseKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
        'Content-Profile': 'public',
        'X-HTTP-Method-Override': 'PATCH'
      }
    );
  }
  
  // User operations
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final result = await _apiService.get('rest/v1/profiles?user_id=eq.$userId&select=*');
    if (result is List && result.isNotEmpty) {
      return result.first;
    }
    throw Exception('User profile not found');
  }
  
  // Get API keys stored in Supabase
  Future<Map<String, String>> getAPIKeys() async {
    final result = await _apiService.get('rest/v1/api_keys?select=*');
    if (result is List && result.isNotEmpty) {
      Map<String, String> keys = {};
      for (var key in result) {
        keys[key['name']] = key['value'];
      }
      return keys;
    }
    throw Exception('API keys not found');
  }
}