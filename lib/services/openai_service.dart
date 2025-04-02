import 'dart:convert';
import 'dart:developer' as developer;

/// Abstract class defining the interface for OpenAI services
abstract class OpenAIService {
  /// Call OpenAI API to generate a todo list from the given text
  Future<List<Map<String, dynamic>>> generateTodoList(String text);
}

/// Utility class for processing OpenAI responses
class OpenAIResponseProcessor {
  /// Process the raw response content into a structured format
  static List<Map<String, dynamic>> processResponseContent(String content) {
    List<Map<String, dynamic>> items = [];
    
    try {
      // Check if the content is already in the [priority] format
      final lines = content.split('\n');
      
      // Process the lines into tasks
      int id = 1;
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        
        // Extract task description and priority
        String description = trimmedLine;
        String priority = 'medium'; // Default priority
        
        // Check for the [priority] format first (e.g., "[high] Buy milk")
        final priorityTagMatch = RegExp(r'^\[(high|medium|low)\]\s*(.+)$', caseSensitive: false).firstMatch(trimmedLine);
        if (priorityTagMatch != null) {
          priority = priorityTagMatch.group(1)!.toLowerCase();
          description = priorityTagMatch.group(2)!.trim();
        }
        // Check if the line contains priority information
        else if (trimmedLine.toLowerCase().contains('priority:')) {
          final parts = trimmedLine.split('priority:');
          if (parts.length > 1) {
            description = parts[0].trim();
            final priorityText = parts[1].trim().toLowerCase();
            
            if (priorityText.contains('high')) {
              priority = 'high';
            } else if (priorityText.contains('low')) {
              priority = 'low';
            } else {
              priority = 'medium';
            }
          }
        } else if (trimmedLine.toLowerCase().contains('(priority:')) {
          final parts = trimmedLine.split('(priority:');
          if (parts.length > 1) {
            description = parts[0].trim();
            final priorityText = parts[1].replaceAll(')', '').trim().toLowerCase();
            
            if (priorityText.contains('high')) {
              priority = 'high';
            } else if (priorityText.contains('low')) {
              priority = 'low';
            } else {
              priority = 'medium';
            }
          }
        } else if (trimmedLine.toLowerCase().contains('[high]')) {
          priority = 'high';
          description = trimmedLine.replaceAll(RegExp(r'\[high\]', caseSensitive: false), '').trim();
        } else if (trimmedLine.toLowerCase().contains('[medium]')) {
          priority = 'medium';
          description = trimmedLine.replaceAll(RegExp(r'\[medium\]', caseSensitive: false), '').trim();
        } else if (trimmedLine.toLowerCase().contains('[low]')) {
          priority = 'low';
          description = trimmedLine.replaceAll(RegExp(r'\[low\]', caseSensitive: false), '').trim();
        }
        
        // Clean up the description (remove bullet points, numbers, etc.)
        description = description
            .replaceAll(RegExp(r'^[-•*]\s*'), '') // Remove bullet points
            .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove numbered lists
            .trim();
        
        if (description.isNotEmpty) {
          items.add({
            'task': description,
            'priority': priority,
          });
        }
      }
      
      return items;
    } catch (e) {
      // Return a basic structure in case of error
      return [
        {'task': 'Error processing response', 'priority': 'medium'}
      ];
    }
  }
}