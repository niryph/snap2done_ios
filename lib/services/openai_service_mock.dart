import 'dart:developer' as developer;
import 'openai_service.dart' as openai_interface;

/// Mock implementation of OpenAIService for testing
class OpenAIServiceMock implements openai_interface.OpenAIService {
  @override
  Future<List<Map<String, dynamic>>> generateTodoList(String text) async {
    // Simulate network delay
    developer.log('Using mock OpenAI service', name: 'OpenAIServiceMock');
    await Future.delayed(Duration(seconds: 1));
    
    // Generate mock todos based on the input text
    final List<Map<String, dynamic>> todos = [];
    
    // If the text contains specific keywords, generate relevant todos
    if (text.toLowerCase().contains('grocery') || text.toLowerCase().contains('shopping')) {
      todos.addAll([
        {'task': 'Buy milk', 'priority': 'high'},
        {'task': 'Get bread', 'priority': 'medium'},
        {'task': 'Purchase eggs', 'priority': 'medium'},
        {'task': 'Pick up cheese', 'priority': 'low'},
        {'task': 'Buy vegetables', 'priority': 'high'},
      ]);
    } else if (text.toLowerCase().contains('work') || text.toLowerCase().contains('project')) {
      todos.addAll([
        {'task': 'Complete project report', 'priority': 'high'},
        {'task': 'Schedule team meeting', 'priority': 'medium'},
        {'task': 'Review code changes', 'priority': 'high'},
        {'task': 'Update documentation', 'priority': 'medium'},
        {'task': 'Send weekly update', 'priority': 'low'},
      ]);
    } else if (text.toLowerCase().contains('home') || text.toLowerCase().contains('house')) {
      todos.addAll([
        {'task': 'Clean kitchen', 'priority': 'medium'},
        {'task': 'Do laundry', 'priority': 'high'},
        {'task': 'Vacuum living room', 'priority': 'medium'},
        {'task': 'Water plants', 'priority': 'low'},
        {'task': 'Take out trash', 'priority': 'high'},
      ]);
    } else {
      // Default todos if no specific keywords are found
      todos.addAll([
        {'task': 'Task 1 from input text', 'priority': 'high'},
        {'task': 'Task 2 from input text', 'priority': 'medium'},
        {'task': 'Task 3 from input text', 'priority': 'low'},
        {'task': 'Task 4 from input text', 'priority': 'medium'},
        {'task': 'Task 5 from input text', 'priority': 'high'},
      ]);
    }
    
    developer.log('Generated ${todos.length} mock todos', name: 'OpenAIServiceMock');
    return todos;
  }
} 