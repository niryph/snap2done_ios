import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class ConfigService {
  static final supabase = Supabase.instance.client;
  static Map<String, String> _configCache = {};
  static bool _isInitialized = false;
  static final _secureStorage = FlutterSecureStorage();
  static bool _useSharedPrefsOnly = false;
  
  /// Initialize the config service by fetching public configs
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Check if we're on macOS, where we might have signing issues
    _useSharedPrefsOnly = Platform.isMacOS;

    try {
      final response = await supabase
          .from('app_configuration')
          .select('key, value')
          .eq('is_public', true);
      
      // Update cache
      for (final item in response) {
        _configCache[item['key']] = item['value'];
      }
      
      _isInitialized = true;
      developer.log('Config initialized with ${_configCache.length} values', name: 'ConfigService');
    } catch (e) {
      developer.log('Error initializing config: $e', name: 'ConfigService');
      // Use defaults if we can't fetch config
      _setDefaults();
      _isInitialized = true;
    }
  }
  
  /// Fetch a private configuration value from Supabase and store it securely
  /// This should only be called during app initialization
  static Future<String> fetchAndSecurePrivateConfig(String key) async {
    try {
      final response = await supabase
          .from('app_configuration')
          .select('value')
          .eq('key', key)
          .single();
      
      if (response != null && response['value'] != null) {
        // Store the value securely
        await setSecureConfig(key, response['value']);
        return response['value'];
      }
    } catch (e) {
      developer.log('Error fetching private config $key: $e', name: 'ConfigService');
      // Set a fallback value if available
      _setFallbackSecureValue(key);
    }
    return '';
  }
  
  /// Set a local value in the config cache (for development/testing)
  static void setLocalValue(String key, String value) {
    _configCache[key] = value;
    developer.log('Set local config value for $key', name: 'ConfigService');
  }
  
  /// Set a fallback secure value for critical configurations
  static Future<void> _setFallbackSecureValue(String key) async {
    String fallbackValue = '';
    
    // Define fallback values for critical configurations
    switch (key) {
      case 'GOOGLE_CLOUD_API_KEY':
        fallbackValue = 'AIzaSyDJfwYYhvXRnBvSJNJLJYnmHQeL9N0yLnI'; // Example key, replace with your actual fallback
        break;
      case 'OPENAI_API_KEY':
        fallbackValue = 'sk-dummy-key-for-development'; // Replace with your actual fallback
        break;
      case 'GPT_MODEL':
        fallbackValue = 'gpt-3.5-turbo';
        break;
    }
    
    if (fallbackValue.isNotEmpty) {
      await setSecureConfig(key, fallbackValue);
      developer.log('Set fallback secure value for $key', name: 'ConfigService');
    }
  }
  
  /// Securely store a sensitive configuration value
  static Future<void> setSecureConfig(String key, String value) async {
    try {
      // On macOS, default to shared preferences to avoid signing issues
      if (_useSharedPrefsOnly) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('secure_$key', value);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (e) {
      print('Error setting secure config for $key: $e');
      // Fall back to using standard shared preferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fallback_$key', value);
    }
  }
  
  /// Retrieve a securely stored configuration value
  /// This is the method that should be used throughout the app
  static Future<String> getSecureConfig(String key) async {
    try {
      // On macOS, get from shared preferences
      if (_useSharedPrefsOnly) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('secure_$key') ?? '';
      }
      return await _secureStorage.read(key: key) ?? '';
    } catch (e) {
      print('Error getting secure config for $key: $e');
      // Try getting from fallback storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fallback_$key') ?? 
             prefs.getString('secure_$key') ?? '';
    }
  }
  
  /// Get a configuration value, with an optional default
  static String get(String key, {String defaultValue = ''}) {
    return _configCache[key] ?? defaultValue;
  }
  
  /// Get configuration as int
  static int getInt(String key, {int defaultValue = 0}) {
    final value = _configCache[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }
  
  /// Get configuration as bool
  static bool getBool(String key, {bool defaultValue = false}) {
    final value = _configCache[key];
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }
  
  /// Set default values in case we can't connect
  static void _setDefaults() {
    _configCache = {
      'MAX_FREE_SCANS': '5',
      'RETENTION_DAYS_FREE': '7',
      'ENABLE_GOOGLE_AUTH': 'true',
      'VISION_API_ENDPOINT': 'https://vision.googleapis.com/v1/images:annotate',
    };
  }

  // Get the appropriate redirect URL based on the current environment
  static String getRedirectUrl() {
    // You can expand this to use environment variables or build configuration
    const isProduction = bool.fromEnvironment('dart.vm.product', defaultValue: false);
    
    if (isProduction) {
      // Production mobile app redirect
      return 'com.niryph.snap2done://login-callback/';
    } else {
      // Development redirect URLs
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile development
        return 'com.niryph.snap2done://login-callback/';
      } else {
        // Web/desktop development
        return 'http://localhost:3000/auth/callback';
      }
    }
  }
}