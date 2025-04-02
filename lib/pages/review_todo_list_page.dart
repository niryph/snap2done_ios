import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Add this import for SystemUiOverlayStyle
import '../services/service_factory.dart';
import '../models/task_model.dart';
import '../models/card_model.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:ui'; // Add this import for lerpDouble
import 'dart:io'; // Add this import for Platform
import 'package:app_settings/app_settings.dart'; // Add this import for AppSettings
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Add this import for color picker
import '../services/notification_service.dart'; // Add this import for notification service
import 'package:uuid/uuid.dart'; // Add this import for UUID generation
import '../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../utils/theme_provider.dart';
import '../services/todo_service.dart';
import '../models/todo_settings_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart' show ExpansionTileController;

class TodoItem {
  String id; // Changed from int to String to match UUID in database
  String description;
  bool isEditing;
  bool isCompleted; // Added to match database
  String priority;
  String? notes; // Added to match database
  int position; // Added to match database
  TextEditingController controller;
  TextEditingController notesController;
  bool isEditingPriority;
  DateTime? reminderDate; // Added for reminder feature
  Map<String, dynamic> metadata; // Add metadata field
  bool isExpanded = false; // Replace GlobalKey with this
  final GlobalKey expansionTileKey = GlobalKey();
  
  // Add fields to store original values
  String? _originalDescription;
  String? _originalNotes;
  String? _originalPriority;
  DateTime? _originalReminderDate;
  Map<String, dynamic>? _originalMetadata;

  TodoItem({
    required this.id,
    required this.description,
    this.isEditing = false,
    this.isCompleted = false,
    String? priority,
    this.notes,
    this.position = 0,
    this.isEditingPriority = false,
    this.reminderDate, // Added for reminder feature
    Map<String, dynamic>? metadata, // Add metadata parameter
  }) : 
    priority = priority ?? 'medium',
    controller = TextEditingController(text: description),
    notesController = TextEditingController(text: notes ?? ''),
    metadata = metadata ?? {}; // Initialize metadata
    
  // Create from TaskModel
  factory TodoItem.fromTaskModel(TaskModel task) {
    return TodoItem(
      id: task.id,
      description: task.description,
      isCompleted: task.isCompleted,
      priority: task.priority,
      notes: task.notes,
      position: task.position,
      reminderDate: task.reminderDate, // Added for reminder feature
      metadata: task.metadata ?? {}, // Add metadata from TaskModel
    );
  }
  
  // Convert to TaskModel (without card_id, created_at, updated_at)
  Map<String, dynamic> toTaskData() {
    return {
      'id': id.startsWith('temp_') ? null : id, // Don't send temporary IDs
      'description': description,
      'is_completed': isCompleted,
      'priority': priority,
      'notes': notes,
      'position': position,
      'reminder_date': reminderDate?.toIso8601String(), // Added for reminder feature
      'metadata': metadata, // Add metadata to task data
    };
  }

  // Store current values as originals
  void storeOriginalValues() {
    _originalDescription = description;
    _originalNotes = notes;
    _originalPriority = priority;
    _originalReminderDate = reminderDate;
    _originalMetadata = Map<String, dynamic>.from(metadata); // Store original metadata
  }

  // Restore original values
  void restoreOriginalValues() {
    if (_originalDescription != null) {
      description = _originalDescription!;
      controller.text = _originalDescription!;
    }
    if (_originalNotes != null) {
      notes = _originalNotes;
      notesController.text = _originalNotes ?? '';
    }
    if (_originalPriority != null) {
      priority = _originalPriority!;
    }
    reminderDate = _originalReminderDate;
    if (_originalMetadata != null) {
      metadata = Map<String, dynamic>.from(_originalMetadata!); // Restore metadata
    }
  }
}

class ReviewTodoListPage extends StatefulWidget {
  final String ocrText;
  final Map<String, dynamic> initialResult;
  final Function(Map<String, dynamic>) onSaveCard;
  final bool isViewMode; // Add this parameter

  const ReviewTodoListPage({
    Key? key,
    required this.ocrText,
    required this.initialResult,
    required this.onSaveCard,
    this.isViewMode = false, // Default to false for backward compatibility
  }) : super(key: key);

  @override
  _ReviewTodoListPageState createState() => _ReviewTodoListPageState();
}

class _ReviewTodoListPageState extends State<ReviewTodoListPage> {
  final TodoService _todoService = TodoService();
  String _userId = '';  // Initialize with empty string
  TodoSettings? _settings;
  bool _isLoading = true;
  String _cardTitle = 'Generated Todo Card';
  List<TodoItem> _todoItems = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();
  final TextEditingController _todoController = TextEditingController();
  List<String> _selectedTags = ['Personal'];
  Color _selectedColor = Color(0xFF6C5CE7);
  
  // Add missing variables
  Color _prevSelectedColor = Color(0xFF6C5CE7);
  List<String> _prevSelectedTags = ['Personal'];
  String _prevTitle = '';
  bool _isEditMode = false;
  
