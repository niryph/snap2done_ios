import 'dart:convert';
import 'dart:developer' as developer;

/// A mock service for testing OpenAI API responses without making actual API calls
class MockOpenAIService {
  /// Mock response for JSON format (problematic format)
  static const String _mockJsonResponse = '''
{
  "Task List for 'apple'": {
    "1": "Buy apples from the grocery store",
    "2": "Wash and cut the apples for a healthy snack",
    "3": "Make an apple pie for dessert",
    "4": "Try out a new apple recipe for a meal",
    "5": "Research different types of apples and their flavors"
  },
  "Task List for 'banana'": {
    "1": "Purchase ripe bananas from the market",
    "2": "Use bananas in a smoothie for breakfast",
    "3": "Bake banana bread for a homemade treat",
    "4": "Experiment with making banana pancakes for brunch",
    "5": "Learn about the nutritional benefits of bananas"
  }
}
''';

  /// Mock response for the desired format
  static const String _mockDesiredFormatResponse = '''
[medium] Buy apples from the grocery store
[high] Wash and cut the apples for a healthy snack
[low] Make an apple pie for dessert
[medium] Try out a new apple recipe for a meal
[low] Research different types of apples and their flavors
[medium] Purchase ripe bananas from the market
[high] Use bananas in a smoothie for breakfast
[medium] Bake banana bread for a homemade treat
[low] Experiment with making banana pancakes for brunch
[low] Learn about the nutritional benefits of bananas
''';

  /// Generate a mock todo list response
  /// 
  /// If [useJsonFormat] is true, returns the problematic JSON format
  /// Otherwise returns the desired [priority] format
  static Future<dynamic> generateTodoList(String text, {bool useJsonFormat = true}) async {
    print("🔵 MOCK OPENAI API CALL with text: ${text.length > 50 ? text.substring(0, 50) + '...' : text}");
    developer.log('Mock API Request to OpenAI:', name: 'MockOpenAIService');
    developer.log('User text: $text', name: 'MockOpenAIService');
    
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Choose which mock response to use
    final content = useJsonFormat ? _mockJsonResponse : _mockDesiredFormatResponse;
    
    print("🔵 MOCK OPENAI CONTENT: $content");
    developer.log('Mock content from OpenAI: $content', name: 'MockOpenAIService');
    
    // Process the content using the same method as the real service
    final result = _processResponseContent(content);
    
    // Log the processed result
    print("🔵 MOCK PROCESSED RESULT: ${json.encode(result)}");
    developer.log('Mock processed result: ${json.encode(result)}', name: 'MockOpenAIService');
    
    return result;
  }
  
