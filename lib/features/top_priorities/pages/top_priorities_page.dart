import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/top_priorities_models.dart';
import '../services/priorities_reminder_service.dart';
import '../services/top_priorities_service.dart';
import '../models/top_priorities_entry_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/card_service.dart';
import '../../../models/card_model.dart';
import '../../../models/task_model.dart';
import '../../../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/theme_provider.dart';

class TopPrioritiesPage extends StatefulWidget {
  final String? cardId;
  final Map<String, dynamic>? metadata;
  final Function(Map<String, dynamic>)? onSave;
  final bool isEditing;

  const TopPrioritiesPage({
    Key? key,
    this.cardId,
    this.metadata,
    this.onSave,
    this.isEditing = false,
  }) : super(key: key);

  @override
  State<TopPrioritiesPage> createState() => _TopPrioritiesPageState();
}

class _TopPrioritiesPageState extends State<TopPrioritiesPage> {
  late DateTime _selectedDate;
  late TimeOfDay _reminderTime;
  late List<Map<String, dynamic>> _tasks;
  final _uuid = Uuid();
  bool _isLoading = false;
  int? _draggedItemIndex;
  
  // Add a map to store text controllers for each task
  final Map<String, TextEditingController> _textControllers = {};
  // Map to store individual reminder times for each task
  final Map<String, TimeOfDay?> _taskReminderTimes = {};

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

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    if (widget.isEditing && widget.metadata != null) {
      // Initialize from existing metadata
      _initializeFromMetadata();
    } else {
      // Initialize with defaults
      _tasks = TopPrioritiesModel.getDefaultTasks();
      _initializeTextControllers();
    }
  }
  
  @override
  void dispose() {
    // Dispose all text controllers
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  // Initialize text controllers for each task
  void _initializeTextControllers() {
    for (var task in _tasks) {
      final id = task['id'] as String;
      _textControllers[id] = TextEditingController(text: task['description'] as String);
    }
  }

  void _initializeFromMetadata() {
    // Get tasks for today or create defaults
    final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
    final dayData = widget.metadata!['priorities']?[dateKey];
    
    if (dayData != null) {
      _tasks = List<Map<String, dynamic>>.from(dayData['tasks']);
    } else {
      _tasks = TopPrioritiesModel.getDefaultTasks();
    }
    
    // Initialize text controllers
    _initializeTextControllers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TopPrioritiesModel.getTitleForDate(_selectedDate)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date navigation
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
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
                                      TopPrioritiesModel.formatDate(_selectedDate),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
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
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    key: ValueKey('tile-${task['id']}-${task['isExpanded'] ?? false}'),
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        task['isExpanded'] = expanded;
                                      });
                                    },
                                    initiallyExpanded: task['isExpanded'] ?? false,
                                    maintainState: false,
                                    leading: Checkbox(
                                      value: task['isCompleted'] ?? false,
                                      activeColor: Theme.of(context).primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          task['isCompleted'] = value;
                                        });
                                      },
                                    ),
                                    title: Text(
                                      task['description'] ?? '',
                                      style: TextStyle(
                                        decoration: task['isCompleted'] == true ? TextDecoration.lineThrough : null,
                                        fontSize: 16,
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
                                            TextFormField(
                                              initialValue: task['description'] ?? '',
                                              decoration: InputDecoration(
                                                labelText: 'Description',
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
                                              ),
                                              onChanged: (value) {
                                                task['description'] = value;
                                              },
                                            ),
                                            SizedBox(height: 16),
                                            // Notes field
                                            TextFormField(
                                              initialValue: task['notes'] ?? '',
                                              decoration: InputDecoration(
                                                labelText: 'Notes',
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
                                              ),
                                              maxLines: 3,
                                              onChanged: (value) {
                                                task['notes'] = value;
                                              },
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
                                                  onPressed: () async {
      setState(() {
                                                      task['isExpanded'] = false;
                                                    });
                                                    // Save changes when Done is clicked
                                                    await _saveCard();
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

  void _selectDate(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _isLoading = true;
    });
    
    try {
      // Load tasks from the service for the selected date
      final savedTasks = await TopPrioritiesService.getEntriesForDate(date);
    
    setState(() {
        if (savedTasks.isNotEmpty) {
          _tasks = savedTasks;
        } else if (widget.isEditing && widget.metadata != null) {
          // Fall back to metadata if available
          final dateKey = TopPrioritiesModel.dateToKey(date);
          final dayData = widget.metadata!['priorities']?[dateKey];
          if (dayData != null) {
            _tasks = List<Map<String, dynamic>>.from(dayData['tasks']);
          } else {
            _tasks = TopPrioritiesModel.getDefaultTasks();
          }
        } else {
          _tasks = TopPrioritiesModel.getDefaultTasks();
        }
        _initializeTextControllers();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading tasks: $e');
    setState(() {
        _tasks = TopPrioritiesModel.getDefaultTasks();
        _initializeTextControllers();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCard() async {
    if (_isLoading) return;
    
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = AuthService.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in to save changes')),
        );
        return;
      }
      
      // Ensure all tasks have valid UUIDs
      for (var task in _tasks) {
        if (task['id'] == null || task['id'].toString().isEmpty) {
          task['id'] = _uuid.v4();
        }
      }
      
      String cardId;
      CardModel? savedCard;
      final now = DateTime.now();
        final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);

      // Create or update the card first
      if (widget.isEditing && widget.cardId != null) {
        cardId = widget.cardId!;
        // Update existing card
        final existingCard = await CardService.getCardById(cardId);
        final cardData = {
          ...existingCard.toMap(),
          'id': cardId,
          'updated_at': now.toIso8601String(),
          'metadata': {
            'type': 'top_priority',
            'version': '1.0',
            'priorities': {
              dateKey: {
                'lastModified': now.toIso8601String(),
                'tasks': _tasks,
              }
            }
          },
        };
        savedCard = await CardService.updateCard(cardData);
      } else {
        // Create new card
        final cardData = {
          'id': _uuid.v4(),
          'user_id': user.id,
          'title': 'Top 3 Priorities',
          'description': 'Daily top priorities tracker',
          'color': '0xFFE53935',
          'tags': ['Productivity', 'Priorities'],
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'is_favorited': false,
          'metadata': {
            'type': 'top_priority',
            'version': '1.0',
            'priorities': {
              dateKey: {
                'lastModified': now.toIso8601String(),
                'tasks': _tasks,
              }
            }
          },
          'tasks': [], // Empty tasks array since we're using separate table
        };
        
        savedCard = await CardService.createCard(cardData, notifyListeners: true);
        cardId = savedCard.id;
      }

      // Save all entries for the current date
      await TopPrioritiesService.savePriorityEntries(_selectedDate, _tasks);

      // Force a cards refresh before navigation
      await CardService.getCards();

      // Reload tasks for the current date to ensure UI is up to date
      final savedTasks = await TopPrioritiesService.getEntriesForDate(_selectedDate);
      if (!mounted) return;
      setState(() {
        if (savedTasks.isNotEmpty) {
          _tasks = savedTasks;
          _initializeTextControllers();
        }
        });
        
        // Show success message
      if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text('Changes saved'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Only navigate back if we're creating a new card
      if (!widget.isEditing) {
        if (!mounted) return;
        Navigator.pop(context, savedCard);
      }

    } catch (e) {
      print('Error saving changes: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
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
} 