  // Add isDarkMode getter
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  
  // Background widget with programmatically generated pattern
  Widget get backgroundWidget {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    return Container(
      color: themeProvider.isDarkMode ? Color(0xFF1E1E2E) : Colors.transparent,
      child: themeProvider.isDarkMode
          ? BackgroundPatterns.darkThemeBackground()
          : BackgroundPatterns.lightThemeBackground(),
    );
  }
  
  // Available card colors
  final List<Color> _cardColors = [
    Color(0xFF6C5CE7), // Purple (default)
    Color(0xFF00B894), // Green
    Color(0xFFFF7675), // Red
    Color(0xFFFD79A8), // Pink
    Color(0xFFFDAA5E), // Orange
    Color(0xFF0984E3), // Blue
    Color(0xFF636E72), // Gray
    Color(0xFF2D3436), // Dark
  ];
  
  // Priority colors and icons
  final Map<String, Color> _priorityColors = {
    'high': Colors.red.shade100,
    'medium': Colors.amber.shade100,
    'low': Colors.green.shade100,
  };
  
  final Map<String, IconData> _priorityIcons = {
    'high': Icons.priority_high,
    'medium': Icons.remove,
    'low': Icons.arrow_downward,
  };
  
  // Add missing variables
  final List<String> priorities = ['low', 'medium', 'high'];
  
  // Common tags
  final List<String> _commonTags = [
    'Personal',
    'Work',
    'Shopping',
    'Health',
    'Finance',
    'Travel',
    'Home',
    'Education',
  ];
  
  // Add missing variables for priority and reminder date
  String _selectedPriority = 'medium'; // Default priority
  DateTime? _reminderDate; // For card-level reminder
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Initialize ServiceFactory with user ID
      await ServiceFactory.initializeUser();
      await ServiceFactory.setCurrentUserId(currentUser.id);
      
      // Get user ID and verify it's not empty
      _userId = ServiceFactory.getCurrentUserId();
      if (_userId.isEmpty) {
        throw Exception('Invalid user ID');
      }
      
      // Initialize settings
      await _initializeSettings();