  /// Process the raw response content into a structured format
  /// This is a copy of the method from OpenAIService to ensure consistent behavior
  static Map<String, dynamic> _processResponseContent(String content) {
    // Default title
    String title = 'Generated Todo List';
    List<Map<String, dynamic>> items = [];
    
    try {
      developer.log('Processing mock response content: $content', name: 'MockOpenAIService');
      
      // Check if the content is already in the [priority] format
      final lines = content.split('\n');
      bool isPriorityFormat = true;
      List<String> priorityFormattedLines = [];
      
      // Check if all non-empty lines match the [priority] format
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        
        final priorityTagMatch = RegExp(r'^\[(high|medium|low)\]\s*(.+)$', caseSensitive: false).firstMatch(trimmedLine);
        if (priorityTagMatch == null) {
          isPriorityFormat = false;
          break;
        }
        priorityFormattedLines.add(trimmedLine);
      }
      
      // If content is already in [priority] format, process it directly
      if (isPriorityFormat && priorityFormattedLines.isNotEmpty) {
        developer.log('Content is already in [priority] format, processing directly', name: 'MockOpenAIService');
        int id = 1;
        for (final line in priorityFormattedLines) {
          final priorityTagMatch = RegExp(r'^\[(high|medium|low)\]\s*(.+)$', caseSensitive: false).firstMatch(line);
          if (priorityTagMatch != null) {
            final priority = priorityTagMatch.group(1)!.toLowerCase() == 'high' ? 'High' : 
                      priorityTagMatch.group(1)!.toLowerCase() == 'low' ? 'Low' : 'Medium';
            final description = priorityTagMatch.group(2)!.trim();
            
            items.add({
              'id': id++,
              'description': description,
              'priority': priority,
            });
            developer.log('Added item from priority format: $description (Priority: $priority)', name: 'MockOpenAIService');
          }
        }
        
        return {
          'title': title,
          'items': items,
        };
      }
      
      // First, try to parse as JSON if it looks like JSON
      if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
        try {
          // Try to parse as JSON
          developer.log('Content appears to be JSON, attempting to parse', name: 'MockOpenAIService');
          final Map<String, dynamic> jsonData = json.decode(content);
          
          // If we have a title in the JSON, use it
          if (jsonData.containsKey('title')) {
            title = jsonData['title'].toString();
            developer.log('Found title in JSON: $title', name: 'MockOpenAIService');
          }
          
          // If we have items in the JSON, use them
          if (jsonData.containsKey('items') && jsonData['items'] is List) {
            final List<dynamic> jsonItems = jsonData['items'];
            developer.log('Found ${jsonItems.length} items in JSON', name: 'MockOpenAIService');
            
            items = jsonItems.map((item) {
              if (item is Map) {
                return {
                  'id': item['id'] ?? items.length + 1,
                  'description': item['description']?.toString() ?? 'Task',
                  'priority': item['priority']?.toString() ?? 'Medium',
                };
              }
              return {'id': items.length + 1, 'description': item.toString(), 'priority': 'Medium'};
            }).toList().cast<Map<String, dynamic>>();
          }
          
          // If we successfully parsed JSON but didn't get items, return empty list
          if (items.isEmpty) {
            developer.log('No items found in JSON, trying to extract from other fields', name: 'MockOpenAIService');
            // Try to extract items from other fields
            jsonData.forEach((key, value) {
              if (value is Map && key != 'title') {
                // Handle nested maps like {"Task List for 'apple'": {"1": "Buy apples", ...}}
                final Map<String, dynamic> taskMap = value as Map<String, dynamic>;
                taskMap.forEach((taskKey, taskValue) {
                  items.add({
                    'id': items.length + 1,
                    'description': taskValue.toString(),
                    'priority': 'Medium',
                  });
                  developer.log('Added item from nested map: $taskValue', name: 'MockOpenAIService');
                });
              } else if (value is List && key != 'title') {
                final List<dynamic> possibleItems = value;
                developer.log('Found potential items in field "$key": ${possibleItems.length} items', name: 'MockOpenAIService');
                
                items = possibleItems.map((item) {
                  if (item is Map) {
                    return {
                      'id': item['id'] ?? items.length + 1,
                      'description': item['description']?.toString() ?? item.toString(),
                      'priority': item['priority']?.toString() ?? 'Medium',
                    };
                  }
                  return {'id': items.length + 1, 'description': item.toString(), 'priority': 'Medium'};
                }).toList().cast<Map<String, dynamic>>();
              }
            });
          }
        } catch (e) {
          // If JSON parsing fails, fall back to text parsing
          developer.log('JSON parsing failed: $e', name: 'MockOpenAIService');
        }
      }
      
