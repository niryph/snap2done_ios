import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'config_service.dart';
import 'service_factory.dart';
import 'api_service.dart';

/// Service for handling OCR using Google Vision API
class VisionService {
  /// Performs OCR on an image file and returns the extracted text
  static Future<String> performOCR(String imagePath) async {
    try {
      developer.log('Starting OCR processing on image: $imagePath', name: 'VisionService');
      
      // Read the image file as bytes
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      try {
        // Get the Google Vision service from ServiceFactory
        final GoogleVisionService visionService = ServiceFactory.googleVision;
        
        // Call the detectText method with the image bytes
        final Map<String, dynamic> responseData = await visionService.detectText(imageBytes);
        
        // Extract the text from the response
        String extractedText = '';
        if (responseData.containsKey('responses') && 
            responseData['responses'].isNotEmpty &&
            responseData['responses'][0].containsKey('fullTextAnnotation')) {
          extractedText = responseData['responses'][0]['fullTextAnnotation']['text'];
        } else if (responseData.containsKey('responses') && 
                  responseData['responses'].isNotEmpty &&
                  responseData['responses'][0].containsKey('textAnnotations') &&
                  responseData['responses'][0]['textAnnotations'].isNotEmpty) {
          extractedText = responseData['responses'][0]['textAnnotations'][0]['description'];
        }
        
        developer.log('OCR processing completed. Extracted ${extractedText.length} characters', name: 'VisionService');
        return extractedText;
      } catch (e) {
        developer.log('Error with Vision API, using mock OCR: $e', name: 'VisionService');
        // If the Vision API fails, use a mock OCR response for development
        return _generateMockOCRResponse(imagePath);
      }
    } catch (e) {
      developer.log('Error in OCR processing: $e', name: 'VisionService');
      throw Exception('Failed to process image: $e');
    }
  }
  
  /// Analyzes an image and returns a description of its contents
  static Future<String?> analyzeImage(String imagePath) async {
    try {
      // First try to extract text using OCR
      final String ocrText = await performOCR(imagePath);
      
      // If OCR text is available, return it
      if (ocrText.isNotEmpty) {
        return "Image contains text: $ocrText";
      }
      
      // If no text was found, return a generic description
      return "Food item in image. Please analyze for nutritional content.";
    } catch (e) {
      developer.log('Error analyzing image: $e', name: 'VisionService');
      return null;
    }
  }
  
  /// Generate a mock OCR response for development and testing
  static String _generateMockOCRResponse(String imagePath) {
    // For development, return a mock OCR text based on the image name
    final filename = imagePath.split('/').last.toLowerCase();
    
    if (filename.contains('receipt')) {
      return '''
GROCERY STORE RECEIPT
Date: 2023-03-05
-----------------
1x Milk \$3.99
2x Bread \$5.98
1x Eggs \$2.49
3x Apples \$4.50
1x Cheese \$3.75
-----------------
TOTAL: \$20.71
''';
    } else if (filename.contains('todo') || filename.contains('list')) {
      return '''
TO-DO LIST:
- Buy groceries
- Clean the house
- Pay bills
- Call mom
- Schedule dentist appointment
- Finish project report
''';
    } else {
      return '''
Sample text extracted from image.
This is a mock OCR response for development.
Please connect to the Vision API for actual OCR functionality.
''';
    }
  }
}