      // Process initial result if available
      if (widget.initialResult.isNotEmpty) {
        await _processInitialResult();
      } else {
        await _generateInitialList();
      }

    } catch (e) {
      developer.log('Error initializing data: $e', name: 'TodoList');
      
      // Only show error todo item if we don't have any items yet
      if (_todoItems.isEmpty) {
        setState(() {
          _todoItems = [
            TodoItem(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}_0',
              description: 'Error: Failed to initialize. Please try again.',
              priority: 'medium',
              position: 0,
              reminderDate: null,
              metadata: {},
            )
          ];
        });
      }
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show error message here if needed
    if (_todoItems.length == 1 && _todoItems[0].description.startsWith('Error:')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: User not found')),
        );
      });
    }
  }

  Future<void> _initializeSettings() async {
    try {
      // Get or create user settings
      TodoSettings? settings = await _todoService.getTodoSettings(_userId);
      if (settings == null) {
        settings = TodoSettings(
          userId: _userId,
          defaultPriority: 'medium',
          showCompletedTasks: true,
          sortBy: 'created',
          sortAscending: true,
        );
        await _todoService.saveTodoSettings(settings);
      }
      setState(() {
        _settings = settings;
      });
    } catch (e) {
      developer.log('Error initializing settings: $e', name: 'TodoList');
      // Create default settings in memory if database operation fails
      _settings = TodoSettings(
        userId: _userId,
        defaultPriority: 'medium',
        showCompletedTasks: true,
        sortBy: 'created',
        sortAscending: true,
      );
    }
  }

  Future<void> _loadTodoEntries(String cardId) async {
    try {
      final entries = await _todoService.getTodoEntries(_userId, cardId);
      setState(() {
        _todoItems = entries.map((entry) => TodoItem.fromTaskModel(entry)).toList();
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading todo entries: $e', name: 'TodoList');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processInitialResult() async {
    developer.log('Processing initial result: ${widget.initialResult}');
    
    // Set card title
    _cardTitle = widget.initialResult['title'] ?? 'Generated Todo Card';
    _titleController.text = _cardTitle;
    
    // Set card color
    if (widget.initialResult['color'] != null) {
      try {
        final colorValue = widget.initialResult['color'].toString();
        final colorInt = colorValue.startsWith('0x') 
            ? int.parse(colorValue) 
            : int.parse('0x$colorValue');
        _selectedColor = Color(colorInt);
        developer.log('Set color to: 0x${_selectedColor.value.toRadixString(16).padLeft(8, '0')}', name: 'TodoList');
      } catch (e) {
        developer.log('Error parsing color: $e', name: 'TodoList');
        // Use default color if parsing fails
        _selectedColor = Color(0xFF6C5CE7);
      }
    }
    
    // Set tags
    if (widget.initialResult['tags'] != null) {
      _selectedTags = List<String>.from(widget.initialResult['tags']);
    }
    
    // Load todo entries from database if card ID exists
    if (widget.initialResult['id'] != null) {
      final cardId = widget.initialResult['id'];
      final entries = await _todoService.getTodoEntries(_userId, cardId);
      
      if (entries.isNotEmpty) {
        if (mounted) {
          setState(() {
            _todoItems = entries.map((task) => TodoItem.fromTaskModel(task)).toList();
          });
        }
      } else {
        // Fall back to initial tasks if no entries found
        _processInitialTasks();
      }
    } else {
      // Process initial tasks for new card
      _processInitialTasks();
    }
  }

  void _processInitialTasks() {
    final tasks = widget.initialResult['tasks'] as List<dynamic>? ?? [];
    if (mounted) {
      setState(() {
        _todoItems = tasks.map((task) {
          return TodoItem(
            id: 'temp_${const Uuid().v4()}',
            description: task.toString(),
            position: _todoItems.length,
          );
        }).toList();
      });
    }
  }
  
  Future<void> _generateInitialList() async {
    developer.log('Generating initial todo list from OCR text', name: 'TodoList');
    developer.log('Input source: ${widget.ocrText.length > 50 ? widget.ocrText.substring(0, 50) + "..." : widget.ocrText}', name: 'TodoList');
    developer.log('CALLING OPENAI API NOW', name: 'TodoList');
    
    try {
      final todoItems = await ServiceFactory.generateTodoList(widget.ocrText);
      developer.log('Received ${todoItems.length} items from OpenAI service', name: 'TodoList');
      
      setState(() {
        _todoItems = [];
        for (int i = 0; i < todoItems.length; i++) {
          final item = todoItems[i];
          final description = item['task']?.toString() ?? 'Task';
          final priority = item['priority']?.toString()?.toLowerCase() ?? 'medium';
          
          _todoItems.add(TodoItem(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}_$i',
            description: description,
            priority: priority,
            position: i,
            reminderDate: item['reminder_date'] != null ? DateTime.parse(item['reminder_date']) : null,
            metadata: item['metadata'] ?? {}, // Add metadata from task
          ));
        }
        
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error generating initial list: $e', name: 'TodoList');
      setState(() {
        _isLoading = false;
        _todoItems = [
          TodoItem(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}_0',
            description: 'Failed to generate list. Please try again.',
            priority: 'medium',
            position: 0,
            reminderDate: null,
            metadata: {}, // Add empty metadata
          )
        ];
      });
    }
  }
  
  // Update the _regenerateList method similarly
  Future<void> _regenerateList(String option) async {
    developer.log('Regenerating todo list with option: $option', name: 'TodoList');
    setState(() {
      _isLoading = true;
    });
    
    // Create a prompt based on the option and original OCR text
    String prompt = widget.ocrText;
    
    // Modify the prompt based on the selected option
    if (option == 'detailed') {
      prompt = "Create a detailed task list with subtasks from this text: ${widget.ocrText}";
    } else if (option == 'simple') {
      prompt = "Create a simplified, concise task list from this text: ${widget.ocrText}";
    } else if (option == 'style') {
      prompt = "Reformat this task list with a different style: ${widget.ocrText}";
    } else if (option == 'full') {
      prompt = "Completely regenerate a task list from this text: ${widget.ocrText}";
    }
    
    developer.log('Using prompt: $prompt', name: 'TodoList');
    
    try {
      final todoItems = await ServiceFactory.generateTodoList(prompt);
      developer.log('Received ${todoItems.length} items from OpenAI service', name: 'TodoList');
      
      setState(() {
        _todoItems = [];
        for (int i = 0; i < todoItems.length; i++) {
          final item = todoItems[i];
          final description = item['task']?.toString() ?? 'Task';
          final priority = item['priority']?.toString()?.toLowerCase() ?? 'medium';
          
          _todoItems.add(TodoItem(
            id: 'temp_${DateTime.now().millisecondsSinceEpoch}_$i',
            description: description,
            priority: priority,
            position: i,
            reminderDate: item['reminder_date'] != null ? DateTime.parse(item['reminder_date']) : null,
            metadata: item['metadata'] ?? {}, // Add metadata from task
          ));
        }
        
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error regenerating list: $e', name: 'TodoList');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to regenerate list: $e'))
      );
    }
  }
  
  void _addNewItem() {
    setState(() {
      _todoItems.add(TodoItem(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}_${_todoItems.length}',
        description: 'New todo',
        isEditing: true,
        position: _todoItems.length,
        reminderDate: null,
        metadata: {}, // Add empty metadata
      ));
    });
  }
  
  void _deleteItem(String id) {
    setState(() {
      _todoItems.removeWhere((item) => item.id == id);
      
      // Update positions for remaining items
      for (int i = 0; i < _todoItems.length; i++) {
        _todoItems[i].position = i;
      }
    });
  }
  
  void _toggleEditingItem(String id) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        if (_todoItems[index].isEditing) {
          // Exiting edit mode - no need to save the current values
          _todoItems[index].isEditing = false;
        } else {
          // Entering edit mode - store current values
          _todoItems[index].isEditing = true;
          _todoItems[index].storeOriginalValues();
          _todoItems[index].controller.text = _todoItems[index].description;
          _todoItems[index].notesController.text = _todoItems[index].notes ?? '';
          
          // Position cursor at the end for description
          _todoItems[index].controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _todoItems[index].controller.text.length),
          );
          
          // Position cursor at the end for notes
          _todoItems[index].notesController.selection = TextSelection.fromPosition(
            TextPosition(offset: _todoItems[index].notesController.text.length),
          );
        }
      }
    });
  }
  
  void _cancelEditing(TodoItem item) {
    setState(() {
      // Restore all original values
      item.restoreOriginalValues();
      item.isEditing = false;
      
      // Reset the text controllers to match the original values
      item.controller.text = item.description;
      item.notesController.text = item.notes ?? '';
      
      // Find and collapse the ExpansionTile for this item
      item.isExpanded = false;
    });
  }
  
  void _updateItemDescription(String id, String newDescription) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _todoItems[index].description = newDescription;
      }
    });
  }
  
  void _toggleEditingPriority(String id) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _todoItems[index].isEditingPriority = !_todoItems[index].isEditingPriority;
      }
    });
  }
  
  void _updateItemPriority(String id, String newPriority) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _todoItems[index].priority = newPriority;
      }
    });
  }
  
  void _toggleItemCompletion(String id) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index >= 0) {
        _todoItems[index].isCompleted = !_todoItems[index].isCompleted;
      }
    });
  }
  
  void _updateItemNotes(String id, String? newNotes) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index != -1) {
        _todoItems[index].notes = newNotes;
      }
    });
  }
  
  // Update reminder date for a todo item
  void _updateItemReminderDate(String id, DateTime? newReminderDate) {
    setState(() {
      final index = _todoItems.indexWhere((item) => item.id == id);
      if (index != -1) {
        _todoItems[index].reminderDate = newReminderDate;
      }
    });
  }
  
  // Update all items to ensure latest controller values are used
  void _updateItemDescriptions() {
    for (var item in _todoItems) {
      if (item.isEditing) {
        item.description = item.controller.text.trim();
        item.notes = item.notesController.text.isEmpty ? null : item.notesController.text.trim();
      }
    }
  }
  
  Future<void> _saveTodoCard() async {
    try {
      setState(() {
        _isLoading = true;
      });

      _updateItemDescriptions();

      final _uuid = Uuid();
      final String cardId = widget.initialResult != null ? 
          widget.initialResult!['id'] : 
          _uuid.v4();

      // Create card data
      final cardData = {
        'id': cardId,
        'title': _titleController.text.trim(),
        'description': '',
        'task_count': _todoItems.length,
        'tags': _selectedTags,
        'color': '0x${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
        'metadata': widget.initialResult != null 
            ? (widget.initialResult!['metadata'] ?? {}) 
            : {},
      };

      // Convert todo items to TaskModels
      final tasks = _todoItems.map((item) => TaskModel(
        id: item.id.startsWith('temp_') ? _uuid.v4() : item.id,
        cardId: cardId,
        description: item.description,
        notes: item.notes,
        priority: item.priority,
        isCompleted: item.isCompleted,
        position: item.position,
        reminderDate: item.reminderDate,
        metadata: item.metadata,
      )).toList();

      // Save todo entries
      await _todoService.saveTodoEntriesBatch(_userId, cardId, tasks);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card saved successfully'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Call the onSaveCard callback
      if (widget.onSaveCard != null) {
        await widget.onSaveCard!(cardData);
      }

      await _scheduleNotificationsInBackground(cardData);

      await Future.delayed(Duration(milliseconds: 300));

      if (mounted) {
        if (widget.initialResult != null) {
          // Return the new color as part of the result when we pop
          Navigator.of(context).pop({
            ...widget.initialResult,
            'color': '0x${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
          });
        } else {
          Navigator.of(context).pop();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }
    } catch (e) {
      developer.log('Error saving todo card: $e', name: 'TodoList');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving card: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Schedule notifications in background
  Future<void> _scheduleNotificationsInBackground(Map<String, dynamic> cardData) async {
    try {
      final notificationService = NotificationService();
      
      // Initialize notification service first
      await notificationService.initialize();
      
      // Ensure we have permission
      final permissionGranted = await notificationService.requestPermission();
      if (!permissionGranted) {
        developer.log('Notification permission not granted, cannot schedule reminders', name: 'TodoList');
        return;
      }
      
      // Schedule reminder notification if reminder date is set
      if (_todoItems.any((item) => item.reminderDate != null)) {
        developer.log('Scheduling notifications for todo items with reminders', name: 'TodoList');
        
        for (var item in _todoItems) {
          if (item.reminderDate != null && !item.isCompleted) {
            // Cancel any existing notification for this task
            await notificationService.cancelNotification(item.id);
            
            // Only schedule if the reminder date is in the future
            if (item.reminderDate!.isAfter(DateTime.now())) {
              developer.log('Scheduling notification for todo ${item.id} at ${item.reminderDate}', name: 'TodoList');
              
              await notificationService.scheduleTaskReminder(
                taskId: item.id,
                title: 'Todo Reminder: ${_titleController.text.trim()}',
                body: item.description,
                scheduledDate: item.reminderDate!,
              );
              
              developer.log('Todo notification scheduled successfully for ${item.id}', name: 'TodoList');
            } else {
              developer.log('Skipping reminder for ${item.id} as date is in the past: ${item.reminderDate}', name: 'TodoList');
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error scheduling notifications: $e', name: 'TodoList');
    }
  }
  
  void _deleteCard() {
    // Check if we have a card to delete and a delete callback
    if (widget.initialResult != null && widget.initialResult!.containsKey('id')) {
      final cardId = widget.initialResult!['id'];
      
      // Show confirmation dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Card'),
          content: Text('Are you sure you want to delete this card? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                
                // Create card data with deletion flag
                final cardData = {
                  'id': cardId,
                  'deleted': true, // Add deletion flag
                };
                
                // Call the callback if provided
                if (widget.onSaveCard != null) {
                  widget.onSaveCard!(cardData);
                }
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Card deleted successfully')),
                );
                
                // Navigate back to the main page
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Delete'),
            ),
          ],
        ),
      );
    } else {
      // Show error message if no card ID is available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot delete card: No card ID found')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: isDarkMode ? Color(0xFF1E1E2E) : Colors.white,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: backgroundWidget),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: widget.isViewMode 
                ? Text(_titleController.text)
                : Text('Edit Todo Card'),
              actions: [
                if (widget.isViewMode)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewTodoListPage(
                            ocrText: widget.ocrText,
                            initialResult: widget.initialResult,
                            onSaveCard: widget.onSaveCard,
                            isViewMode: false,
                          ),
                        ),
                      );
                      
                      // Update color if returned from edit page
                      if (result != null && result is Map<String, dynamic> && result.containsKey('color')) {
                        setState(() {
                          final colorValue = result['color'].toString();
                          final colorInt = colorValue.startsWith('0x') 
                              ? int.parse(colorValue) 
                              : int.parse('0x$colorValue');
                          _selectedColor = Color(colorInt);
                        });
                      }
                    },
                  ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!widget.isViewMode) ...[
                            _buildCardHeader(),
                          ],
                          // Only show todo list in view mode
                          if (widget.isViewMode) 
                            _buildTodoList(),
                        ],
                      ),
                    ),
                  ),
            floatingActionButton: widget.isViewMode
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Add Todo'),
                              content: TextField(
                                controller: _todoController,
                                decoration: InputDecoration(
                                  hintText: 'Enter todo description',
                                  border: OutlineInputBorder(),
                                ),
                                autofocus: true,
                                onSubmitted: (value) async {
                                  if (value.isNotEmpty) {
                                    await _addTodoItem(value);
                                    _todoController.clear();
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (_todoController.text.isNotEmpty) {
                                      await _addTodoItem(_todoController.text);
                                      _todoController.clear();
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Text('Add'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Icon(Icons.add),
                        backgroundColor: _selectedColor,
                        elevation: 4,
                        hoverElevation: 8,
                        highlightElevation: 2,
                        shape: CircleBorder(),
                      ),
                    ),
                  )
                : null,
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          ),
        ],
      ),
    );
  }

  // Build card header widget
  Widget _buildCardHeader() {
    if (!widget.isViewMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title Container
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Card Title',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter card title',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          
          // Card Color Container
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: _buildColorPicker(),
          ),
          
          // Tags Container
          Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: _buildTagEditor(),
          ),
          
          // Action Buttons Container
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.initialResult.containsKey('id')) 
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _deleteCard,
                      icon: Icon(Icons.delete_outline),
                      label: Text('Delete Card'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (widget.initialResult.containsKey('id')) 
                  SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveTodoCard,
                    icon: Icon(Icons.save),
                    label: Text('Save Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // View mode header
      return Row(
        children: [
          Expanded(
            child: Text(
              _titleController.text,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _prevSelectedColor = _selectedColor;
                _prevSelectedTags = List<String>.from(_selectedTags);
                _prevTitle = _titleController.text;
                _isEditMode = true;
              });
            },
          ),
        ],
      );
    }
  }

  Widget _buildTodoList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar display
        Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade900.withOpacity(0.7) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDarkMode 
                  ? Colors.black.withOpacity(0.2) 
                  : Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.checklist_rounded,
                          color: _selectedColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_todoItems.where((item) => item.isCompleted).length}/${_todoItems.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(_todoItems.where((item) => item.isCompleted).length * 100 / _todoItems.length).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = _todoItems.isEmpty ? 0 : 
                        _todoItems.where((item) => item.isCompleted).length / _todoItems.length;
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: 12,
                        width: constraints.maxWidth * progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _selectedColor,
                              _selectedColor.withOpacity(0.8),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        // Todo list
        ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _todoItems.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final item = _todoItems.removeAt(oldIndex);
              _todoItems.insert(newIndex, item);
              
              // Update positions for all items
              for (int i = 0; i < _todoItems.length; i++) {
                _todoItems[i].position = i;
                _updateTodoItem(_todoItems[i]);
              }
            });
          },
          proxyDecorator: (child, index, animation) {
            return Material(
              elevation: 5,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.transparent,
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            );
          },
          itemBuilder: (context, index) {
            return KeyedSubtree(
              key: Key(_todoItems[index].id),
              child: ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: widget.isViewMode ? SystemMouseCursors.grab : SystemMouseCursors.basic,
                  child: Dismissible(
                    key: Key(_todoItems[index].id),
                    direction: widget.isViewMode ? DismissDirection.none : DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: widget.isViewMode ? null : (direction) {
                      _deleteTodoItem(_todoItems[index]);
                    },
                    child: Transform(
                      key: ValueKey('todo-transform-${_todoItems[index].id}-${_selectedColor.value}'),
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // perspective
                        ..rotateZ((index % 2 == 0 ? 0.2 : -0.2) * (3.14159 / 180.0)),
                      alignment: Alignment.center,
                      child: Container(
                        key: ValueKey('todo-container-${_todoItems[index].id}-${_selectedColor.value}'),
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: _selectedColor,
                              width: 4,
                            ),
                          ),
                        ),
                        child: ExpansionTile(
                          key: ValueKey('tile-${_todoItems[index].id}-${_todoItems[index].isExpanded}-${_selectedColor.value}'),
                          onExpansionChanged: (expanded) {
                            // Create a new list to force rebuild
                            final updatedItems = List<TodoItem>.from(_todoItems);
                            
                            updatedItems[index].isExpanded = expanded;
                            if (expanded) {
                              // Store original values when expanding
                              updatedItems[index].storeOriginalValues();
                              updatedItems[index].isEditing = true;
                            } else {
                              updatedItems[index].isEditing = false;
                            }
                            
                            setState(() {
                              _todoItems = updatedItems;
                            });
                          },
                          initiallyExpanded: _todoItems[index].isExpanded,
                          maintainState: false,
                          leading: Checkbox(
                            key: ValueKey('todo-checkbox-${_todoItems[index].id}-${_selectedColor.value}'),
                            value: _todoItems[index].isCompleted,
                            activeColor: _selectedColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (bool? value) {
                              setState(() {
                                _todoItems[index].isCompleted = value ?? false;
                              });
                              _updateTodoItem(_todoItems[index]);
                            },
                          ),
                          title: Text(
                            _todoItems[index].description,
                            style: TextStyle(
                              decoration: _todoItems[index].isCompleted ? TextDecoration.lineThrough : null,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _priorityIcons[_todoItems[index].priority] ?? Icons.priority_high,
                                  size: 16,
                                  color: _getPriorityColor(_todoItems[index].priority),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _todoItems[index].priority.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _getPriorityColor(_todoItems[index].priority),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.transparent,
                          collapsedBackgroundColor: Colors.transparent,
                          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          expandedAlignment: Alignment.topLeft,
                          childrenPadding: EdgeInsets.zero,
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Description field
                                  TextField(
                                    controller: _todoItems[index].controller,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      hintText: 'New todo',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Color(0xFF2196F3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Notes field
                                  Text(
                                    'Notes (Optional)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextField(
                                    controller: _todoItems[index].notesController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Add notes for this todo',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Color(0xFF2196F3),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  // Action buttons row
                                  Row(
                                    children: [
                                      // Priority button
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            int currentIndex = priorities.indexOf(_todoItems[index].priority);
                                            int nextIndex = (currentIndex + 1) % priorities.length;
                                            _todoItems[index].priority = priorities[nextIndex];
                                            _updateTodoItem(_todoItems[index]);
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _priorityIcons[_todoItems[index].priority] ?? Icons.priority_high,
                                                size: 18,
                                                color: _getPriorityColor(_todoItems[index].priority),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                _todoItems[index].priority.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Spacer(),
                                      // Reminder button
                                      IconButton(
                                        icon: Icon(
                                          Icons.alarm,
                                          color: _todoItems[index].reminderDate != null
                                              ? _selectedColor
                                              : (isDarkMode ? Colors.white54 : Colors.grey.shade600),
                                        ),
                                        onPressed: () => _showReminderPicker(_todoItems[index]),
                                      ),
                                      // Cancel button
                                      TextButton(
                                        onPressed: () {
                                          // First restore the original values
                                          _todoItems[index].restoreOriginalValues();
                                          // Then create a completely new list to force rebuild
                                          final updatedItems = List<TodoItem>.from(_todoItems);
                                          // Force the tile to be collapsed
                                          updatedItems[index].isExpanded = false;
                                          updatedItems[index].isEditing = false;
                                          
                                          // Update the state with the new list
                                          setState(() {
                                            _todoItems = updatedItems;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                                        ),
                                        child: Text('Cancel'),
                                      ),
                                      SizedBox(width: 8),
                                      // Done button
                                      ElevatedButton(
                                        onPressed: () {
                                          // Save the new values first
                                          _todoItems[index].description = _todoItems[index].controller.text;
                                          _todoItems[index].notes = _todoItems[index].notesController.text.isEmpty
                                              ? null
                                              : _todoItems[index].notesController.text;
                                          
                                          // Then create a completely new list to force rebuild
                                          final updatedItems = List<TodoItem>.from(_todoItems);
                                          // Force the tile to be collapsed
                                          updatedItems[index].isExpanded = false;
                                          updatedItems[index].isEditing = false;
                                          
                                          // Update the state with the new list
                                          setState(() {
                                            _todoItems = updatedItems;
                                          });
                                          
                                          // Save to database
                                          _updateTodoItem(_todoItems[index]);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _selectedColor,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text('Done'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Show regenerate options dialog
  void _showRegenerateOptionsDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Regenerate Options',
            style: TextStyle(
              color: isDarkMode ? Colors.white : null,
            ),
          ),
          backgroundColor: isDarkMode ? Colors.grey.shade900 : null,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRegenerateOptionItem('More Detailed', 'detailed', Colors.blue[700]!),
              _buildRegenerateOptionItem('Simpler Version', 'simple', Colors.green[700]!),
              _buildRegenerateOptionItem('Change Style', 'style', Colors.orange[700]!),
              _buildRegenerateOptionItem('Regenerate All', 'full', Colors.purple[700]!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white : null,
              ),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build regenerate option item
  Widget _buildRegenerateOptionItem(String label, String option, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(Icons.refresh, color: Colors.white, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDarkMode ? Colors.white : null,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _regenerateList(option);
      },
    );
  }

  // Show color picker dialog
  void _showColorPicker(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) {
        Color pickerColor = _selectedColor;
        
        return AlertDialog(
          title: Text(
            'Pick a Color',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          backgroundColor: isDarkMode ? Colors.grey.shade900 : null,
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              showLabel: true,
              paletteType: PaletteType.hsv,
              // Add extra parameters for dark mode
              labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv, ColorLabelType.hex],
              labelTextStyle: TextStyle(
                color: isDarkMode ? Colors.white : null,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Ensure the alpha channel is set to 0xFF (fully opaque)
                  _selectedColor = Color(0xFF000000 | (pickerColor.value & 0x00FFFFFF));
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Select'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build priority button
  Widget _buildPriorityButton(TodoItem item, String priority, IconData icon) {
    final bool isSelected = item.priority == priority;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _updateItemPriority(item.id, priority),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? _selectedColor.withOpacity(isDarkMode ? 0.3 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? _selectedColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? _selectedColor : (isDarkMode ? Colors.white.withOpacity(0.7) : Colors.grey.shade600),
          size: 18,
        ),
      ),
    );
  }

  // Show reminder date picker
  Future<void> _showReminderPicker(TodoItem item) async {
    try {
      final notificationService = NotificationService();
      
      // Initialize notification service first
      await notificationService.initialize();
      
      // Check permission before showing picker
      final permissionGranted = await notificationService.requestPermission();
      if (!permissionGranted) {
        if (mounted) {
          if (Platform.isMacOS) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please enable notifications for Snap2Done in System Settings > Notifications'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please enable notifications in system settings to set reminders'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () async {
                    await AppSettings.openAppSettings();
                  },
                ),
              ),
            );
          }
        }
        return;
      }
      
      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: item.reminderDate ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(Duration(days: 365)),
      );
      
      if (pickedDate != null) {
        final TimeOfDay? pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(
            item.reminderDate ?? DateTime.now(),
          ),
        );
        
        if (pickedTime != null) {
          final DateTime reminderDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          
          // Update the item's reminder date
          setState(() {
            _updateItemReminderDate(item.id, reminderDateTime);
          });
          
          // Schedule the notification immediately
          if (!item.isCompleted) {
            // Cancel any existing notification
            await notificationService.cancelNotification(item.id);
            
            // Schedule new notification
            await notificationService.scheduleTaskReminder(
              taskId: item.id,
              title: 'Todo Reminder: ${_titleController.text.trim()}',
              body: item.description,
              scheduledDate: reminderDateTime,
            );
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reminder set for ${reminderDateTime.toString()}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error setting reminder: $e', name: 'TodoList');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get color based on priority
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Calculate text color based on background color
  Color _getTextColorForBackground(Color backgroundColor) {
    // Calculate brightness (simple method)
    double brightness = (backgroundColor.red * 299 + 
                         backgroundColor.green * 587 + 
                         backgroundColor.blue * 114) / 1000;
    
    // Check if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // For very light colors, use a darker text color
    if (brightness > 200) {
      // Very light background - use dark text
      return Color(0xFF333333);
    } else if (brightness > 125) {
      // Medium-light background - use darker gray
      return Color(0xFF222222);
    } else {
      // Dark background - always use white text for better visibility
      return Colors.white;
    }
  }

  // Calculate secondary text color based on background color
  Color _getSecondaryTextColorForBackground(Color backgroundColor) {
    // Calculate brightness
    double brightness = (backgroundColor.red * 299 + 
                         backgroundColor.green * 587 + 
                         backgroundColor.blue * 114) / 1000;
    
    // Check if we're in dark mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // For light backgrounds, use a darker gray that's still distinguishable from primary text
    if (brightness > 200) {
      return isDarkMode ? Color(0xFF555555) : Color(0xFF555555);
    } else if (brightness > 125) {
      return isDarkMode ? Color(0xFFCCCCCC) : Color(0xFF444444);
    } else {
      // For dark backgrounds, use a slightly transparent white with higher opacity in dark mode
      return Colors.white.withOpacity(isDarkMode ? 0.95 : 0.8);
    }
  }

  // Add todo item method
  Future<void> _addTodoItem(String description) async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: User not initialized')),
      );
      return;
    }

    try {
      final String cardId = widget.initialResult['id'];
      final taskModel = TaskModel(
        id: const Uuid().v4(),
        cardId: cardId,
        description: description,
        notes: null,
        priority: 'medium',
        isCompleted: false,
        position: _todoItems.length,
        reminderDate: null,
        metadata: {},
      );

      // Save to database first
      await _todoService.saveTodoEntry(_userId, cardId, taskModel);

      // If save successful, update UI
      setState(() {
        _todoItems.add(TodoItem.fromTaskModel(taskModel));
      });
    } catch (e) {
      developer.log('Error adding todo item: $e', name: 'TodoList');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save todo item: $e')),
      );
    }
  }

  // Build color picker widget
  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._cardColors.map((color) {
              final isSelected = _selectedColor.value == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                    developer.log('Color changed to: 0x${color.value.toRadixString(16).padLeft(8, '0')}', name: 'TodoList');
                  });
                },
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                    ? Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
                ),
              );
            }).toList(),
            GestureDetector(
              onTap: () => _showColorPicker(context),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.grey.shade700,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build tag editor widget
  Widget _buildTagEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._selectedTags.map((tag) {
              return Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tag,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedTags.length > 1) {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            GestureDetector(
              onTap: () => _showTagSelectionDialog(context),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedColor,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        size: 16,
                        color: _selectedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: _selectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateTodoItem(TodoItem item) async {
    try {
      if (widget.initialResult['id'] == null) return;
      
      final taskModel = TaskModel(
        id: item.id,
        cardId: widget.initialResult['id'],
        description: item.description,
        notes: item.notes,
        priority: item.priority,
        isCompleted: item.isCompleted,
        position: item.position,
        reminderDate: item.reminderDate,
        metadata: item.metadata,
      );

      await _todoService.saveTodoEntry(_userId, widget.initialResult['id'], taskModel);
    } catch (e) {
      developer.log('Error updating todo item: $e', name: 'TodoList');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo item: $e')),
        );
      }
    }
  }

  Future<void> _deleteTodoItem(TodoItem item) async {
    try {
      if (widget.initialResult['id'] == null) return;

      await _todoService.deleteTodoEntry(item.id);
      
      setState(() {
        _todoItems.removeWhere((i) => i.id == item.id);
        // Update positions
        for (int i = 0; i < _todoItems.length; i++) {
          _todoItems[i].position = i;
        }
      });
    } catch (e) {
      developer.log('Error deleting todo item: $e', name: 'TodoList');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete todo item: $e')),
        );
      }
    }
  }

  void _showTagSelectionDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add Tags',
            style: TextStyle(
              color: isDarkMode ? Colors.white : null,
            ),
          ),
          backgroundColor: isDarkMode ? Colors.grey.shade900 : null,
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Common tags
                Text(
                  'Common Tags',
                  style: TextStyle(
                    fontSize: 14, 
                    color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            // Don't remove if it's the last tag
                            if (_selectedTags.length > 1) {
                              _selectedTags.remove(tag);
                            }
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Chip(
                        label: Text(
                          tag,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : null,
                          ),
                        ),
                        backgroundColor: isSelected 
                            ? Color(0xFF6C5CE7).withOpacity(isDarkMode ? 0.5 : 0.2)
                            : isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 16),
                
                // Custom tag input
                Text(
                  'Add Custom Tag',
                  style: TextStyle(
                    fontSize: 14, 
                    color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customTagController,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter custom tag',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.white,
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDarkMode ? Colors.purpleAccent : Colors.purple,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        cursorColor: isDarkMode ? Colors.purpleAccent : Colors.purple,
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            setState(() {
                              _selectedTags.add(value);
                              _customTagController.clear();
                            });
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_customTagController.text.isNotEmpty) {
                          setState(() {
                            _selectedTags.add(_customTagController.text);
                            _customTagController.clear();
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.white : null,
              ),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}