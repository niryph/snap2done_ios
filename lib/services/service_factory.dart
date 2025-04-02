import 'dart:developer' as developer;
import 'openai_service.dart' as openai_interface;
import 'openai_service_prod.dart';
import 'openai_service_mock.dart';
import 'package:snap2done/services/api_service.dart';
import 'config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Factory for creating and accessing service instances
class ServiceFactory {
  static const bool USE_EDGE_FUNCTIONS = false; // Set to true for production

  // Keep mock option for UI testing, but default to Edge Function
  static bool useMockResponses = false;

  /// Get the appropriate OpenAI service based on configuration
  static openai_interface.OpenAIService get openAIService {
    if (useMockResponses) {
      return OpenAIServiceMock();
    } else {
      return OpenAIServiceProd();
    }
  }
  
  /// Generate a todo list from the given text
  static Future<List<Map<String, dynamic>>> generateTodoList(String inputText) async {
    try {
      developer.log('Generating todo list using ServiceFactory', name: 'ServiceFactory');
      return await openAIService.generateTodoList(inputText);
    } catch (e) {
      developer.log('Error generating todo list: $e', name: 'ServiceFactory');
      return [{'task': 'Error generating todo list', 'priority': 'medium'}];
    }
  }
  
  static late SupabaseService _supabaseService;
  static GoogleVisionService? _googleVisionService;
  
  /// Initialize the service factory with required configuration
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    developer.log('Initializing ServiceFactory', name: 'ServiceFactory');
    
    // Initialize Supabase service
    _supabaseService = SupabaseService(
      supabaseUrl: supabaseUrl,
      supabaseKey: supabaseKey,
    );
    
    try {
      // Get API keys from configuration
      final googleVisionKey = await ConfigService.getSecureConfig('GOOGLE_CLOUD_API_KEY');
      
      // Initialize Google Vision service if key is available
      if (googleVisionKey != null && googleVisionKey.isNotEmpty) {
        _googleVisionService = GoogleVisionService(googleVisionKey);
        developer.log('Google Vision service initialized', name: 'ServiceFactory');
      } else {
        developer.log('Google Vision service not initialized - no API key', name: 'ServiceFactory');
      }
    } catch (e) {
      developer.log('Failed to initialize API services: $e', name: 'ServiceFactory');
    }
  }
  
  /// Get the Supabase service instance
  static SupabaseService get supabase {
    return _supabaseService;
  }
  
  /// Get the Google Vision service instance
  static GoogleVisionService get googleVision {
    if (_googleVisionService == null) {
      throw Exception('Google Vision service not initialized');
    }
    return _googleVisionService!;
  }

  static String? _currentUserId;

  static Future<void> initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('current_user_id');
  }

  static String getCurrentUserId() {
    if (_currentUserId == null) {
      throw Exception('User ID not initialized. Call ServiceFactory.initializeUser() first.');
    }
    return _currentUserId!;
  }

  static Future<void> setCurrentUserId(String userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', userId);
  }

  static Future<void> clearCurrentUserId() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
  }
}