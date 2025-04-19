import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' show AudioEncoder;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/top_priorities_service.dart';
import '../../../services/attachment_service.dart';
import '../../../services/card_service.dart';
import '../models/top_priorities_model.dart';
import '../services/priorities_reminder_service.dart';
import '../models/top_priorities_entry_model.dart';
import '../../../services/card_service.dart';
import '../../../models/card_model.dart';
import '../../../models/task_model.dart';
import '../../../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/attachment_service.dart';
import 'package:path/path.dart' as path;
import '../../../pages/review_todo_list_page.dart';
import '../../../services/todo_service.dart';

class TopPrioritiesPage extends StatefulWidget {
  final String? cardId;
  final Map<String, dynamic>? metadata;
  final Future<String> Function(Map<String, dynamic>) onSave;
  final bool isEditing;

  const TopPrioritiesPage({
    Key? key,
    this.cardId,
    this.metadata,
    required this.onSave,
    required this.isEditing,
  }) : super(key: key);

  @override
  State<TopPrioritiesPage> createState() => _TopPrioritiesPageState();
}

class _TopPrioritiesPageState extends State<TopPrioritiesPage> {
  late DateTime _selectedDate;
  late TimeOfDay _reminderTime;
  late List<Map<String, dynamic>> _tasks;
  late List<Map<String, dynamic>> _attachments = [];
  final _uuid = Uuid();
  bool _isLoading = false;
  int? _draggedItemIndex;
  List<Map<String, dynamic>>? _initialTasks; // Store initial state

  // Add a map to store text controllers for each task
  final Map<String, TextEditingController> _textControllers = {};
  // Map to store individual reminder times for each task
  final Map<String, TimeOfDay?> _taskReminderTimes = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _isLoading = true;

    if (widget.isEditing && widget.metadata != null) {
      // Initialize from existing metadata
      // Use Future.microtask to schedule the async operation after the current frame
      Future.microtask(() async {
        await _initializeFromMetadata();
        // Add listener to sync controller values with tasks
        _addTextControllerListeners();
      });
    } else {
      // Initialize with defaults for new card
      _tasks = TopPrioritiesModel.getDefaultTasks();
      _initialTasks = List<Map<String, dynamic>>.from(_tasks.map((task) => Map<String, dynamic>.from(task)));
      _initializeTextControllers();
      // Add listener to sync controller values with tasks
      _addTextControllerListeners();
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Dispose all text controllers
    for (var controller in _textControllers.values) {
      controller.removeListener(() {}); // Remove any existing listeners
      controller.dispose();
    }
    super.dispose();
  }

  // Initialize text controllers for each task
  void _initializeTextControllers() {
    // First dispose all existing controllers to avoid memory leaks
    for (var controller in _textControllers.values) {
      controller.removeListener(() {}); // Remove any existing listeners
      controller.dispose();
    }
    _textControllers.clear();

    // Then create new controllers for each task
    for (var task in _tasks) {
      final id = task['id'] as String;
      _textControllers[id] = TextEditingController(text: task['description'] as String? ?? '');
    }
  }

  // Add text controller listeners to update task descriptions as the user types
  void _addTextControllerListeners() {
    for (var task in _tasks) {
      final id = task['id'] as String;
      if (_textControllers.containsKey(id)) {
        _textControllers[id]!.addListener(() {
          final controller = _textControllers[id]!;
          // Only update if the task exists and the values differ
          final taskIndex = _tasks.indexWhere((t) => t['id'] == id);
          if (taskIndex != -1 && _tasks[taskIndex]['description'] != controller.text) {
            _tasks[taskIndex]['description'] = controller.text;
            // Update placeholder status
            if (_tasks[taskIndex]['metadata'] != null) {
              _tasks[taskIndex]['metadata']['placeholder'] = controller.text.isEmpty;
            }
          }
        });
      }
    }
  }

  Future<void> _initializeFromMetadata() async {
    print('[TopPrioritiesPage] Initializing from metadata');
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to load tasks from the database
      print('[TopPrioritiesPage] Trying to load tasks from database for date: $_selectedDate');
      final savedTasks = await TopPrioritiesService.getEntriesForDate(_selectedDate);
      print('[TopPrioritiesPage] Found ${savedTasks.length} tasks in database');

      if (savedTasks.isNotEmpty) {
        // If we have tasks in the database, use them
        _tasks = savedTasks;
        print('[TopPrioritiesPage] Using tasks from database');
      } else {
        // If no tasks in database, try to get them from card metadata
        print('[TopPrioritiesPage] No tasks in database, trying card metadata');
        final card = CardService.getCard(widget.cardId!);
        print('[TopPrioritiesPage] Card: ${card?.id}, metadata: ${card?.metadata}');

        if (card?.metadata == null) {
          print('[TopPrioritiesPage] No metadata found for card');
          // Initialize with defaults if no metadata
          _tasks = TopPrioritiesModel.getDefaultTasks();
        } else {
          final metadata = card!.metadata!;
          print('[TopPrioritiesPage] Processing metadata: $metadata');

          try {
            // Check if we have the new format with 'priorities' field
            if (metadata['priorities'] != null) {
              final priorities = metadata['priorities'] as Map<String, dynamic>;

              // Get today's date in the format used as key (YYYY-MM-DD)
              final today = TopPrioritiesModel.dateToKey(_selectedDate);

              // If there are entries for today, use them
              if (priorities.containsKey(today)) {
                final todayData = priorities[today] as Map<String, dynamic>;

                if (todayData['tasks'] != null) {
                  try {
                    // Fix: Properly handle List<dynamic> to List<Map<String, dynamic>> conversion
                    final tasksList = todayData['tasks'] as List;
                    _tasks = tasksList.map((item) =>
                      // Convert each dynamic item to a proper Map<String, dynamic>
                      Map<String, dynamic>.from(item as Map<dynamic, dynamic>)
                    ).toList();
                    print('[TopPrioritiesPage] Using tasks from metadata');
                  } catch (e) {
                    print('[TopPrioritiesPage] Error parsing tasks: $e');
                    // Fall back to defaults on error
                    _tasks = TopPrioritiesModel.getDefaultTasks();
                  }
                } else {
                  _tasks = TopPrioritiesModel.getDefaultTasks();
                }
              } else {
                // No data for today, use defaults
                _tasks = TopPrioritiesModel.getDefaultTasks();
              }
            }
            // Fallback for old format
            else if (metadata['tasks'] != null) {
              try {
                // Fix: Properly handle List<dynamic> to List<Map<String, dynamic>> conversion
                final tasksList = metadata['tasks'] as List;
                _tasks = tasksList.map((item) =>
                  // Convert each dynamic item to a proper Map<String, dynamic>
                  Map<String, dynamic>.from(item as Map<dynamic, dynamic>)
                ).toList();
              } catch (e) {
                print('[TopPrioritiesPage] Error parsing tasks from metadata: $e');
                // Fall back to defaults on error
                _tasks = TopPrioritiesModel.getDefaultTasks();
              }
            }
            // If no tasks found at all, use defaults
            else {
              _tasks = TopPrioritiesModel.getDefaultTasks();
            }
          } catch (e) {
            print('[TopPrioritiesPage] Error processing metadata: $e');
            // Fall back to defaults if metadata is malformed
            _tasks = TopPrioritiesModel.getDefaultTasks();
          }

          // Initialize attachments if any
          if (metadata['attachments'] != null) {
            try {
              // Fix: Properly handle List<dynamic> to List<Map<String, dynamic>> conversion
              final attachmentsList = metadata['attachments'] as List;
              _attachments = attachmentsList.map((item) =>
                // Convert each dynamic item to a proper Map<String, dynamic>
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>)
              ).toList();
            } catch (e) {
              print('[TopPrioritiesPage] Error parsing attachments: $e');
              // Keep attachments empty on error
              _attachments = [];
            }
          }
        }
      }

