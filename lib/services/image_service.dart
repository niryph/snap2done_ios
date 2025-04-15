import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crypto/crypto.dart';

class ImageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Captures an image using the device camera
  static Future<File?> captureImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image == null) return null;
      
      return File(image.path);
    } catch (e) {
      debugPrint('Error capturing image: $e');
      return null;
    }
  }
  
  /// Uploads an image to Wasabi via Supabase storage and processes it with OCR
  static Future<Map<String, dynamic>> uploadAndProcessImage(File imageFile) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Generate a unique filename
      final fileExtension = path.extension(imageFile.path);
      final fileName = '${Uuid().v4()}$fileExtension';
      final wasabiPath = 'images/$userId/$fileName';
      
      // Get Wasabi configuration
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

      final config = Map.fromEntries(
        (configResponse as List<dynamic>).map((item) => MapEntry(item['key'] as String, item['value'] as String))
      );
      
      // Prepare the request
      final date = HttpDate.format(DateTime.now());
      final contentType = 'image/${fileExtension.replaceAll('.', '')}';
      
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
      
      // Upload the file
      final bytes = await imageFile.readAsBytes();
      final response = await http.put(
        uploadUri,
        headers: headers,
        body: bytes,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to upload file: ${response.statusCode}\nResponse: ${response.body}');
      }

      // Get the public URL
      final imageUrl = '$endpoint/$wasabiPath';
      
      // Process with OCR
      final ocrText = await _performOCR(bytes);
      
      // Save image record to database
      final imageRecord = await _supabase.from('attachments').insert({
        'user_id': userId,
        'wasabi_path': wasabiPath,
        'original_filename': path.basename(imageFile.path),
        'size_bytes': bytes.length,
        'mime_type': contentType,
        'ocr_text': ocrText,
        'is_processed': true,
        'attachment_type': 'image'
      }).select().single();
      
      return {
        'id': imageRecord['id'],
        'url': imageUrl,
        'ocr_text': ocrText,
      };
    } catch (e) {
      print('Exception in image service: $e');
      throw Exception('Failed to upload and process image: $e');
    }
  }
  
  /// Performs OCR on an image using Google Cloud Vision API
  static Future<String> _performOCR(Uint8List imageBytes) async {
    try {
      // Directly use cloud OCR since we don't need on-device processing
      return await _performCloudOCR(imageBytes);
    } catch (e) {
      print('Error in OCR processing: $e');
      return ''; // Return empty string if OCR fails
    }
  }
  
  /// Fallback to cloud OCR if on-device fails
  static Future<String> _performCloudOCR(Uint8List imageBytes) async {
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
      final base64Image = base64Encode(imageBytes);
      
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
        } else {
          return '';
        }
      } else {
        throw Exception('Google Vision API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Cloud OCR error: $e');
      return ''; // Return empty string if all OCR methods fail
    }
  }
  
  /// Gets an image record by ID
  static Future<Map<String, dynamic>> getImageById(String imageId) async {
    try {
      final imageRecord = await _supabase
          .from('attachments')
          .select()
          .eq('id', imageId)
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
      final url = '$endpoint/${imageRecord['wasabi_path']}';
      
      return {
        ...imageRecord,
        'url': url,
      };
    } catch (e) {
      print('Error getting image: $e');
      throw Exception('Failed to get image: $e');
    }
  }
}