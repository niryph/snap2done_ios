import 'package:flutter/material.dart';
import 'dart:async'; // Add this import for StreamController
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../models/card_model.dart';
import '../models/task_model.dart';

class CardService {
  // Singleton pattern
  static final CardService _instance = CardService._internal();
  factory CardService() => _instance;
  CardService._internal();
  
  static SupabaseClient get _client => Supabase.instance.client;
  
  // Stream controller to notify listeners when cards change
  static final _cardStreamController = StreamController<List<CardModel>>.broadcast();
  static Stream<List<CardModel>> get cardStream => _cardStreamController.stream;
  
  // Get all cards with their tasks
  static Future<List<CardModel>> getCards() async {
    try {
      // Fetch cards
      final cardsResponse = await _client
          .from('cards')
          .select()
          .order('created_at', ascending: false);
      
      final List<CardModel> cards = List<Map<String, dynamic>>.from(cardsResponse)
          .map((map) => CardModel.fromMap(map))
          .toList();
      
      // Fetch tasks for each card
      for (var card in cards) {
        final tasksResponse = await _client
            .from('tasks')
            .select()
            .eq('card_id', card.id)
            .order('position', ascending: true);
        
        card.tasks = List<Map<String, dynamic>>.from(tasksResponse)
            .map((map) => TaskModel.fromMap(map))
            .toList();
        
        // Update task count
        card.taskCount = card.tasks.length;
      }
      
      // Notify listeners
      _cardStreamController.add(cards);
      
      return cards;
    } catch (e) {
      debugPrint('Error fetching cards: $e');
      // Return empty list for now to avoid breaking the UI
      return [];
    }
  }
  
