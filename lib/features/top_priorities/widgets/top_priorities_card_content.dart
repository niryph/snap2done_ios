import 'package:flutter/material.dart';
import '../models/top_priorities_models.dart';
import '../pages/top_priorities_page.dart';

class TopPrioritiesCardContent extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const TopPrioritiesCardContent({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<TopPrioritiesCardContent> createState() => _TopPrioritiesCardContentState();
}

class _TopPrioritiesCardContentState extends State<TopPrioritiesCardContent> {
  late DateTime _selectedDate;
  late List<Map<String, dynamic>> _currentDayTasks;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadTasksForSelectedDate();
  }

  void _loadTasksForSelectedDate() {
    final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
    final dayData = widget.metadata['priorities']?[dateKey];
    
    print('TopPrioritiesCardContent: Loading tasks for date $dateKey');
    print('TopPrioritiesCardContent: Metadata: ${widget.metadata}');
    print('TopPrioritiesCardContent: Day data: $dayData');
    
    if (dayData != null) {
      _currentDayTasks = List<Map<String, dynamic>>.from(dayData['tasks']);
      print('TopPrioritiesCardContent: Loaded ${_currentDayTasks.length} tasks');
    } else {
      // If no data for this date, create default tasks
      _currentDayTasks = TopPrioritiesModel.getDefaultTasks();
      print('TopPrioritiesCardContent: Created default tasks');
      
      // Save these default tasks to metadata
      _saveDefaultTasksForDate();
    }
  }

  Future<void> _saveDefaultTasksForDate() async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
      final newMetadata = Map<String, dynamic>.from(widget.metadata);
      
      print('TopPrioritiesCardContent: Saving default tasks for date $dateKey');
      print('TopPrioritiesCardContent: Original metadata: ${widget.metadata}');
      
      // Ensure priorities map exists
      if (newMetadata['priorities'] == null) {
        newMetadata['priorities'] = {};
        print('TopPrioritiesCardContent: Created priorities map');
      }
      
      // Add default tasks for this date
      newMetadata['priorities'][dateKey] = {
        'tasks': _currentDayTasks,
        'lastModified': DateTime.now().toIso8601String(),
      };
      
      print('TopPrioritiesCardContent: Updated metadata: $newMetadata');
      
      // Notify parent of changes
      await widget.onMetadataChanged(newMetadata);
      print('TopPrioritiesCardContent: Metadata updated successfully');
    } catch (e) {
      print('Error saving default tasks: $e');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _navigateDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    
    // Allow navigating to any date (past or future)
    setState(() {
      _selectedDate = newDate;
      _loadTasksForSelectedDate();
    });
  }

  Future<void> _toggleTaskCompletion(int index) async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
      // Toggle completion status
      _currentDayTasks[index]['isCompleted'] = !_currentDayTasks[index]['isCompleted'];
    });
    
    try {
      final dateKey = TopPrioritiesModel.dateToKey(_selectedDate);
      final newMetadata = Map<String, dynamic>.from(widget.metadata);
      
      // Ensure priorities map exists
      if (newMetadata['priorities'] == null) {
        newMetadata['priorities'] = {};
      }
      
      // Update tasks for this date
      newMetadata['priorities'][dateKey] = {
        'tasks': _currentDayTasks,
        'lastModified': DateTime.now().toIso8601String(),
      };
      
      // Notify parent of changes
      await widget.onMetadataChanged(newMetadata);
    } catch (e) {
      // If there's an error, revert the local change
      setState(() {
        _currentDayTasks[index]['isCompleted'] = !_currentDayTasks[index]['isCompleted'];
      });
      
      print('Error updating task completion: $e');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  void _editPriorities() {
    print('TopPrioritiesCardContent: Opening edit page');
    print('TopPrioritiesCardContent: cardId: ${widget.cardId}, metadata: ${widget.metadata}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TopPrioritiesPage(
          cardId: widget.cardId,
          metadata: widget.metadata,
          onSave: widget.onMetadataChanged,
          isEditing: true,
        ),
      ),
    ).then((_) {
      print('TopPrioritiesCardContent: Returned from edit page');
      // Reload tasks when returning from edit page
      _loadTasksForSelectedDate();
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'low':
        return Colors.blue.shade100;
      default:
        return Colors.red.shade100;
    }
  }

  Color _getPriorityTextColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red.shade900;
      case 'medium':
        return Colors.orange.shade900;
      case 'low':
        return Colors.blue.shade900;
      default:
        return Colors.red.shade900;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'MED';
      case 'low':
        return 'LOW';
      default:
        return 'HIGH';
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _currentDayTasks.where((task) => task['isCompleted']).length;
    final totalCount = _currentDayTasks.length;
    final progressPercentage = totalCount > 0 ? completedCount / totalCount : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date navigation bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous day button
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () => _navigateDate(-1),
              ),
              
              // Date display
              GestureDetector(
                onTap: _editPriorities,
                child: Text(
                  TopPrioritiesModel.formatDate(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Next day button (disabled if future date)
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () => _navigateDate(1),
              ),
            ],
          ),
        ),
        
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$completedCount/$totalCount completed',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        
        // Tasks list
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _currentDayTasks.length,
          itemBuilder: (context, index) {
            final task = _currentDayTasks[index];
            return ListTile(
              leading: Checkbox(
                value: task['isCompleted'],
                onChanged: (_) => _toggleTaskCompletion(index),
              ),
              title: Text(
                task['description'].isEmpty ? 'Priority #${index + 1}' : task['description'],
                style: TextStyle(
                  decoration: task['isCompleted'] ? TextDecoration.lineThrough : null,
                  color: task['isCompleted'] ? Colors.grey : null,
                  fontStyle: task['description'].isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(task['priority']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getPriorityText(task['priority']),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getPriorityTextColor(task['priority']),
                  ),
                ),
              ),
            );
          },
        ),
        
        // Edit button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ElevatedButton.icon(
              onPressed: _editPriorities,
              icon: Icon(Icons.edit),
              label: Text('Edit Priorities'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 