      // Ensure the notes field is properly formatted
      _migrateNotesToList();

      // Store initial state for change detection
      _initialTasks = List<Map<String, dynamic>>.from(_tasks.map((task) => Map<String, dynamic>.from(task)));

      // Initialize text controllers
      _initializeTextControllers();

      print('[TopPrioritiesPage] Initialization complete');
      print('[TopPrioritiesPage] Date: $_selectedDate');
      print('[TopPrioritiesPage] Tasks count: ${_tasks.length}');
      print('[TopPrioritiesPage] Attachments count: ${_attachments.length}');
    } catch (e) {
      print('[TopPrioritiesPage] Fatal error in initialization: $e');
      // Set up defaults if there's a fatal error
      _tasks = TopPrioritiesModel.getDefaultTasks();
      _initialTasks = List<Map<String, dynamic>>.from(_tasks.map((task) => Map<String, dynamic>.from(task)));
      _initializeTextControllers();
      _attachments = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _migrateNotesToList() {
    for (var task in _tasks) {
      try {
        if (task['notes'] == null) {
          task['notes'] = <String>[];
        } else if (task['notes'] is String) {
          final oldNote = task['notes'] as String;
          task['notes'] = oldNote.isNotEmpty ? <String>[oldNote] : <String>[];
        } else if (task['notes'] is List) {
          // Handle List<dynamic> by converting each item to String
          List<dynamic> dynamicList = task['notes'] as List<dynamic>;
          task['notes'] = dynamicList.map((item) => item?.toString() ?? '').toList();
        } else {
          // Fallback for any other type
          task['notes'] = <String>[];
          print('[TopPrioritiesPage] Unexpected notes type: ${task['notes'].runtimeType}, resetting to empty list');
        }
      } catch (e) {
        print('[TopPrioritiesPage] Error migrating notes: $e');
        task['notes'] = <String>[];
      }

      // Ensure documents field exists
      try {
        if (task['documents'] == null) {
          task['documents'] = <Map<String, dynamic>>[];
        } else if (task['documents'] is List) {
          // Handle List<dynamic> for documents
          List<dynamic> dynamicList = task['documents'] as List<dynamic>;

          // Convert each item in the list to Map<String, dynamic>
          List<Map<String, dynamic>> convertedList = [];
          for (var item in dynamicList) {
            if (item is Map) {
              // Convert Map<dynamic, dynamic> to Map<String, dynamic>
              convertedList.add(Map<String, dynamic>.from(item));
            }
          }
          task['documents'] = convertedList;
        } else {
          task['documents'] = <Map<String, dynamic>>[];
          print('[TopPrioritiesPage] Invalid documents field type: ${task['documents'].runtimeType}, resetting to empty list');
        }
      } catch (e) {
        print('[TopPrioritiesPage] Error migrating documents: $e');
        task['documents'] = <Map<String, dynamic>>[];
      }

      // Ensure metadata field exists
      if (task['metadata'] == null) {
        task['metadata'] = {
          'type': 'top_priority',
          'order': task['position'] != null ? (task['position'] as int) + 1 : 1,
        };
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: themeProvider.isDarkMode
                ? BackgroundPatterns.darkThemeBackground()
                : BackgroundPatterns.lightThemeBackground(),
          ),

          // Main content
          StreamBuilder<List<CardModel>>(
            stream: CardService.cardStream,
            builder: (context, snapshot) {
              print('[TopPrioritiesPage] StreamBuilder update:');
              print('[TopPrioritiesPage] Has data: ${snapshot.hasData}');
              print('[TopPrioritiesPage] Has error: ${snapshot.hasError}');
              if (snapshot.hasData) {
                print('[TopPrioritiesPage] Data length: ${snapshot.data?.length}');
                print('[TopPrioritiesPage] Cards: ${snapshot.data?.map((c) => '${c.id}: ${c.metadata?['type']}')}');
              }

              if (snapshot.hasError) {
                debugPrint('[TopPrioritiesPage] Error in card stream: ${snapshot.error}');
                return Center(child: Text('Error loading cards'));
              }

              // If we have data and this card exists in the stream, update our local state
              if (snapshot.hasData && widget.cardId != null) {
                print('[TopPrioritiesPage] Looking for card: ${widget.cardId}');
                final card = snapshot.data!.firstWhere(
                  (card) => card.id == widget.cardId,
                  orElse: () => CardModel.fromMap({}),
                );

                print('[TopPrioritiesPage] Found card: ${card.id}, metadata: ${card.metadata}');

                // Only update if we're not already loading data and this is not a checkbox update
                if (card.id != null && card.metadata != null && !_isLoading) {
                  // Update local state with new card data
                  print('[TopPrioritiesPage] Scheduling state update with new card data');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      print('[TopPrioritiesPage] Updating state with new card data');
                      setState(() {
                        _initializeFromMetadata();
                      });
                    }
                  });
                }
              }

              return Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  title: Text(widget.isEditing ? 'Daily Top Priorities' : 'Create Daily Top Priorities'),
                  backgroundColor: themeProvider.isDarkMode ? Colors.grey[900]?.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                  foregroundColor: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () async {
                      final canPop = await _onBackPressed();
                      if (canPop && mounted) {
                        // Use Navigator.pushReplacementNamed to avoid black screen
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                  ),
                  actions: [
                    if (widget.isEditing)
                      IconButton(
                        icon: Icon(Icons.settings),
                        onPressed: _openEditTodoCardPage,
                      ),
                  ],
                ),
                extendBody: !widget.isEditing,
                body: Column(
                  children: [
                    Expanded(
                      child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              top: 16.0,
                              bottom: widget.isEditing ? 16.0 : 80.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date navigation
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  color: themeProvider.isDarkMode ? Colors.grey[900]?.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.chevron_left),
                                          onPressed: () {
                                            _selectDate(_selectedDate.subtract(Duration(days: 1)));
                                          },
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _showDatePicker(),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  TopPrioritiesModel.formatDate(_selectedDate, context),
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                if (_isSpecialDate(_selectedDate)) ...[
                                                  SizedBox(height: 4),
                                                  Text(
                                                    DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(_selectedDate),
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.chevron_right),
                                          onPressed: () {
                                            _selectDate(_selectedDate.add(Duration(days: 1)));
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Progress gauge - only show in editing mode
                                if (widget.isEditing && !_isLoading) ...[
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    color: themeProvider.isDarkMode ? Colors.grey[900]?.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Progress',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${_tasks.where((task) => task['isCompleted'] == true).length}/${_tasks.length}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          LinearProgressIndicator(
                                            value: _tasks.isEmpty ? 0.0 : _tasks.where((task) => task['isCompleted'] == true).length / _tasks.length,
                                            backgroundColor: Colors.grey.withOpacity(0.3),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).primaryColor,
                                            ),
                                            minHeight: 10,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          SizedBox(height: 8),
                                          Builder(
                                            builder: (context) {
                                              final completedCount = _tasks.where((task) => task['isCompleted'] == true).length;
                                              final totalCount = _tasks.length;
                                              String message;
                                              
                                              if (completedCount == 0) {
                                                message = 'No tasks completed yet. You can do it!';
                                              } else if (completedCount == totalCount) {
                                                message = 'All tasks completed! Great job!';
                                              } else {
                                                final remainingCount = totalCount - completedCount;
                                                final percentage = (completedCount / totalCount * 100).round();
                                                
                                                if (percentage < 25) {
                                                  message = 'Just getting started! $remainingCount more to go.';
                                                } else if (percentage < 50) {
                                                  message = 'Good progress! $remainingCount more remaining.';
                                                } else if (percentage < 75) {
                                                  message = 'More than halfway there! Keep going!';
                                                } else {
                                                  message = 'Almost done! Just $remainingCount more to complete.';
                                                }
                                              }
                                              
                                              return Text(
                                                message,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                ],

                                // Tasks list
                                ReorderableListView.builder(
                                  buildDefaultDragHandles: false,
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _tasks.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setState(() {
                                      if (oldIndex < newIndex) {
                                        newIndex -= 1;
                                      }
                                      final item = _tasks.removeAt(oldIndex);
                                      _tasks.insert(newIndex, item);

                                      // Update positions after reorder
                                      for (var i = 0; i < _tasks.length; i++) {
                                        _tasks[i]['position'] = i;
                                        _tasks[i]['metadata'] = {
                                          ..._tasks[i]['metadata'] ?? {},
                                          'type': 'top_priority',
                                          'order': i + 1,
                                        };
                                      }
                                    });
                                  },
                                  proxyDecorator: (child, index, animation) {
                                    return Material(
                                      elevation: 5,
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: child,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    final task = _tasks[index];
                                    return KeyedSubtree(
                                      key: Key(task['id']),
                                      child: ReorderableDragStartListener(
                                        index: index,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.grab,
                                          child: Card(
                                            key: ValueKey(task['id']),
                                            margin: EdgeInsets.only(bottom: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            color: themeProvider.isDarkMode ? Colors.grey[900]?.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                                            child: Theme(
                                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                              child: ExpansionTile(
                                                key: ValueKey('tile-${task['id']}-${task['isExpanded'] ?? false}'),
                                                onExpansionChanged: (expanded) {
                                                  setState(() {
                                                    if (expanded) {
                                                      // Store original state when expanding
                                                      task['_originalState'] = {
                                                        'description': task['description'],
                                                        'notes': task['notes'],
                                                        'metadata': Map<String, dynamic>.from(task['metadata'] ?? {}),
                                                      };
                                                    }
                                                    task['isExpanded'] = expanded;
                                                  });
                                                },
                                                initiallyExpanded: task['isExpanded'] ?? false,
                                                maintainState: false,
                                                leading: widget.isEditing ? Checkbox(
                                                  value: task['isCompleted'] ?? false,
                                                  activeColor: Theme.of(context).primaryColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  onChanged: (value) async {
                                                    // Update UI immediately without showing loading indicator
                                                    setState(() {
                                                      task['isCompleted'] = value;
                                                    });

                                                    // Save in background without blocking UI
                                                    _saveTaskCompletionInBackground(task, value);
                                                  },
                                                ) : Container(
                                                  width: 24,
                                                  height: 24,
                                                  margin: EdgeInsets.symmetric(horizontal: 8),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                                                    border: Border.all(
                                                      color: Theme.of(context).primaryColor,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Theme.of(context).primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  task['metadata']?['placeholder'] == true
                                                    ? 'Priority #${task['metadata']?['order']}'
                                                    : (task['description'] ?? ''),
                                                  style: TextStyle(
                                                    decoration: task['isCompleted'] == true ? TextDecoration.lineThrough : null,
                                                    fontSize: 16,
                                                    fontStyle: task['metadata']?['placeholder'] == true ? FontStyle.italic : FontStyle.normal,
                                                    color: task['metadata']?['placeholder'] == true ? Colors.grey : null,
                                                  ),
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (task['reminderTime'] != null)
                                                      Padding(
                                                        padding: EdgeInsets.only(right: 8),
                                                        child: Icon(
                                                          Icons.alarm_on,
                                                          size: 20,
                                                          color: Theme.of(context).primaryColor,
                                                        ),
                                                      ),
                                                    IconButton(
                                                      icon: Icon(Icons.delete_outline, size: 20),
                                                      color: Colors.red.withOpacity(0.7),
                                                      onPressed: () async {
                                                        setState(() {
                                                          _isLoading = true; // Show loading indicator
                                                        });

                                                        try {
                                                          // Remove the task from the UI
                                                          final deletedTask = _tasks.removeAt(index);

                                                          // Update order for remaining tasks
                                                          for (var i = 0; i < _tasks.length; i++) {
                                                            _tasks[i]['position'] = i;
                                                            _tasks[i]['metadata'] = {
                                                              ..._tasks[i]['metadata'] ?? {},
                                                              'type': 'top_priority',
                                                              'order': i + 1,
                                                            };
                                                          }

                                                          // Save changes to database
                                                          await _saveTasksAfterDelete(deletedTask);

                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text('Task deleted successfully'),
                                                                backgroundColor: Colors.green,
                                                              ),
                                                            );
                                                          }
                                                        } catch (e) {
                                                          print('Error deleting task: $e');
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text('Error deleting task: $e'),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                          }
                                                        } finally {
                                                          if (mounted) {
                                                            setState(() {
                                                              _isLoading = false; // Hide loading indicator
                                                            });
                                                          }
                                                        }
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints: BoxConstraints(
                                                        minWidth: 36,
                                                        minHeight: 36,
                                                      ),
                                                      splashRadius: 20,
                                                    ),
                                                    Icon(Icons.drag_handle, color: Colors.grey),
                                                  ],
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
                                                          controller: _textControllers[task['id']],
                                                          maxLength: TopPrioritiesModel.maxDescriptionLength,
                                                          onTap: task['metadata']?['placeholder'] == true ? () {
                                                            // Clear the text only on first tap for placeholder items
                                                            _textControllers[task['id']]?.clear();
                                                            setState(() {
                                                              task['description'] = '';
                                                              task['metadata']?['placeholder'] = false;
                                                            });
                                                          } : null,
                                                          decoration: InputDecoration(
                                                            labelText: 'Description',
                                                            hintText: task['metadata']?['placeholder'] == true ? 'Priority #${task['metadata']?['order']}' : null,
                                                            hintStyle: const TextStyle(
                                                              fontStyle: FontStyle.italic,
                                                              color: Colors.grey,
                                                            ),
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            focusedBorder: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                              borderSide: BorderSide(
                                                                color: Theme.of(context).primaryColor,
                                                                width: 2,
                                                              ),
                                                            ),
                                                            counterText: '',
                                                          ),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              task['description'] = value;
                                                              // Remove placeholder flag when user starts typing
                                                              if (value.isNotEmpty && task['metadata']?['placeholder'] == true) {
                                                                task['metadata']?['placeholder'] = false;
                                                              }
                                                              // Restore placeholder if field is emptied
                                                              if (value.isEmpty) {
                                                                task['metadata']?['placeholder'] = true;
                                                              }
                                                            });
                                                          },
                                                        ),
                                                        SizedBox(height: 16),
                                                        // Notes section
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            if ((task['notes'] as List<String>?)?.isNotEmpty ?? false) ...[
                                                              Text(
                                                                'Notes',
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                              SizedBox(height: 8),
                                                              ...List.generate(
                                                                (task['notes'] as List<String>?)?.length ?? 0,
                                                                (index) => Padding(
                                                                  padding: EdgeInsets.only(bottom: 8),
                                                                  child: Stack(
                                                                    children: [
                                                                      TextFormField(
                                                                        initialValue: (task['notes'] as List<String>?)?[index] ?? '',
                                                                        decoration: InputDecoration(
                                                                          hintText: 'Enter note',
                                                                          border: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(8),
                                                                          ),
                                                                          focusedBorder: OutlineInputBorder(
                                                                            borderRadius: BorderRadius.circular(8),
                                                                            borderSide: BorderSide(
                                                                              color: Theme.of(context).primaryColor,
                                                                              width: 2,
                                                                            ),
                                                                          ),
                                                                          counterText: '',
                                                                        ),
                                                                        maxLength: TopPrioritiesModel.maxNoteLength,
                                                                        maxLines: null,
                                                                        onChanged: (value) {
                                                                          setState(() {
                                                                            (task['notes'] as List<String>?)?[index] = value;
                                                                          });
                                                                        },
                                                                      ),
                                                                      Positioned(
                                                                        right: 0,
                                                                        top: 0,
                                                                        child: IconButton(
                                                                          icon: Icon(Icons.close, size: 20),
                                                                          onPressed: () {
                                                                            setState(() {
                                                                              (task['notes'] as List<String>?)?.removeAt(index);
                                                                            });
                                                                          },
                                                                          padding: EdgeInsets.zero,
                                                                          constraints: BoxConstraints(
                                                                            minWidth: 36,
                                                                            minHeight: 36,
                                                                          ),
                                                                          splashRadius: 20,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                            SizedBox(height: 8),
                                                            TextButton.icon(
                                                              onPressed: () {
                                                                setState(() {
                                                                  if (task['notes'] == null) {
                                                                    task['notes'] = <String>[];
                                                                  }
                                                                  (task['notes'] as List<String>).add('');
                                                                });
                                                              },
                                                              icon: Icon(Icons.add),
                                                              label: Text('Add Note'),
                                                              style: TextButton.styleFrom(
                                                                foregroundColor: Theme.of(context).primaryColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 16),
                                                        // Documents section
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            if (task['documents'] != null && (task['documents'] as List).isNotEmpty) ...[
                                                              Text(
                                                                'Documents',
                                                                style: TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                              SizedBox(height: 8),
                                                              Wrap(
                                                                spacing: 8,
                                                                runSpacing: 8,
                                                                children: [
                                                                  ...(task['documents'] as List).map((docItem) {
                                                                    // Safely convert to Map<String, dynamic>
                                                                    final doc = docItem is Map ?
                                                                      Map<String, dynamic>.from(docItem as Map) :
                                                                      <String, dynamic>{};

                                                                    return Container(
                                                                      width: 100,
                                                                      child: Column(
                                                                        children: [
                                                                          Stack(
                                                                            children: [
                                                                              Container(
                                                                                width: 80,
                                                                                height: 80,
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.grey.withOpacity(0.1),
                                                                                  borderRadius: BorderRadius.circular(8),
                                                                                ),
                                                                                child: InkWell(
                                                                                  onTap: () => _openDocument(doc),
                                                                                  child: Image.asset(
                                                                                    TopPrioritiesModel.getDocumentTypeIcon(doc['mimeType']?.toString() ?? ''),
                                                                                    width: 40,
                                                                                    height: 40,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Positioned(
                                                                                right: 0,
                                                                                top: 0,
                                                                                child: IconButton(
                                                                                  icon: Icon(Icons.close, size: 16, color: Colors.red),
                                                                                  onPressed: () async {
                                                                                    try {
                                                                                      // Delete from storage first
                                                                                      if (doc['wasabi_path'] != null) {
                                                                                        await StorageService.deleteFile(doc['url']);
                                                                                      }
                                                                                      // Then remove from UI
                                                                                      setState(() {
                                                                                        (task['documents'] as List).remove(docItem);
                                                                                      });
                                                                                    } catch (e) {
                                                                                      print('Error deleting document: $e');
                                                                                      if (!mounted) return;
                                                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                                                        SnackBar(content: Text('Error deleting document: $e')),
                                                                                      );
                                                                                    }
                                                                                  },
                                                                                  padding: EdgeInsets.zero,
                                                                                  constraints: BoxConstraints(
                                                                                    minWidth: 24,
                                                                                    minHeight: 24,
                                                                                  ),
                                                                                  splashRadius: 16,
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          SizedBox(height: 4),
                                                                          Text(
                                                                            doc['name']?.toString() ?? 'Document',
                                                                            maxLines: 2,
                                                                            overflow: TextOverflow.ellipsis,
                                                                            textAlign: TextAlign.center,
                                                                            style: TextStyle(
                                                                              fontSize: 12,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    );
                                                                  }).toList(),
                                                                ],
                                                              ),
                                                            ],
                                                            SizedBox(height: 8),
                                                            Row(
                                                              children: [
                                                                TextButton.icon(
                                                                  onPressed: () => _addDocument(task),
                                                                  icon: Image.asset(
                                                                    'assets/images/document_icon.png',
                                                                    width: 24,
                                                                    height: 24,
                                                                    color: Theme.of(context).primaryColor,
                                                                  ),
                                                                  label: Text('Add Document'),
                                                                  style: TextButton.styleFrom(
                                                                    foregroundColor: Theme.of(context).primaryColor,
                                                                  ),
                                                                ),
                                                                SizedBox(width: 16),
                                                                TextButton.icon(
                                                                  onPressed: () => _addVoiceNote(task),
                                                                  icon: Image.asset(
                                                                    'assets/images/microphone.png',
                                                                    width: 24,
                                                                    height: 24,
                                                                    color: Theme.of(context).primaryColor,
                                                                  ),
                                                                  label: Text('Add Voice Note'),
                                                                  style: TextButton.styleFrom(
                                                                    foregroundColor: Theme.of(context).primaryColor,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 16),
                                                        // Action buttons row
                                                        Row(
                                                          children: [
                                                            IconButton(
                                                              icon: Icon(
                                                                task['reminderTime'] != null ? Icons.alarm_on : Icons.alarm_add,
                                                                color: task['reminderTime'] != null
                                                                    ? Theme.of(context).primaryColor
                                                                    : Colors.grey,
                                                              ),
                                                              onPressed: () => _selectTaskReminderTime(context, task['id']),
                                                            ),
                                                            Spacer(),
                                                            TextButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  // Restore original state
                                                                  if (task['_originalState'] != null) {
                                                                    task['description'] = task['_originalState']['description'];
                                                                    task['notes'] = task['_originalState']['notes'];
                                                                    task['metadata'] = Map<String, dynamic>.from(task['_originalState']['metadata']);
                                                                    task['_originalState'] = null;
                                                                  }
                                                                  task['isExpanded'] = false;
                                                                });
                                                              },
                                                              style: TextButton.styleFrom(
                                                                foregroundColor: Theme.of(context).brightness == Brightness.dark
                                                                    ? Colors.white70
                                                                    : Colors.grey.shade700,
                                                              ),
                                                              child: Text('Cancel'),
                                                            ),
                                                            SizedBox(width: 8),
                                                            ElevatedButton(
                                                              onPressed: () {
                                                                setState(() {
                                                                  task['isExpanded'] = false;
                                                                  // Only save if we're in edit mode (card exists)
                                                                  if (widget.isEditing) {
                                                                    _saveChanges();
                                                                  }
                                                                });
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Theme.of(context).primaryColor,
                                                                foregroundColor: Colors.white,
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
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                    ),
                    // Bottom button for editing mode
                    if (widget.isEditing)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(context).primaryColor,
                            ),
                            onPressed: _isLoading ? null : _saveChanges,
                            child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Save Changes',
                                  style: TextStyle(fontSize: 16),
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
                bottomNavigationBar: !widget.isEditing ? BottomAppBar(
                  shape: CircularNotchedRectangle(),
                  notchMargin: 8,
                  color: themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
                  elevation: themeProvider.isDarkMode ? 0 : 8,
                  height: 60,
                  child: Container(
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Image.asset(
                                  'assets/images/cancel.png',
                                  width: 24,
                                  height: 24,
                                  color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                tooltip: 'Cancel',
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 80),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Image.asset(
                                  'assets/images/card.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.green,
                                ),
                                onPressed: _isLoading ? null : _createCard,
                                tooltip: 'Create Card',
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ) : null,
                floatingActionButton: !widget.isEditing ? Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        final newTaskIndex = _tasks.length;
                        _tasks.add(TopPrioritiesModel.createDefaultTask(newTaskIndex));
                        _initializeTextControllers();
                      });
                    },
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Image.asset(
                      'assets/images/magic.png',
                      color: Colors.white,
                      width: 42,
                      height: 42,
                    ),
                    elevation: 4.0,
                    tooltip: 'Add New Priority',
                    shape: CircleBorder(),
                  ),
                ) : null,
                floatingActionButtonLocation: !widget.isEditing ? FloatingActionButtonLocation.centerDocked : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // Update the date selection methods
  Future<void> _showDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      _selectDate(picked);
    }
  }

  Future<void> _selectDate(DateTime date) async {
    // First update the date immediately to make UI responsive
    setState(() {
      _selectedDate = date;
      _isLoading = true;
    });

    // Then load the tasks in the background
    try {
      // Load tasks from the service for the selected date
      print('[TopPrioritiesPage] Loading tasks from database for date: $date');
      final savedTasks = await TopPrioritiesService.getEntriesForDate(date);
      print('[TopPrioritiesPage] Found ${savedTasks.length} tasks in database for date: $date');

      if (!mounted) return;

      setState(() {
        if (savedTasks.isNotEmpty) {
          // If we have tasks in the database, use them
          _tasks = savedTasks;
          print('[TopPrioritiesPage] Using tasks from database');
          _migrateNotesToList();
        } else if (widget.isEditing) {
          // If no tasks in database, try to get them from card metadata
          print('[TopPrioritiesPage] No tasks in database, trying card metadata');
          // Get today's date in the format used as key (YYYY-MM-DD)
          final dateKey = TopPrioritiesModel.dateToKey(date);
          Map<String, dynamic>? metadata;

          // Try to get fresh metadata from card if available
          if (widget.cardId != null) {
            final card = CardService.getCard(widget.cardId!);
            metadata = card?.metadata;
            print('[TopPrioritiesPage] Card metadata: $metadata');
          }

          // Fall back to widget metadata if necessary
          if (metadata == null) {
            metadata = widget.metadata;
            print('[TopPrioritiesPage] Using widget metadata: $metadata');
          }

          // Check if we have data for this date in the priorities
          final dayData = metadata?['priorities']?[dateKey];
          print('[TopPrioritiesPage] Day data for $dateKey: $dayData');

          if (dayData != null && dayData['tasks'] != null) {
            _tasks = List<Map<String, dynamic>>.from(dayData['tasks']);
            print('[TopPrioritiesPage] Using tasks from metadata');
            _migrateNotesToList();
          } else {
            _tasks = TopPrioritiesModel.getDefaultTasks();
            print('[TopPrioritiesPage] Using default tasks');
          }
        } else {
          _tasks = TopPrioritiesModel.getDefaultTasks();
          print('[TopPrioritiesPage] Using default tasks (not editing)');
        }

        // Initialize text controllers for the new tasks
        _initializeTextControllers();

        // Add listener to sync controller values with tasks
        _addTextControllerListeners();

        // Store initial state for change detection
        _initialTasks = List<Map<String, dynamic>>.from(_tasks.map((task) => Map<String, dynamic>.from(task)));

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
      if (!mounted) return;
      setState(() {
        _tasks = TopPrioritiesModel.getDefaultTasks();
        _initializeTextControllers();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // First, update task descriptions from text controllers
      _updateTasksFromControllers();

      final user = AuthService.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to save changes')),
        );
        return;
      }

      // Save priority entries
      await TopPrioritiesService.savePriorityEntries(
        _selectedDate,
        _tasks,
      );

      // Update card metadata if we have a card
      if (widget.cardId != null) {
        final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
        final updatedMetadata = {
          'type': 'top_priorities',
          'version': '1.0',
          'priorities': {
            dateKey: {
              'lastModified': DateTime.now().toIso8601String(),
              'tasks': _tasks,
            }
          }
        };
        await CardService.updateCardMetadata(widget.cardId!, updatedMetadata);
      }

      if (!mounted) return;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Changes saved'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print('Error saving top priorities: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add reminder time selection method
  Future<void> _selectTaskReminderTime(BuildContext context, String taskId) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
                              setState(() {
        // Find and update the task with the new reminder time
        for (var task in _tasks) {
          if (task['id'] == taskId) {
            task['reminderTime'] = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
            break;
          }
        }
      });

      // Schedule the reminder
      final reminderService = PrioritiesReminderService();
      await reminderService.scheduleDailyReminder(
        cardId: widget.cardId ?? taskId, // Use card ID if available, otherwise use task ID
        reminderTime: picked,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${picked.format(context)}'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }

  // Navigate to Edit Todo Card page
  void _openEditTodoCardPage() {
    if (widget.cardId == null) return;

    // Get the card to access its properties
    final card = CardService.getCard(widget.cardId!);
    if (card == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewTodoListPage(
          ocrText: '',
          initialResult: {
            'id': widget.cardId,
            'title': 'Daily Top Priorities',
            'color': card.color ?? '0xFF6C5CE7', // Use the card's color or default purple
            'tags': card.tags.toList(), // Include the card's tags
            'tasks': _tasks.map((task) => {
              'id': task['id'],
              'description': task['description'],
              'isCompleted': task['isCompleted'],
              'priority': task['priority'] ?? 'medium',
              'notes': task['notes'],
              'position': task['position'],
            }).toList(),
            'metadata': card.metadata ?? {}, // Include the card's metadata
          },
          onSaveCard: (updatedCard) async {
            try {
              // Update card in database
              await CardService.updateCard(updatedCard);

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              print('Error updating card: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating card: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          isViewMode: false,
        ),
      ),
    );
  }

  // Keep the delete card method for reference but it's not used anymore
  Future<void> _deleteCard() async {
    if (widget.cardId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Top 3 Priorities'),
        content: Text('Are you sure you want to delete this card? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete associated entries first
        await TopPrioritiesService.deleteEntriesForCard(widget.cardId!);
        // Then delete the card
        await CardService.deleteCard(widget.cardId!);
        if (!mounted) return;
        Navigator.pop(context); // Close the page
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting card: $e')),
        );
      }
    }
  }

  // Check if a top priorities card already exists for the current date
  Future<String?> _findExistingCardForDate() async {
    try {
      // Get all cards
      final cards = await CardService.getCards();

      // Filter for top priorities cards
      final topPrioritiesCards = cards.where((card) =>
        card.metadata != null && card.metadata!['type'] == 'top_priorities').toList();

      // Get the date key for the selected date
      final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);

      // Find a card that has data for the selected date
      for (final card in topPrioritiesCards) {
        if (card.metadata != null &&
            card.metadata!['priorities'] != null &&
            (card.metadata!['priorities'] as Map<String, dynamic>).containsKey(dateKey)) {
          return card.id;
        }
      }

      return null; // No existing card found for this date
    } catch (e) {
      print('Error finding existing card: $e');
      return null;
    }
  }

  Future<void> _createCard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First, update task descriptions from text controllers
      _updateTasksFromControllers();

      // Check if a card already exists for this date
      final existingCardId = await _findExistingCardForDate();

      String? cardId;
      if (existingCardId != null) {
        // Card already exists, just update it
        cardId = existingCardId;
        print('Using existing card: $cardId');

        // Update the card metadata
        final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
        final updatedMetadata = {
          'type': 'top_priorities',
          'version': '1.0',
          'priorities': {
            dateKey: {
              'lastModified': DateTime.now().toIso8601String(),
              'tasks': _tasks,
            }
          }
        };
        await CardService.updateCardMetadata(cardId, updatedMetadata);
      } else {
        // No existing card, create a new one
        cardId = await widget.onSave(TopPrioritiesModel.createDefaultMetadata());
        print('Created new card: $cardId');
      }

      // Save the entries
      await TopPrioritiesService.savePriorityEntries(
        _selectedDate,
        _tasks,
      );

      // No need to interact with todo_entries table for top priorities

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingCardId != null
              ? 'Changes saved successfully'
              : 'Top priorities card created successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Let WillPopScope handle the navigation
        // We'll return from _onBackPressed() which will trigger the navigation
      }
    } catch (e) {
      print('Error creating top priorities card: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating card: $e'),
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

  bool _isSpecialDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    return dateToCheck == today || // Today
           dateToCheck == today.subtract(Duration(days: 1)) || // Yesterday
           dateToCheck == today.add(Duration(days: 1)); // Tomorrow
  }

  // Add method to check if tasks have been modified
  bool _hasChanges() {
    if (_initialTasks == null || _initialTasks!.length != _tasks.length) {
      return true;
    }

    for (int i = 0; i < _tasks.length; i++) {
      final originalTask = _initialTasks![i];
      final currentTask = _tasks[i];

      if (currentTask['description'] != originalTask['description'] ||
          currentTask['notes'] != originalTask['notes'] ||
          currentTask['isCompleted'] != originalTask['isCompleted'] ||
          currentTask['reminderTime'] != originalTask['reminderTime'] ||
          currentTask['metadata']?['placeholder'] != originalTask['metadata']?['placeholder']) {
        return true;
      }
    }
    return false;
  }

  // Add method to handle back button press
  Future<bool> _onBackPressed() async {
    // First, update task descriptions from text controllers
    _updateTasksFromControllers();

    if (!widget.isEditing && _hasChanges()) {
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unsaved Changes'),
          content: Text('You have unsaved changes. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(0), // Discard
              child: Text('Discard Changes'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(1), // Create
              child: Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      );

      if (result == 1) {
        // User chose to save changes
        try {
          // Save the card
          await _saveCardWithoutPopping();

          // Return true to allow WillPopScope to handle the navigation
          return true;
        } catch (e) {
          print('Error saving card: $e');
          return false; // Don't pop if there was an error
        }
      } else if (result == 0) {
        // User chose to discard changes
        return true;
      }
      return false;
    }
    return true;
  }

  // Save card without popping the navigation stack
  Future<void> _saveCardWithoutPopping() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First, update task descriptions from text controllers
      _updateTasksFromControllers();

      // Check if a card already exists for this date
      final existingCardId = await _findExistingCardForDate();

      String? cardId;
      if (existingCardId != null) {
        // Card already exists, just update it
        cardId = existingCardId;
        print('Using existing card: $cardId');

        // Update the card metadata
        final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
        final updatedMetadata = {
          'type': 'top_priorities',
          'version': '1.0',
          'priorities': {
            dateKey: {
              'lastModified': DateTime.now().toIso8601String(),
              'tasks': _tasks,
            }
          }
        };
        await CardService.updateCardMetadata(cardId, updatedMetadata);
      } else {
        // No existing card, create a new one
        cardId = await widget.onSave(TopPrioritiesModel.createDefaultMetadata());
        print('Created new card: $cardId');
      }

      // Save all tasks to top_priorities_entries
      await TopPrioritiesService.savePriorityEntries(_selectedDate, _tasks);

      // No need to interact with todo_entries table for top priorities

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existingCardId != null
              ? 'Changes saved successfully'
              : 'Top priorities card created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving top priorities: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow; // Rethrow to handle in the calling method
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add new method to update tasks from text controllers
  void _updateTasksFromControllers() {
    for (var task in _tasks) {
      final id = task['id'] as String;
      if (_textControllers.containsKey(id)) {
        final controller = _textControllers[id];
        if (controller != null && controller.text != task['description']) {
          task['description'] = controller.text;

          // Update placeholder status based on text content
          if (task['metadata'] != null) {
            task['metadata']['placeholder'] = controller.text.isEmpty;
          }
        }
      }
    }
  }

  // Save tasks after deleting a task
  Future<void> _saveTasksAfterDelete(Map<String, dynamic> deletedTask) async {
    try {
      // First, update task descriptions from text controllers
      _updateTasksFromControllers();

      // Save to the top_priorities_entries table
      await TopPrioritiesService.savePriorityEntries(
        _selectedDate,
        _tasks,
      );

      print('Tasks saved successfully after deleting task: ${deletedTask['id']}');
    } catch (e) {
      print('Error saving tasks after delete: $e');
      rethrow; // Rethrow to handle in the calling method
    }
  }

  // Save task completion status to database
  Future<void> _saveTaskCompletionStatus(Map<String, dynamic> task) async {
    try {
      // First, update task descriptions from text controllers
      _updateTasksFromControllers();

      // Save only to the top_priorities_entries table, not to the card metadata
      // This avoids triggering the StreamBuilder which causes the infinite loop
      await TopPrioritiesService.savePriorityEntries(
        _selectedDate,
        _tasks,
      );

      print('Task completion status saved successfully: ${task['id']}, isCompleted: ${task['isCompleted']}');
    } catch (e) {
      print('Error saving task completion status: $e');
      rethrow; // Rethrow to handle in the calling method
    }
  }

  Future<void> _addDocument(Map<String, dynamic> task) async {
    try {
      // First ensure the task is saved
      if (task['id'] == null) {
        // Generate an ID for the task if it doesn't have one
        task['id'] = const Uuid().v4();
      }

      // Instead of saving just this task, save all tasks at once
      // This avoids conflicts with the unique_user_date_position constraint
      await TopPrioritiesService.savePriorityEntries(_selectedDate, _tasks);

      // Get or create a card ID
      String cardId;
      if (widget.isEditing && widget.cardId != null) {
        // If we're in editing mode, use the existing card ID
        cardId = widget.cardId!;

        // Update the card metadata
        final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
        final updatedMetadata = {
          'type': 'top_priorities',
          'version': '1.0',
          'priorities': {
            dateKey: {
              'lastModified': DateTime.now().toIso8601String(),
              'tasks': _tasks,
            }
          }
        };
        await CardService.updateCardMetadata(cardId, updatedMetadata);
      } else {
        // If we're in creation mode, create a temporary card
        final user = AuthService.currentUser;
        if (user == null) throw Exception('User not authenticated');

        // Create a temporary card in the cards table
        final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
        final tempCard = await CardService.createCard({
          'title': 'Daily Top Priorities',
          'description': 'Top priorities for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
          'color': '0xFF6C5CE7', // Purple color
          'tags': ['Daily', 'Priorities'],
          'metadata': {
            'type': 'top_priorities',
            'version': '1.0',
            'priorities': {
              dateKey: {
                'lastModified': DateTime.now().toIso8601String(),
                'tasks': _tasks,
              }
            }
          },
          'tasks': [], // No tasks in the card itself
        });

        cardId = tempCard.id;
      }

      // Make sure the task is saved in top_priorities_entries
      await TopPrioritiesService.savePriorityEntry(_selectedDate, task);

      final user = AuthService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp3', 'wav', 'pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.first;
        final fileName = file.name;
        final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

        // Check file size (5MB limit)
        if (file.size > 5 * 1024 * 1024) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('File Too Large'),
              content: Text('The selected file is too large. Please choose a file smaller than 5MB.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        if (!TopPrioritiesModel.supportedDocumentTypes.contains(mimeType)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsupported file type')),
          );
          return;
        }

        // Show loading indicator
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );

        try {

          // Upload the file using AttachmentService
          final attachmentType = mimeType.startsWith('image/') ? 'image' : 'document';
          final uploadResult = await AttachmentService.uploadAttachment(
            filePath: file.path!,
            fileName: fileName,
            mimeType: mimeType,
            sizeBytes: file.size,
            attachmentType: attachmentType,
            todoEntryId: task['id'],
            metadata: {
              'todo_entry_title': task['description'],
              'todo_entry_date': _selectedDate.toIso8601String(),
              'uploaded_at': DateTime.now().toIso8601String(),
            },
          );

          // Update the UI
          setState(() {
            // Ensure documents is initialized as a list
            if (task['documents'] == null || task['documents'] is! List) {
              task['documents'] = [];
            }

            // Add the new document
            (task['documents'] as List).add({
              'id': uploadResult['id'],
              'url': uploadResult['url'],
              'wasabi_path': uploadResult['wasabi_path'],
              'mimeType': uploadResult['mime_type'],
              'name': fileName,
              'todo_entry_id': task['id'],
            });
          });

          // Close loading indicator
          if (!mounted) return;
          Navigator.pop(context);
        } catch (e) {
          // Close loading indicator
          if (!mounted) return;
          Navigator.pop(context);

          // Show error
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload file: $e')),
          );
        }
      }
    } catch (e) {
      print('Error adding document: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding document: $e')),
      );
    }
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    try {
      final wasabiPath = doc['wasabi_path'];
      if (wasabiPath == null) {
        throw 'Missing document path';
      }

      final signedUrl = await StorageService.getSignedUrl(wasabiPath.toString());

      final mimeType = doc['mime_type']?.toString() ?? '';

      if (mimeType.startsWith('image/')) {
        // Show image in dialog using the signed URL
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Image.network(
              signedUrl,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text('Error loading image', style: TextStyle(color: Colors.red)),
                );
              },
            ),
          ),
        );
      } else if (mimeType.contains('pdf')) {
        // For PDFs, open directly in browser/system viewer
        if (await canLaunch(signedUrl)) {
          await launch(signedUrl);
        } else {
          throw 'Could not launch $signedUrl';
        }
      } else {
        // For other file types, open in browser/system viewer
        if (await canLaunch(signedUrl)) {
          await launch(signedUrl);
        } else {
          throw 'Could not launch $signedUrl';
        }
      }
    } catch (e) {
      print('Error opening document: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening document: $e')),
      );
    }
  }

  Future<void> _addVoiceNote(Map<String, dynamic> task) async {
    try {
      // First ensure the task is saved
      if (task['id'] == null) {
        // Generate an ID for the task if it doesn't have one
        task['id'] = const Uuid().v4();
      }

      // Save all tasks to top_priorities_entries table
      await TopPrioritiesService.savePriorityEntries(_selectedDate, _tasks);

      // Get the card ID (it should be available now)
      String? cardId = widget.cardId;
      if (cardId == null) {
        // Check if a card already exists for this date
        final existingCardId = await _findExistingCardForDate();

        if (existingCardId != null) {
          cardId = existingCardId;
        } else {
          // Create a new card
          final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
          final tempCard = await CardService.createCard({
            'title': 'Daily Top Priorities',
            'description': 'Top priorities for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
            'color': '0xFF6C5CE7', // Purple color
            'tags': ['Daily', 'Priorities'],
            'metadata': {
              'type': 'top_priorities',
              'version': '1.0',
              'priorities': {
                dateKey: {
                  'lastModified': DateTime.now().toIso8601String(),
                  'tasks': _tasks,
                }
              }
            },
            'tasks': [], // No tasks in the card itself
          });

          cardId = tempCard.id;
        }
      }

      // Make sure the task is saved in top_priorities_entries
      await TopPrioritiesService.savePriorityEntry(_selectedDate, task);

      final user = AuthService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final record = AudioRecorderService.instance;

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
        if (!mounted) return;
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
            if (!mounted) return;
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

              // Upload using AttachmentService
              final uploadResult = await AttachmentService.uploadAttachment(
                filePath: path,
                fileName: 'Voice Note ${DateTime.now().toString()}',
                mimeType: 'audio/mpeg',
                sizeBytes: await File(path).length(),
                attachmentType: 'audio',
                todoEntryId: task['id'],
                metadata: {
                  'todo_entry_title': task['description'],
                  'todo_entry_date': _selectedDate.toIso8601String(),
                  'uploaded_at': DateTime.now().toIso8601String(),
                },
              );

              // Update UI
              setState(() {
                // Ensure documents is initialized as a list
                if (task['documents'] == null || task['documents'] is! List) {
                  task['documents'] = [];
                }

                // Add the voice note
                (task['documents'] as List).add({
                  'id': uploadResult['id'],
                  'url': uploadResult['url'],
                  'wasabi_path': uploadResult['wasabi_path'],
                  'mimeType': uploadResult['mime_type'],
                  'name': 'Voice Note ${DateTime.now().toString()}',
                  'todo_entry_id': task['id'],
                });
              });

              // Close uploading dialog
              if (!mounted) return;
              Navigator.pop(context);
            } catch (e) {
              // Close uploading dialog
              if (!mounted) return;
              Navigator.pop(context);

              // Show error
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload voice note: $e')),
              );
            }
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      print('Error recording voice note: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording voice note: $e')),
      );
    }
  }

  int _getCompletedTasksCount() {
    return _tasks.where((task) => task['isCompleted'] == true).length;
  }

  double _getCompletionPercentage() {
    if (_tasks.isEmpty) return 0.0;
    return _getCompletedTasksCount() / _tasks.length;
  }

  String _getCompletionMessage() {
    final completedCount = _getCompletedTasksCount();
    final totalCount = _tasks.length;

    if (completedCount == 0) {
      return 'No tasks completed yet. You can do it!';
    } else if (completedCount == totalCount) {
      return 'All tasks completed! Great job!';
    } else {
      final remainingCount = totalCount - completedCount;
      final percentage = (completedCount / totalCount * 100).round();
      
      if (percentage < 25) {
        return 'Just getting started! $remainingCount more to go.';
      } else if (percentage < 50) {
        return 'Good progress! $remainingCount more remaining.';
      } else if (percentage < 75) {
        return 'More than halfway there! Keep going!';
      } else {
        return 'Almost done! Just $remainingCount more to complete.';
      }
    }
  }

  // Save task completion status in background without blocking UI
  void _saveTaskCompletionInBackground(Map<String, dynamic> task, bool? newValue) {
    Future.microtask(() async {
      try {
        // Update task descriptions from text controllers
        _updateTasksFromControllers();
        
        // Save to database
        await TopPrioritiesService.savePriorityEntries(
          _selectedDate, 
          _tasks,
        );
        
        print('Task completion status saved successfully: ${task['id']}, isCompleted: ${newValue}');
      } catch (e) {
        print('Error saving task completion status: $e');
        
        // Only update UI if widget is still mounted and there was an error
        if (mounted) {
          setState(() {
            // Revert the change
            task['isCompleted'] = !newValue!;
            
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating task: $e'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          });
        }
      }
    });
  }

  // Select a reminder time for a task
}