      // If we couldn't parse as JSON or didn't get any items, parse as text
      if (items.isEmpty) {
        developer.log('Parsing content as plain text', name: 'MockOpenAIService');
        // Split the content into lines
        final lines = content.split('\n');
        developer.log('Split content into ${lines.length} lines', name: 'MockOpenAIService');
        
        // Try to extract a title from the first line
        if (lines.isNotEmpty && !lines[0].contains(':') && 
            !lines[0].startsWith('-') && !lines[0].startsWith('•') && 
            !lines[0].startsWith('*') && !RegExp(r'^\d+\.').hasMatch(lines[0]) &&
            !RegExp(r'^\[.*\]').hasMatch(lines[0])) {
          title = lines[0].trim();
          developer.log('Extracted title from first line: $title', name: 'MockOpenAIService');
          lines.removeAt(0);
        }
        
        // Process the remaining lines into tasks
        int id = 1;
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;
          
          // Extract task description and priority
          String description = trimmedLine;
          String priority = 'Medium'; // Default priority
          
          // Check for the [priority] format first (e.g., "[high] Buy milk")
          final priorityTagMatch = RegExp(r'^\[(high|medium|low)\]\s*(.+)$', caseSensitive: false).firstMatch(trimmedLine);
          if (priorityTagMatch != null) {
            priority = priorityTagMatch.group(1)!.toLowerCase() == 'high' ? 'High' : 
                      priorityTagMatch.group(1)!.toLowerCase() == 'low' ? 'Low' : 'Medium';
            description = priorityTagMatch.group(2)!.trim();
            developer.log('Found [priority] format: $priority - $description', name: 'MockOpenAIService');
          }
          // Check if the line contains priority information
          else if (trimmedLine.toLowerCase().contains('priority:')) {
            final parts = trimmedLine.split('priority:');
            if (parts.length > 1) {
              description = parts[0].trim();
              final priorityText = parts[1].trim().toLowerCase();
              
              if (priorityText.contains('high')) {
                priority = 'High';
              } else if (priorityText.contains('medium')) {
                priority = 'Medium';
              } else if (priorityText.contains('low')) {
                priority = 'Low';
              }
              developer.log('Found priority in text: $priority', name: 'MockOpenAIService');
            }
          } else if (trimmedLine.toLowerCase().contains('(priority:')) {
            final parts = trimmedLine.split('(priority:');
            if (parts.length > 1) {
              description = parts[0].trim();
              final priorityText = parts[1].replaceAll(')', '').trim().toLowerCase();
              
              if (priorityText.contains('high')) {
                priority = 'High';
              } else if (priorityText.contains('medium')) {
                priority = 'Medium';
              } else if (priorityText.contains('low')) {
                priority = 'Low';
              }
              developer.log('Found priority in parentheses: $priority', name: 'MockOpenAIService');
            }
          } else if (trimmedLine.toLowerCase().contains('[high]')) {
            priority = 'High';
            description = trimmedLine.replaceAll(RegExp(r'\[high\]', caseSensitive: false), '').trim();
            developer.log('Found [High] tag', name: 'MockOpenAIService');
          } else if (trimmedLine.toLowerCase().contains('[medium]')) {
            priority = 'Medium';
            description = trimmedLine.replaceAll(RegExp(r'\[medium\]', caseSensitive: false), '').trim();
            developer.log('Found [Medium] tag', name: 'MockOpenAIService');
          } else if (trimmedLine.toLowerCase().contains('[low]')) {
            priority = 'Low';
            description = trimmedLine.replaceAll(RegExp(r'\[low\]', caseSensitive: false), '').trim();
            developer.log('Found [Low] tag', name: 'MockOpenAIService');
          }
          
          // Clean up the description (remove bullet points, numbers, etc.)
          final originalDescription = description;
          description = description
              .replaceAll(RegExp(r'^[-•*]\s*'), '') // Remove bullet points
              .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove numbered lists
              .trim();
          
          if (description != originalDescription) {
            developer.log('Cleaned up description: "$originalDescription" -> "$description"', name: 'MockOpenAIService');
          }
          
          if (description.isNotEmpty) {
            items.add({
              'id': id++,
              'description': description,
              'priority': priority,
            });
            developer.log('Added item: $description (Priority: $priority)', name: 'MockOpenAIService');
          }
        }
      }
      
      developer.log('Final result: Title="$title", ${items.length} items', name: 'MockOpenAIService');
      
      // Return the structured data
      return {
        'title': title,
        'items': items,
      };
    } catch (e) {
      developer.log('Error processing response: $e', name: 'MockOpenAIService');
      // Return a basic structure in case of error
      return {
        'title': 'Generated Todo List',
        'items': [
          {'id': 1, 'description': 'Error processing response', 'priority': 'Medium'}
        ],
      };
    }
  }
} 