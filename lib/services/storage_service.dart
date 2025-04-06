import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class StorageService {
  static final _uuid = Uuid();
  static Map<String, String>? _config;
  
  // File type icons
  static const String audioIcon = 'assets/images/audio_icon.png';
  static const String documentIcon = 'assets/images/document_icon.png';
  static const String imageIcon = 'assets/images/image_icon.png';
  static const String microphoneIcon = 'assets/images/microphone.png';

  /// Get the appropriate icon for a file type
  static String getFileTypeIcon(String filePath) {
    final mimeType = lookupMimeType(filePath)?.split('/')[0] ?? '';
    final extension = path.extension(filePath).toLowerCase();
    
    if (extension == '.m4a' || extension == '.aac' || extension == '.mp3') {
      return audioIcon;
    }
    
    switch (mimeType) {
      case 'audio':
        return audioIcon;
      case 'image':
        return imageIcon;
      default:
        return documentIcon;
    }
  }

  static Future<void> initialize() async {
    try {
      // Fetch Wasabi configuration from database
      final response = await Supabase.instance.client
          .from('app_configuration')
          .select('key, value')
          .inFilter('key', [
            'WASABI_ACCESS_KEY',
            'WASABI_SECRET_KEY',
            'WASABI_BUCKET',
            'WASABI_REGION',
            'WASABI_ENDPOINT'
          ])
          .limit(5);

      // Convert response to map
      _config = Map.fromEntries(
        (response as List<dynamic>).map((item) => MapEntry(item['key'] as String, item['value'] as String))
      );

      if (_config == null || _config!.length != 5) {
        throw Exception('Missing required Wasabi configuration');
      }
    } catch (e) {
      print('Error initializing StorageService: $e');
      rethrow;
    }
  }

  /// Upload a file to Wasabi S3 via Supabase storage
  /// Returns a map containing the file URL, wasabi_path, icon path, and mime type
  static Future<Map<String, String>> uploadFile(File file, String directory) async {
    try {
      // Generate a unique filename
      final extension = path.extension(file.path);
      final filename = '${_uuid.v4()}$extension';
      final wasabiPath = '$directory/$filename';

      // Get the mime type
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      if (_config == null) {
        await initialize();
      }

      // Prepare the request
      final date = HttpDate.format(DateTime.now());
      final contentType = mimeType;

      // Create canonical string for signing
      final canonicalString = [
        'PUT',
        '',  // MD5
        contentType,
        date,
        '/${_config!['WASABI_BUCKET']}/$wasabiPath'
      ].join('\n');

      // Create signature
      final signature = base64.encode(
        Hmac(sha1, utf8.encode(_config!['WASABI_SECRET_KEY']!))
            .convert(utf8.encode(canonicalString))
            .bytes
      );

      // Construct the bucket-specific endpoint
      final endpoint = 'https://${_config!['WASABI_BUCKET']}.s3.${_config!['WASABI_REGION']}.wasabisys.com';
      final uploadUri = Uri.parse('$endpoint/$wasabiPath');

      // Create headers
      final headers = {
        'Host': uploadUri.host,
        'Date': date,
        'Content-Type': contentType,
        'Authorization': 'AWS ${_config!['WASABI_ACCESS_KEY']}:$signature',
      };

      // Upload the file
      final bytes = await file.readAsBytes();
      final response = await http.put(
        uploadUri,
        headers: headers,
        body: bytes,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to upload file: ${response.statusCode}\nResponse: ${response.body}');
      }

      // Construct the public URL
      final url = '$endpoint/$wasabiPath';

      return {
        'url': url,
        'wasabi_path': wasabiPath,
        'icon': getFileTypeIcon(file.path),
        'mimeType': mimeType,
      };
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  /// Delete a file from Wasabi S3
  static Future<void> deleteFile(String url) async {
    if (_config == null) {
      await initialize();
    }

    try {
      final uri = Uri.parse(url);
      final key = uri.path.substring(1); // Remove leading slash
      
      // Prepare the request
      final date = HttpDate.format(DateTime.now());
      
      // Create canonical string for signing
      final canonicalString = [
        'DELETE',
        '',  // MD5
        '',  // Content Type
        date,
        '/${_config!['WASABI_BUCKET']}/$key'
      ].join('\n');

      // Create signature
      final signature = base64.encode(
        Hmac(sha1, utf8.encode(_config!['WASABI_SECRET_KEY']!))
            .convert(utf8.encode(canonicalString))
            .bytes
      );

      // Construct the bucket-specific endpoint
      final endpoint = 'https://${_config!['WASABI_BUCKET']}.s3.${_config!['WASABI_REGION']}.wasabisys.com';
      final deleteUri = Uri.parse('$endpoint/$key');

      // Create headers
      final headers = {
        'Host': deleteUri.host,
        'Date': date,
        'Authorization': 'AWS ${_config!['WASABI_ACCESS_KEY']}:$signature',
      };

      // Send delete request
      final response = await http.delete(
        deleteUri,
        headers: headers,
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete file: ${response.statusCode}\nResponse: ${response.body}');
      }
    } catch (e) {
      print('Error deleting file: $e');
      rethrow;
    }
  }

  /// Record and upload a voice note
  static Future<Map<String, String>?> recordAndUploadVoiceNote(BuildContext context) async {
    final record = Record();
    
    try {
      // Request microphone permission
      if (await record.hasPermission()) {
        // Get temp directory for saving recording
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // Start recording
        await record.start(
          path: tempPath,
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          samplingRate: 44100,
        );
        
        // Show recording dialog
        final shouldStop = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Recording Voice Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Recording in progress...'),
                SizedBox(height: 16),
                Text('Tap Stop when finished'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text('Stop Recording'),
                ),
              ],
            ),
          ),
        );
        
        if (shouldStop == true) {
          // Stop recording
          final path = await record.stop();
          
          if (path != null) {
            // Show uploading dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Text('Uploading Voice Note'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Please wait...'),
                  ],
                ),
              ),
            );

            try {
              // Upload the recorded file
              final file = File(path);
              final uploadResult = await uploadFile(file, 'audio/m4a');
              
              // Delete temp file
              await file.delete();
              
              // Close uploading dialog
              Navigator.of(context).pop();
              
              return {
                'url': uploadResult['url']!,
                'mimeType': 'audio/m4a'
              };
            } catch (e) {
              // Close uploading dialog
              Navigator.of(context).pop();
              rethrow;
            }
          }
        } else {
          // User cancelled recording
          await record.stop();
        }
      } else {
        throw Exception('Microphone permission denied');
      }
    } catch (e) {
      print('Error recording voice note: $e');
      rethrow;
    } finally {
      await record.dispose();
    }
    return null;
  }

  /// Gets a signed URL for viewing a file
  static Future<String> getSignedUrl(String wasabiPath) async {
    if (_config == null) {
      await initialize();
    }

    // Prepare the request
    final date = HttpDate.format(DateTime.now());
    final expires = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600; // 1 hour expiry

    // Create canonical string for signing
    final canonicalString = [
      'GET',
      '',  // MD5
      '',  // Content Type
      expires.toString(),
      '/${_config!['WASABI_BUCKET']}/$wasabiPath'
    ].join('\n');

    // Create signature
    final signature = base64.encode(
      Hmac(sha1, utf8.encode(_config!['WASABI_SECRET_KEY']!))
          .convert(utf8.encode(canonicalString))
          .bytes
    );

    // Construct the bucket-specific endpoint
    final endpoint = 'https://${_config!['WASABI_BUCKET']}.s3.${_config!['WASABI_REGION']}.wasabisys.com';
    final signedUrl = '$endpoint/$wasabiPath?AWSAccessKeyId=${_config!['WASABI_ACCESS_KEY']}&Expires=$expires&Signature=${Uri.encodeComponent(signature)}';

    return signedUrl;
  }
} 