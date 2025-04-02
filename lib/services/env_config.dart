// Legacy adapter for EnvConfig to ConfigService
// This helps maintain compatibility during transition
import 'config_service.dart';

class EnvConfig {
  // OCR Configuration
  static String get googleCloudApiKey => ConfigService.get('GOOGLE_CLOUD_API_KEY');
  static String get visionApiEndpoint => ConfigService.get('VISION_API_ENDPOINT');

  // OpenAI Configuration
  static String get openaiApiKey => ConfigService.get('OPENAI_API_KEY');
  static String get gptModel => ConfigService.get('GPT_MODEL');
  static String get gptPrompt => ConfigService.get('GPT_PROMPT');

  // App Configuration
  static int get maxFreeScans => ConfigService.getInt('MAX_FREE_SCANS');
  static int get retentionDaysFree => ConfigService.getInt('RETENTION_DAYS_FREE');
  static int get retentionDaysPremium => ConfigService.getInt('RETENTION_DAYS_PREMIUM');

  // Wasabi Storage
  static String get wasabiAccessKey => ConfigService.get('WASABI_ACCESS_KEY');
  static String get wasabiSecretKey => ConfigService.get('WASABI_SECRET_KEY');
  static String get wasabiBucket => ConfigService.get('WASABI_BUCKET');
  static String get wasabiRegion => ConfigService.get('WASABI_REGION');
  static String get wasabiEndpoint => ConfigService.get('WASABI_ENDPOINT');
} 