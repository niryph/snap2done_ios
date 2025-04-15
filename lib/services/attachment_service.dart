import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';

class AttachmentService {
  static final _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  /// Uploads any file to Wasabi and stores its metadata in the attachments table
  static Future<Map<String, dynamic>> uploadAttachment({
    required String filePath,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    required String attachmentType,
    String? todoEntryId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileExtension = path.extension(filePath).toLowerCase();
      
      // Generate unique filename
      final uniqueFileName = '${Uuid().v4()}$fileExtension';
      final wasabiPath = 'attachments/$attachmentType/${user.id}/$uniqueFileName';

      // Get Wasabi configuration
      final config = await _getWasabiConfig();
      if (config == null) throw Exception('Storage configuration not found');

      // Prepare headers for upload
      final headers = await _prepareUploadHeaders(File(filePath), config, wasabiPath);

      // Upload file
      final uploadResponse = await http.put(
        Uri.parse('https://${config['WASABI_BUCKET']}.s3.${config['WASABI_REGION']}.wasabisys.com/$wasabiPath'),
        headers: headers,
        body: await File(filePath).readAsBytes(),
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Failed to upload file: ${uploadResponse.statusCode}');
      }

      // Process OCR for images if configuration exists
      String? ocrText;
      if (mimeType.startsWith('image/')) {
        try {
          ocrText = await _performOCR(File(filePath));
        } catch (e) {
          print('OCR error: $e');
          // Continue without OCR if it fails
        }
      }

      // Insert record into attachments table
      final insertData = {
        'user_id': user.id,
        'wasabi_path': wasabiPath,
        'original_filename': fileName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'attachment_type': attachmentType,
      };

      if (todoEntryId != null) {
        insertData['todo_entry_id'] = todoEntryId;
      }

      if (description != null) {
        insertData['description'] = description;
      }

      if (metadata != null) {
        insertData['metadata'] = metadata;
      }

      if (ocrText != null) {
        insertData['ocr_text'] = ocrText;
      }

      final response = await _supabase
          .from('attachments')
          .insert(insertData)
          .select()
          .single();

      return response;
    } catch (e) {
      print('Exception in attachment service: $e');
      rethrow;
    }
  }

  /// Gets all attachments for a user
  static Future<List<Map<String, dynamic>>> getUserAttachments() async {
    try {
      final attachments = await _supabase
          .from('attachments')
          .select()
          .order('created_at', ascending: false);
      
      // Get the Wasabi configuration
      final configResponse = await _supabase
          .from('app_configuration')
          .select('key, value')
          .inFilter('key', [
            'WASABI_BUCKET',
            'WASABI_REGION'
          ])
          .limit(2);

      final config = Map.fromEntries(
        (configResponse as List<dynamic>).map((item) => MapEntry(item['key'] as String, item['value'] as String))
      );

      // Construct the Wasabi URL for each attachment
      final endpoint = 'https://${config['WASABI_BUCKET']}.s3.${config['WASABI_REGION']}.wasabisys.com';
      
      return (attachments as List<dynamic>).map((attachment) {
        final url = '$endpoint/${attachment['wasabi_path']}';
        return <String, dynamic>{
          ...Map<String, dynamic>.from(attachment),
          'url': url,
        };
      }).toList();
    } catch (e) {
      print('Error getting user attachments: $e');
      throw Exception('Failed to get user attachments: $e');
    }
  }

  /// Gets an attachment record by ID
  static Future<Map<String, dynamic>> getAttachmentById(String attachmentId) async {
    try {
      final attachmentRecord = await _supabase
          .from('attachments')
          .select()
          .eq('id', attachmentId)
          .single();
      
      // Get the Wasabi configuration
      final configResponse = await _supabase
          .from('app_configuration')
          .select('key, value')
          .inFilter('key', [
            'WASABI_BUCKET',
            'WASABI_REGION'
          ])
          .limit(2);

      final config = Map.fromEntries(
        (configResponse as List<dynamic>).map((item) => MapEntry(item['key'] as String, item['value'] as String))
      );

      // Construct the Wasabi URL
      final endpoint = 'https://${config['WASABI_BUCKET']}.s3.${config['WASABI_REGION']}.wasabisys.com';
      final url = '$endpoint/${attachmentRecord['wasabi_path']}';
      
      return {
        ...attachmentRecord,
        'url': url,
      };
    } catch (e) {
      print('Error getting attachment: $e');
      throw Exception('Failed to get attachment: $e');
    }
  }

