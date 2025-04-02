import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class FoodAnalysisResult {
  final String name;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;

  FoodAnalysisResult({
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });
}

class VisionService {
  static const String _visionApiUrl = 'https://vision.googleapis.com/v1/images:annotate';
  static const String _visionApiKey = 'YOUR_VISION_API_KEY';
  static const String _nutritionApiUrl = 'https://api.nutritionix.com/v1/item';
  static const String _nutritionApiKey = 'YOUR_NUTRITIONIX_API_KEY';

  Future<FoodAnalysisResult> analyzeFoodImage(String imagePath) async {
    try {
      // Read image file as bytes
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Prepare Vision API request
      final response = await http.post(
        Uri.parse('$_visionApiUrl?key=$_visionApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [{
            'image': {
              'content': base64Image,
            },
            'features': [{
              'type': 'LABEL_DETECTION',
              'maxResults': 10,
            }, {
              'type': 'WEB_DETECTION',
              'maxResults': 10,
            }],
          }],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to analyze image: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final labels = data['responses'][0]['labelAnnotations'] as List;
      final webEntities = data['responses'][0]['webDetection']['webEntities'] as List;

      // Combine and filter food-related labels
      final allLabels = [
        ...labels.map((l) => l['description'] as String),
        ...webEntities.where((e) => e['description'] != null).map((e) => e['description'] as String),
      ];

      final foodLabel = allLabels.firstWhere(
        (label) => _isFoodRelated(label),
        orElse: () => throw Exception('No food detected in the image'),
      );

      // Get nutrition information
      final nutritionInfo = await _getNutritionInfo(foodLabel);
      return nutritionInfo;
    } catch (e) {
      print('Error analyzing food image: $e');
      rethrow;
    }
  }

  bool _isFoodRelated(String label) {
    // Add more food-related keywords as needed
    final foodKeywords = [
      'food', 'meal', 'dish', 'cuisine', 'fruit', 'vegetable',
      'meat', 'fish', 'dessert', 'snack', 'breakfast', 'lunch',
      'dinner', 'bread', 'rice', 'pasta', 'salad'
    ];

    return foodKeywords.any((keyword) => 
      label.toLowerCase().contains(keyword.toLowerCase())
    );
  }

  Future<FoodAnalysisResult> _getNutritionInfo(String foodName) async {
    try {
      final response = await http.get(
        Uri.parse('$_nutritionApiUrl?query=$foodName&appId=YOUR_APP_ID&appKey=$_nutritionApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        return FoodAnalysisResult(
          name: foodName,
          calories: data['nf_calories']?.round() ?? 0,
          carbs: data['nf_total_carbohydrate']?.toDouble() ?? 0.0,
          protein: data['nf_protein']?.toDouble() ?? 0.0,
          fat: data['nf_total_fat']?.toDouble() ?? 0.0,
        );
      } else {
        throw Exception('Failed to get nutrition information');
      }
    } catch (e) {
      print('Error getting nutrition info: $e');
      // Return estimated values if API call fails
      return FoodAnalysisResult(
        name: foodName,
        calories: 0,
        carbs: 0.0,
        protein: 0.0,
        fat: 0.0,
      );
    }
  }
} 