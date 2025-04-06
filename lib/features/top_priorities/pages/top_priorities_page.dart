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
  final _uuid = Uuid();
  bool _isLoading = false;
  int? _draggedItemIndex;
  
  // Add a map to store text controllers for each task
  final Map<String, TextEditingController> _textControllers = {};
  // Map to store individual reminder times for each task
  final Map<String, TimeOfDay?> _taskReminderTimes = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    if (widget.isEditing && widget.metadata != null) {
      // Initialize from existing metadata
      _initializeFromMetadata();
    } else {
      // Initialize with defaults for new card
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
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);

    return Stack(
      children: [
        // Background pattern
        Positioned.fill(
          child: themeProvider.isDarkMode
              ? BackgroundPatterns.darkThemeBackground()
              : BackgroundPatterns.lightThemeBackground(),
        ),
        
        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(widget.isEditing ? 'Daily Top Priorities' : 'Create Daily Top Priorities'),
            backgroundColor: themeProvider.isDarkMode ? Colors.grey[900]?.withOpacity(0.7) : Colors.white.withOpacity(0.7),
            foregroundColor: themeProvider.isDarkMode ? Colors.white : Colors.black87,
            elevation: 0,
            actions: [
              if (widget.isEditing) 
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: _deleteCard,
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
                                            onChanged: (value) {
                                              setState(() {
                                                task['isCompleted'] = value;
                                              });
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
                                            task['description'] ?? '',
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
                                                    initialValue: task['metadata']?['placeholder'] == true ? '' : (task['description'] ?? ''),
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
                  _tasks.add({
                    'id': _uuid.v4(),
                    'description': '',
                    'notes': '',
                    'isCompleted': false,
                    'position': _tasks.length,
                    'metadata': {
                      'type': 'top_priority',
                      'order': _tasks.length + 1,
                      'placeholder': true,
                    },
                  });
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
        ),
      ],
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

  Future<void> _saveChanges() async {
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

  Future<void> _createCard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call onSave callback to create the card
      final cardId = await widget.onSave(TopPrioritiesModel.createDefaultMetadata());
      
      // Save the entries
      await TopPrioritiesService.savePriorityEntries(
        _selectedDate,
        _tasks,
      );

      if (mounted) {
        // Pop back to previous screen after successful creation
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Top priorities card created successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
} 