  /// Gets all attachments for a task
  static Future<List<Map<String, dynamic>>> getAttachmentsForTask(String taskId) async {
    try {
      final attachments = await _supabase
          .from('attachments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: false);
      
      // Get the Wasabi configuration
      final configResponse = await _supabase
          .from('app_configuration')
          .select('key, value')
          .inFilter('key', [
            'WASABI_BUCKET',
            'WASABI_REGION'
          ])
          .limit(2);

      final config = Map.fromEntries(
        (configResponse as List<dynamic>).map((item) => MapEntry(item['key'] as String, item['value'] as String))
      );

      // Construct the Wasabi URL for each attachment
      final endpoint = 'https://${config['WASABI_BUCKET']}.s3.${config['WASABI_REGION']}.wasabisys.com';
      
      return (attachments as List<dynamic>).map((attachment) {
        final url = '$endpoint/${attachment['wasabi_path']}';
        return <String, dynamic>{
          ...Map<String, dynamic>.from(attachment),
          'url': url,
        };
      }).toList();
    } catch (e) {
      print('Error getting task attachments: $e');
      throw Exception('Failed to get task attachments: $e');
    }
  }

  /// Gets all attachments for a todo entry
  static Future<List<Map<String, dynamic>>> getAttachmentsForTodoEntry(String todoEntryId) async {
    final response = await _supabase
        .from('attachments')
        .select()
        .eq('todo_entry_id', todoEntryId)
        .order('created_at');

    return response;
  }

  /// Performs OCR on an image using Google Cloud Vision API
  static Future<String> _performOCR(File file) async {
    try {
      // Get Google Vision API key from app_configuration
      final apiKeyResponse = await _supabase
          .from('app_configuration')
          .select('value')
          .eq('key', 'google_vision_api_key')
          .single();
      
      final apiKey = apiKeyResponse['value'];
      if (apiKey == null) {
        throw Exception('Google Vision API key not found');
      }
      
      final url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');
      final base64Image = base64Encode(await file.readAsBytes());
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {
                'content': base64Image,
              },
              'features': [
                {
                  'type': 'TEXT_DETECTION',
                  'maxResults': 1,
                },
              ],
            },
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final textAnnotations = jsonResponse['responses'][0]['textAnnotations'];
        
        if (textAnnotations != null && textAnnotations.isNotEmpty) {
          return textAnnotations[0]['description'];
        }
      }
      return '';
    } catch (e) {
      print('OCR error: $e');
      return ''; // Return empty string if OCR fails
    }
  }

  static Future<Map<String, String>> _getWasabiConfig() async {
    final configResponse = await _supabase
        .from('app_configuration')
        .select('key, value')
        .inFilter('key', [
          'WASABI_ACCESS_KEY',
          'WASABI_SECRET_KEY',
          'WASABI_BUCKET',
          'WASABI_REGION'
        ])
        .limit(4);

    return Map.fromEntries(
      (configResponse as List<dynamic>).map((item) => MapEntry(item['key'] as String, item['value'] as String))
    );
  }

  static Future<Map<String, String>> _prepareUploadHeaders(File file, Map<String, String> config, String wasabiPath) async {
    final date = HttpDate.format(DateTime.now());
    final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
    
    // Create canonical string for signing
    final canonicalString = [
      'PUT',
      '',  // MD5
      contentType,
      date,
      '/${config['WASABI_BUCKET']}/$wasabiPath'
    ].join('\n');

    // Create signature
    final signature = base64.encode(
      Hmac(sha1, utf8.encode(config['WASABI_SECRET_KEY']!))
          .convert(utf8.encode(canonicalString))
          .bytes
    );

    // Construct the bucket-specific endpoint
    final endpoint = 'https://${config['WASABI_BUCKET']}.s3.${config['WASABI_REGION']}.wasabisys.com';
    final uploadUri = Uri.parse('$endpoint/$wasabiPath');

    // Create headers
    final headers = {
      'Host': uploadUri.host,
      'Date': date,
      'Content-Type': contentType,
      'Authorization': 'AWS ${config['WASABI_ACCESS_KEY']}:$signature',
    };
    
    return headers;
  }
} 