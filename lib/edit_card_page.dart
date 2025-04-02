import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'services/notification_service.dart';
import 'models/task_model.dart';
import 'dart:developer' as developer;
import 'dart:convert';

class EditCardPage extends StatefulWidget {
  final Map<String, dynamic> card;
  final Function(Map<String, dynamic>) onSave;
  final Function(String) onDelete;

  const EditCardPage({
    Key? key,
    required this.card,
    required this.onSave,
    required this.onDelete,
  }) : super(key: key);

  @override
  _EditCardPageState createState() => _EditCardPageState();
}

class _EditCardPageState extends State<EditCardPage> {
  late TextEditingController _titleController;
  late List<Map<String, dynamic>> _tasks;
  late Color _selectedColor;
  late List<String> _tags;
  late TextEditingController _newTagController;
  bool _isLoading = false;
  final NotificationService _notificationService = NotificationService();

  // Available background colors
  final List<Color> _availableColors = [
    Color(0xFFF5F5F7), // Default light
    Color(0xFF483D8B), // Deep purple
    Color(0xFFC8FF00), // Lime
    Color(0xFF3498DB), // Blue
    Color(0xFFE74C3C), // Red
    Color(0xFF2ECC71), // Green
    Color(0xFFF39C12), // Orange
  ];

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card['title']);
    _newTagController = TextEditingController();
    
    // Create a deep copy of the tasks list
    _tasks = List<Map<String, dynamic>>.from(
      widget.card['tasks'].map((task) => Map<String, dynamic>.from(task))
    );
    
    // Initialize tags
    _tags = widget.card.containsKey('tags') && widget.card['tags'] is List
        ? List<String>.from(widget.card['tags'])
        : ['Personal']; // Default tag
    
    // Set the initial color based on the card's color
    _selectedColor = _getColorFromCardId(widget.card['id']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  // Get color based on card ID
  Color _getColorFromCardId(String cardId) {
    // First check if the card has a custom color property
    if (widget.card.containsKey('color') && widget.card['color'] != null) {
      return Color(widget.card['color']);
    }
    
    // Otherwise use the default color based on card type
    switch (cardId) {
      case 'grocery':
        return Color(0xFFF5F5F7);
      case 'christmas':
        return Color(0xFFC8FF00);
      case 'lorem':
        return Color(0xFF483D8B);
      default:
        return Color(0xFFF5F5F7);
    }
  }

  // Get card ID based on color
  String _getCardIdFromColor(Color color) {
    if (color == Color(0xFFF5F5F7)) return 'grocery';
    if (color == Color(0xFFC8FF00)) return 'christmas';
    if (color == Color(0xFF483D8B)) return 'lorem';
    
    // For new colors, generate a unique ID
    return 'card_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Show color picker dialog
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _selectedColor,
              onColorChanged: (Color color) {
                setState(() {
                  _selectedColor = color;
                });
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              showLabel: true,
              paletteType: PaletteType.hsvWithHue,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Done'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Add a new tag
  void _addTag(String tag) {
    if (tag.isEmpty) return;
    
    setState(() {
      if (!_tags.contains(tag)) {
        _tags.add(tag);
      }
      _newTagController.clear();
    });
  }

  // Remove a tag
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      // Ensure there's always at least one tag
      if (_tags.isEmpty) {
        _tags.add('Personal');
      }
    });
  }

  // Build a task item widget
  Widget _buildTaskItem(Map<String, dynamic> task, int index) {
    final TextEditingController titleController = TextEditingController(text: task['title']);
    final TextEditingController descriptionController = TextEditingController(text: task['description'] ?? '');
    
    // Get reminder date from task if it exists
    final DateTime? reminderDate = task.containsKey('reminderDate') ? task['reminderDate'] : null;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Check if the task is in editing mode
    final bool isEditing = task['isEditing'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        child: isEditing 
            ? _buildEditingTaskItem(task, index, titleController, descriptionController, reminderDate)
            : _buildCollapsedTaskItem(task, index, reminderDate),
      ),
    );
  }
  
  // Build collapsed (view mode) task item
  Widget _buildCollapsedTaskItem(Map<String, dynamic> task, int index, DateTime? reminderDate) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isCompleted = task['isCompleted'] ?? false;
    
    return Row(
      children: [
        // Left colored border
        Container(
          width: 8,
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ),
        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Task title with completion checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Completion checkbox
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          task['isCompleted'] = !isCompleted;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: 8, top: 2),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isCompleted 
                              ? _selectedColor.withOpacity(0.9) 
                              : _selectedColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _selectedColor.withOpacity(0.8),
                            width: 1.5,
                          ),
                        ),
                        child: isCompleted
                            ? Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                    // Task title
                    Expanded(
                      child: Text(
                        task['title'] ?? 'Task',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          decoration: isCompleted 
                              ? TextDecoration.lineThrough 
                              : TextDecoration.none,
                          decorationColor: isDarkMode ? Colors.white : Colors.black87,
                          decorationThickness: 2.0,
                        ),
                      ),
                    ),
                    // Edit button
                    IconButton(
                      icon: Icon(Icons.edit, color: _selectedColor, size: 20),
                      onPressed: () {
                        setState(() {
                          task['isEditing'] = true;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    SizedBox(width: 8),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () {
                        setState(() {
                          _tasks.removeAt(index);
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                
                // Description if available
                if (task['description'] != null && task['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 28.0),
                    child: Text(
                      task['description'],
                      style: TextStyle(
                        fontSize: 12, 
                        color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                
                SizedBox(height: 8),
                Divider(color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Priority indicator
                    Row(
                      children: [
                        _getPriorityIcon(task['priority'] ?? 'medium'),
                        SizedBox(width: 4),
                        Text(
                          _getPriorityText(task['priority'] ?? 'medium'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    
                    // Reminder indicator if set
                    if (reminderDate != null)
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: _selectedColor,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatReminderDate(reminderDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Build editing mode task item
  Widget _buildEditingTaskItem(Map<String, dynamic> task, int index, 
      TextEditingController titleController, TextEditingController descriptionController, DateTime? reminderDate) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with description and action buttons
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Spacer(),
              // Reminder button
              IconButton(
                icon: Icon(
                  reminderDate != null ? Icons.notifications_active : Icons.notifications_none,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => _showReminderDialog(index),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 16),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    _tasks.removeAt(index);
                  });
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 16),
              // Cancel button
              TextButton(
                onPressed: () {
                  setState(() {
                    task['isEditing'] = false;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
                child: Text('Cancel'),
              ),
              SizedBox(width: 8),
              // Done button
              TextButton(
                onPressed: () {
                  setState(() {
                    task['isEditing'] = false;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _selectedColor,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size(0, 0),
                ),
                child: Text('Done'),
              ),
            ],
          ),
        ),
        
        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title field
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onChanged: (value) {
                  setState(() {
                    task['title'] = value;
                  });
                },
              ),
              
              SizedBox(height: 16),
              
              // Description field
              Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white.withOpacity(0.8) : Colors.grey.shade700,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  hintText: 'Task description (optional)',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onChanged: (value) {
                  setState(() {
                    task['description'] = value;
                  });
                },
                maxLines: 3,
              ),
            ],
          ),
        ),
        
        // Bottom action bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              // Priority dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: DropdownButton<String>(
                  value: task['priority'] ?? 'medium',
                  icon: Icon(Icons.arrow_drop_down, color: _selectedColor),
                  underline: SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('🟢 Low'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('🟡 Medium'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('🔴 High'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      task['priority'] = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Helper method to get priority icon
  Widget _getPriorityIcon(String priority) {
    switch (priority) {
      case 'low':
        return Text('🟢', style: TextStyle(fontSize: 14));
      case 'high':
        return Text('🔴', style: TextStyle(fontSize: 14));
      case 'medium':
      default:
        return Text('🟡', style: TextStyle(fontSize: 14));
    }
  }
  
  // Helper method to get priority text
  String _getPriorityText(String priority) {
    switch (priority) {
      case 'low':
        return 'Low';
      case 'high':
        return 'High';
      case 'medium':
      default:
        return 'Medium';
    }
  }
  
  // Format reminder date for display
  String _formatReminderDate(DateTime? date) {
    if (date == null) return 'No reminder set';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  // Show dialog to set or remove a reminder
  void _showReminderDialog(int taskIndex) {
    final task = _tasks[taskIndex];
    DateTime? selectedDate = task.containsKey('reminderDate') ? task['reminderDate'] : null;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Set Reminder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Current reminder: ${_formatReminderDate(selectedDate)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Select Date & Time:'),
                      TextButton(
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          
                          if (pickedDate != null) {
                            final TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: selectedDate != null 
                                  ? TimeOfDay.fromDateTime(selectedDate!) 
                                  : TimeOfDay.now(),
                            );
                            
                            if (pickedTime != null) {
                              setState(() {
                                selectedDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Text(
                          selectedDate == null ? 'Pick Date & Time' : 'Change',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  if (selectedDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            selectedDate = null;
                          });
                        },
                        child: Text(
                          'Remove Reminder',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    this.setState(() {
                      task['reminderDate'] = selectedDate;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Save card with reminders
  void _saveCard() async {
    // Validate title
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for the card'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    // Create updated card
    final updatedCard = {
      ...widget.card,
      'title': _titleController.text,
      'tasks': _tasks,
      'tags': _tags,
      'color': _selectedColor.value,
    };
    
    // Schedule notifications for tasks with reminders
    for (final task in _tasks) {
      final String taskId = task['id'] ?? '';
      final DateTime? reminderDate = task['reminderDate'];
      
      // Cancel any existing notification for this task
      if (taskId.isNotEmpty) {
        await _notificationService.cancelNotification(taskId);
      }
      
      // Schedule new notification if reminder is set and task is not completed
      if (reminderDate != null && !(task['isCompleted'] ?? false)) {
        // Only schedule if reminder is in the future
        if (reminderDate.isAfter(DateTime.now())) {
          await _notificationService.scheduleTaskReminder(
            taskId: taskId,
            title: 'Task Reminder',
            body: task['title'] ?? 'You have a task to complete',
            scheduledDate: reminderDate,
          );
          developer.log('Scheduled reminder for task $taskId at $reminderDate', name: 'EditCardPage');
        }
      }
    }
    
    // Call the onSave callback
    developer.log('Saving card with title: ${_titleController.text}', name: 'EditCardPage');
    developer.log('Card data: ${json.encode(updatedCard)}', name: 'EditCardPage');
    
    try {
      widget.onSave(updatedCard);
      developer.log('Card saved successfully via callback', name: 'EditCardPage');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back after successful save
      Navigator.pop(context);
    } catch (e) {
      developer.log('Error saving card: $e', name: 'EditCardPage');
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving card: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  // Delete the card
  void _deleteCard() {
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
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete(widget.card['id']);
              Navigator.pop(context); // Close edit page
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate text color based on background brightness
    double brightness = (_selectedColor.red * 299 + 
                         _selectedColor.green * 587 + 
                         _selectedColor.blue * 114) / 1000;
    Color textColor = brightness > 125 ? Colors.black87 : Colors.white;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Card'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteCard,
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveCard,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
              color: _selectedColor,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title section
                      Text(
                        'Card Title',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _selectedColor.withOpacity(0.7),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: textColor),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Add divider after title section
                      Divider(
                        color: textColor.withOpacity(0.3),
                        thickness: 1,
                      ),
                      SizedBox(height: 8),
                      
                      // Color section
                      Text(
                        'Background Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Display colors in a grid-like layout with two rows
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ..._availableColors.map((color) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                              child: Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedColor == color
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: _selectedColor == color
                                  ? Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                              ),
                            );
                          }).toList(),
                          // Custom color picker
                          GestureDetector(
                            onTap: _showColorPicker,
                            child: Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.add, color: Colors.grey, size: 18),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      
                      // Add divider after color section
                      Divider(
                        color: textColor.withOpacity(0.3),
                        thickness: 1,
                      ),
                      SizedBox(height: 8),
                      
                      // Tags section
                      Text(
                        'Tags',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Selected tags with X button
                          ..._tags.map((tag) {
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
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
                                        color: Colors.black,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _removeTag(tag),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.black.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          
                          // Add tag button
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => _buildAddTagDialog(),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Color(0xFF6C5CE7),
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
                                      color: Color(0xFF6C5CE7),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: Color(0xFF6C5CE7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      
                      // Add divider after tags section
                      Divider(
                        color: textColor.withOpacity(0.3),
                        thickness: 1,
                      ),
                      SizedBox(height: 8),
                      
                      // Tasks section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tasks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.add),
                            label: Text('Add Task'),
                            onPressed: _addTask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: textColor.withOpacity(0.2),
                              foregroundColor: textColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ..._tasks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final task = entry.value;
                        return _buildTaskItem(task, index);
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  // Helper method to build the add tag dialog
  Widget _buildAddTagDialog() {
    return AlertDialog(
      title: Text('Add Tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newTagController,
            decoration: InputDecoration(
              hintText: 'Enter tag name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                _addTag(value);
                Navigator.pop(context);
              }
            },
          ),
          SizedBox(height: 16),
          Text('Common Tags'),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonTags.map((tag) {
              return GestureDetector(
                onTap: () {
                  _addTag(tag);
                  Navigator.pop(context);
                },
                child: Chip(
                  label: Text(tag),
                  backgroundColor: Colors.grey.shade200,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_newTagController.text.isNotEmpty) {
              _addTag(_newTagController.text);
              _newTagController.clear();
              Navigator.pop(context);
            }
          },
          child: Text('Add'),
        ),
      ],
    );
  }

  // Add a new task
  void _addTask() {
    setState(() {
      _tasks.add({
        'title': 'New task',
        'description': '',
        'priority': 'medium',
        'isCompleted': false,
        'isEditing': true,
      });
    });
  }
} 