  // Create a new card with tasks
  static Future<CardModel> createCard(Map<String, dynamic> cardData, {bool notifyListeners = true}) async {
    try {
      // Get current user ID
      final userId = _client.auth.currentUser?.id;
      debugPrint('Creating card for user: $userId');
      
      if (userId == null) {
        debugPrint('Error: User not authenticated');
        throw Exception('User not authenticated');
      }

      // Extract tasks before creating the card
      final List<Map<String, dynamic>> tasksData = 
          cardData.containsKey('tasks') ? List<Map<String, dynamic>>.from(cardData['tasks']) : [];
      
      debugPrint('Card has ${tasksData.length} tasks');
      
      // Remove tasks from card data as they will be inserted separately
      final cardDataWithoutTasks = Map<String, dynamic>.from(cardData);
      cardDataWithoutTasks.remove('tasks');

      // Add user_id to card data
      cardDataWithoutTasks['user_id'] = userId;
      
      // Ensure created_at and updated_at are set
      if (!cardDataWithoutTasks.containsKey('created_at') || cardDataWithoutTasks['created_at'] == null) {
        cardDataWithoutTasks['created_at'] = DateTime.now().toIso8601String();
      }
      
      if (!cardDataWithoutTasks.containsKey('updated_at') || cardDataWithoutTasks['updated_at'] == null) {
        cardDataWithoutTasks['updated_at'] = DateTime.now().toIso8601String();
      }
      
      // Ensure task_count is set
      cardDataWithoutTasks['task_count'] = tasksData.length;
      
      // Ensure progress is set
      if (!cardDataWithoutTasks.containsKey('progress') || cardDataWithoutTasks['progress'] == null) {
        cardDataWithoutTasks['progress'] = '0%';
      }

      // If this is a water intake card, ensure metadata is properly initialized
      if (cardData['metadata']?['type'] == 'water_intake') {
        cardDataWithoutTasks['metadata'] = {
          ...cardData['metadata'] ?? {},
          'dailyGoal': cardData['metadata']?['dailyGoal'] ?? 2000.0,
          'dailyEntries': cardData['metadata']?['dailyEntries'] ?? {},
          'reminderSettings': cardData['metadata']?['reminderSettings'] ?? {
            'enabled': false,
            'intervalHours': 2,
            'startTime': {'hour': 8, 'minute': 0},
            'endTime': {'hour': 22, 'minute': 0},
          },
        };
      }

      debugPrint('Creating card in database with data: ${cardDataWithoutTasks.toString()}');

      // Create card in database
      final response = await _client
          .from('cards')
          .insert(cardDataWithoutTasks)
          .select()
          .single();
      
      debugPrint('Card created successfully with ID: ${response['id']}');

      // Convert response to CardModel
      final card = CardModel.fromMap(response);

      // Insert tasks if any
      if (tasksData.isNotEmpty) {
        debugPrint('Inserting ${tasksData.length} tasks for card ${card.id}');
        
        final tasksToInsert = tasksData.map((task) => {
          ...task,
          'card_id': card.id,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).toList();

        final tasksResponse = await _client
            .from('tasks')
            .insert(tasksToInsert)
            .select();
        
        debugPrint('Tasks inserted successfully: ${tasksResponse.length} tasks');

        card.tasks = List<Map<String, dynamic>>.from(tasksResponse)
            .map((map) => TaskModel.fromMap(map))
            .toList();
      } else {
        card.tasks = [];
      }

      // Notify listeners only if requested
      if (notifyListeners) {
        debugPrint('Notifying listeners about new card');
        final cards = await getCards();
        _cardStreamController.add(cards);
      } else {
        debugPrint('Skipping listener notification for new card');
      }

      return card;
    } catch (e) {
      debugPrint('Error creating card: $e');
      rethrow;
    }
  }
  
  // Update an existing card and its tasks
  static Future<CardModel> updateCard(Map<String, dynamic> cardData) async {
    try {
      final cardId = cardData['id'];
      if (cardId == null) {
        throw Exception('Card ID is required for updates');
      }
      
      // Extract tasks from the card data
      final List<Map<String, dynamic>> tasksData = 
          cardData.containsKey('tasks') ? List<Map<String, dynamic>>.from(cardData['tasks']) : [];
      
      // Prepare card data for database
      final cardDbData = {
        'title': cardData['title'],
        'description': cardData['description'],
        'is_archived': cardData['isArchived'] ?? false,
        'is_favorited': cardData['isFavorited'] ?? false,
        'progress': cardData['progress'] ?? '0%',
        'task_count': tasksData.length,
        'tags': cardData['tags'] ?? ['Personal'],
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Add color if it exists
      if (cardData.containsKey('color') && cardData['color'] != null) {
        cardDbData['color'] = cardData['color'].toString();
      }
      
      // Add metadata if it exists
      if (cardData.containsKey('metadata') && cardData['metadata'] != null) {
        cardDbData['metadata'] = cardData['metadata'];
        debugPrint('Updating card with metadata: ${cardData['metadata']}');
      }
      
      // Update card
      final cardResponse = await _client
          .from('cards')
          .update(cardDbData)
          .eq('id', cardId)
          .select()
          .single();
      
      // Create card model
      final card = CardModel.fromMap(cardResponse);
      
      // Get existing tasks
      final existingTasksResponse = await _client
          .from('tasks')
          .select()
          .eq('card_id', cardId);
      
      final List<TaskModel> existingTasks = List<Map<String, dynamic>>.from(existingTasksResponse)
          .map((map) => TaskModel.fromMap(map))
          .toList();
      
      // Create a map of existing tasks by ID for easy lookup
      final Map<String, TaskModel> existingTasksMap = {};
      for (var task in existingTasks) {
        existingTasksMap[task.id] = task;
      }
      
      // Process tasks
      if (tasksData.isNotEmpty) {
        final List<Map<String, dynamic>> tasksToInsert = [];
        final List<Map<String, dynamic>> tasksToUpdate = [];
        final Set<String> processedTaskIds = {};
        
        for (int i = 0; i < tasksData.length; i++) {
          final task = tasksData[i];
          
          // Extract priority from description if needed
          String priority = 'medium';
          if (task.containsKey('description') && 
              task['description'] is String && 
              task['description'].toString().contains('Priority:')) {
            final priorityMatch = RegExp(r'Priority:\s*(\w+)').firstMatch(task['description']);
            if (priorityMatch != null && priorityMatch.groupCount >= 1) {
              priority = priorityMatch.group(1)!.toLowerCase();
            }
          } else if (task.containsKey('priority')) {
            priority = task['priority'];
          }
          
          // Check if task has an ID and exists
          if (task.containsKey('id') && task['id'] != null && existingTasksMap.containsKey(task['id'])) {
            // Update existing task
            tasksToUpdate.add({
              'id': task['id'],
              'description': task['title'] ?? 'Task ${i + 1}',
              'is_completed': task['isCompleted'] ?? false,
              'priority': priority,
              'notes': task['description'] ?? null,
              'position': i,
              'updated_at': DateTime.now().toIso8601String(),
            });
            
            processedTaskIds.add(task['id']);
          } else {
            // Insert new task
            tasksToInsert.add({
              'card_id': cardId,
              'description': task['title'] ?? 'Task ${i + 1}',
              'is_completed': task['isCompleted'] ?? false,
              'priority': priority,
              'notes': task['description'] ?? null,
              'position': i,
            });
          }
        }
        
        // Delete tasks that are no longer in the list
        final tasksToDelete = existingTasks
            .where((task) => !processedTaskIds.contains(task.id))
            .map((task) => task.id)
            .toList();
        
        if (tasksToDelete.isNotEmpty) {
          // Delete tasks one by one since in_ method is not available
          for (final taskId in tasksToDelete) {
            await _client
                .from('tasks')
                .delete()
                .eq('id', taskId);
          }
        }
        
        // Update existing tasks
        if (tasksToUpdate.isNotEmpty) {
          for (var task in tasksToUpdate) {
            await _client
                .from('tasks')
                .update(task)
                .eq('id', task['id']);
          }
        }
        
        // Insert new tasks
        if (tasksToInsert.isNotEmpty) {
          await _client
              .from('tasks')
              .insert(tasksToInsert);
        }
        
        // Fetch updated tasks
        final updatedTasksResponse = await _client
            .from('tasks')
            .select()
            .eq('card_id', cardId)
            .order('position', ascending: true);
        
        card.tasks = List<Map<String, dynamic>>.from(updatedTasksResponse)
            .map((map) => TaskModel.fromMap(map))
            .toList();
      } else {
        // Delete all tasks if the new task list is empty
        await _client
            .from('tasks')
            .delete()
            .eq('card_id', cardId);
        
        card.tasks = [];
      }
      
      return card;
    } catch (e) {
      debugPrint('Error updating card: $e');
      rethrow;
    }
  }
  
  // Delete a card and its tasks
  static Future<void> deleteCard(String id) async {
    try {
      // Delete tasks first (foreign key constraint)
      await _client
          .from('tasks')
          .delete()
          .eq('card_id', id);
      
      // Delete card
      await _client
          .from('cards')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('Error deleting card: $e');
      rethrow;
    }
  }
  
  // Convert CardModel to legacy format for backward compatibility
  static Map<String, dynamic> _formatCardForUi(CardModel card) {
    return card.toUiMap();
  }
  
  // Dispose resources
  static void dispose() {
    _cardStreamController.close();
  }
  
  // Update a task's completion status and the card's progress
  static Future<CardModel> updateTaskCompletion(String cardId, String taskId, bool isCompleted) async {
    try {
      debugPrint('Updating task completion: cardId=$cardId, taskId=$taskId, isCompleted=$isCompleted');
      
      // Update the task
      await _client
          .from('tasks')
          .update({
            'is_completed': isCompleted,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      
      debugPrint('Task updated successfully in database');
      
      // Get all tasks for the card to calculate progress
      final tasksResponse = await _client
          .from('tasks')
          .select()
          .eq('card_id', cardId);
      
      final List<TaskModel> tasks = List<Map<String, dynamic>>.from(tasksResponse)
          .map((map) => TaskModel.fromMap(map))
          .toList();
      
      // Calculate progress percentage
      final int totalTasks = tasks.length;
      final int completedTasks = tasks.where((task) => task.isCompleted).length;
      final int progressPercentage = totalTasks > 0 
          ? ((completedTasks / totalTasks) * 100).round() 
          : 0;
      
      final String progress = '$progressPercentage%';
      
      debugPrint('Calculated progress: $progress (completed: $completedTasks, total: $totalTasks)');
      
      // Update the card's progress
      final cardResponse = await _client
          .from('cards')
          .update({
            'progress': progress,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cardId)
          .select()
          .single();
      
      debugPrint('Card progress updated in database: ${cardResponse['progress']}');
      
      // Create card model
      final card = CardModel.fromMap(cardResponse);
      card.tasks = tasks;
      
      debugPrint('Returning updated card with progress: ${card.progress}');
      
      return card;
    } catch (e) {
      debugPrint('Error updating task completion: $e');
      rethrow;
    }
  }
  
  // Update a card's pin/favorite status
  static Future<CardModel> updateCardPinStatus(String cardId, bool isFavorited) async {
    try {
      debugPrint('Updating card pin status: cardId=$cardId, isFavorited=$isFavorited');
      
      // Update the card's is_favorited field
      final cardResponse = await _client
          .from('cards')
          .update({
            'is_favorited': isFavorited,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cardId)
          .select()
          .single();
      
      debugPrint('Card pin status updated in database: ${cardResponse['is_favorited']}');
      
      // Get tasks for the card
      final tasksResponse = await _client
          .from('tasks')
          .select()
          .eq('card_id', cardId)
          .order('position', ascending: true);
      
      // Create card model
      final card = CardModel.fromMap(cardResponse);
      card.tasks = List<Map<String, dynamic>>.from(tasksResponse)
          .map((map) => TaskModel.fromMap(map))
          .toList();
      
      return card;
    } catch (e) {
      debugPrint('Error updating card pin status: $e');
      rethrow;
    }
  }

  // Update a task's reminder date
  static Future<CardModel> updateTaskReminder(String cardId, String taskId, DateTime reminderDate) async {
    try {
      debugPrint('Updating task reminder: cardId=$cardId, taskId=$taskId, reminderDate=$reminderDate');
      
      // Update the task's reminder_date field
      await _client
          .from('tasks')
          .update({
            'reminder_date': reminderDate.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);
      
      debugPrint('Task reminder updated in database');
      
      // Get the updated card with all tasks
      final cardResponse = await _client
          .from('cards')
          .select()
          .eq('id', cardId)
          .single();
      
      final tasksResponse = await _client
          .from('tasks')
          .select()
          .eq('card_id', cardId)
          .order('position', ascending: true);
      
      // Create card model
      final card = CardModel.fromMap(cardResponse);
      card.tasks = List<Map<String, dynamic>>.from(tasksResponse)
          .map((map) => TaskModel.fromMap(map))
          .toList();
      
      return card;
    } catch (e) {
      debugPrint('Error updating task reminder: $e');
      rethrow;
    }
  }

  // Update a card's metadata
  static Future<void> updateCardMetadata(String cardId, Map<String, dynamic> metadata) async {
    try {
      debugPrint('Updating card metadata: cardId=$cardId, type=${metadata['type']}');
      
      // Debug logging for priorities
      if (metadata['type'] == 'top_priorities') {
        final dateKeys = metadata['priorities']?.keys ?? [];
        debugPrint('Top priorities metadata has ${dateKeys.length} date entries');
        
        for (final dateKey in dateKeys) {
          final tasks = metadata['priorities'][dateKey]['tasks'] ?? [];
          debugPrint('Date $dateKey has ${tasks.length} tasks');
          
          for (int i = 0; i < tasks.length; i++) {
            debugPrint('Task $i: id=${tasks[i]['id']}, description=${tasks[i]['description']}');
          }
        }
      }
      
      // Debug logging for mood_gratitude
      if (metadata['type'] == 'mood_gratitude') {
        final entriesList = metadata['entries'] as List<dynamic>? ?? [];
        debugPrint('Mood & gratitude metadata has ${entriesList.length} entries');
        
        // Print the latest 3 entries
        final entriesToLog = entriesList.length > 3 ? entriesList.sublist(0, 3) : entriesList;
        for (int i = 0; i < entriesToLog.length; i++) {
          final entry = entriesToLog[i];
          debugPrint('Entry $i: date=${entry['date']}, mood=${entry['mood']}');
        }
        
        if (metadata.containsKey('settings')) {
          debugPrint('Mood & gratitude settings: ${metadata['settings']}');
        } else {
          debugPrint('WARNING: Mood & gratitude card has no settings');
        }
        
        if (metadata.containsKey('todayMood')) {
          debugPrint('Today\'s mood: ${metadata['todayMood']}');
        }
      }
      
      await _client
          .from('cards')
          .update({
            'metadata': metadata,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cardId);
      
      debugPrint('Card metadata updated successfully');
    } catch (e) {
      debugPrint('Error updating card metadata: $e');
      rethrow;
    }
  }

  // Get a card by ID with its tasks
  static Future<CardModel> getCardById(String cardId) async {
    try {
      debugPrint('Getting card by ID: $cardId');
      
      // Fetch the card
      final cardResponse = await _client
          .from('cards')
          .select()
          .eq('id', cardId)
          .single();
      
      final card = CardModel.fromMap(cardResponse);
      
      // Fetch tasks for the card
      final tasksResponse = await _client
          .from('tasks')
          .select()
          .eq('card_id', cardId)
          .order('position', ascending: true);
      
      card.tasks = List<Map<String, dynamic>>.from(tasksResponse)
          .map((map) => TaskModel.fromMap(map))
          .toList();
      
      // Update task count
      card.taskCount = card.tasks.length;
      
      debugPrint('Found card with ${card.tasks.length} tasks');
      
      return card;
    } catch (e) {
      debugPrint('Error getting card by ID: $e');
      throw Exception('Card not found or error retrieving card: $e');
    }
  }
  
  // Delete a task by ID
  static Future<void> deleteTask(String taskId) async {
    try {
      debugPrint('Deleting task: $taskId');
      
      await _client
          .from('tasks')
          .delete()
          .eq('id', taskId);
      
      debugPrint('Task deleted successfully');
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }
}