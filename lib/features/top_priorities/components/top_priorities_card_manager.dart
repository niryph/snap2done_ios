import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/top_priorities_service.dart';
import '../models/top_priorities_model.dart';

class TopPrioritiesCardManager {
  final BuildContext context;
  final Function setState;
  final Function onSave;
  final Function? onPageShown;
  final DateTime selectedDate;
  String? createdCardId;

  TopPrioritiesCardManager({
    required this.context,
    required this.setState,
    required this.onSave,
    required this.selectedDate,
    this.onPageShown,
  });

  Future<bool> checkUnsavedChanges(List<Map<String, dynamic>> tasks) async {
    bool hasUnsavedChanges = false;
    for (var task in tasks) {
      if (task['modified'] == true) {
        hasUnsavedChanges = true;
        break;
      }
    }

    if (hasUnsavedChanges) {
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. Would you like to create a new card or discard the changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 1),
              child: const Text('Create Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      );

      if (result == 1) {
        // User chose to create card
        await createCard();
        return true;
      } else if (result == 0) {
        // User chose to discard changes
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> createCard() async {
    try {
      // Create the card first
      createdCardId = await onSave(TopPrioritiesModel.createDefaultMetadata());
      
      // Call onPageShown callback if provided
      if (onPageShown != null && createdCardId != null) {
        await onPageShown!(createdCardId!);
      }
      
      // Load the created tasks
      if (context.mounted) {
        final savedTasks = await TopPrioritiesService.getEntriesForDate(selectedDate);
        if (savedTasks.isNotEmpty) {
          setState(() {
            // Update tasks and migrate notes
            _updateTasksAndMigrateNotes(savedTasks);
          });
        }
      }
    } catch (e) {
      print('Error creating card: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating card: $e')),
        );
      }
    }
  }

  Future<void> createInitialCard() async {
    try {
      // Create the card first
      createdCardId = await onSave(TopPrioritiesModel.createDefaultMetadata());
      
      // Call onPageShown callback if provided
      if (onPageShown != null && createdCardId != null) {
        await onPageShown!(createdCardId!);
      }
      
      // Load the created tasks
      if (context.mounted) {
        final savedTasks = await TopPrioritiesService.getEntriesForDate(selectedDate);
        if (savedTasks.isNotEmpty) {
          setState(() {
            // Update tasks and migrate notes
            _updateTasksAndMigrateNotes(savedTasks);
          });
        }
      }
    } catch (e) {
      print('Error creating initial card: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating card: $e')),
        );
      }
    }
  }

  void _updateTasksAndMigrateNotes(List<Map<String, dynamic>> savedTasks) {
    for (var task in savedTasks) {
      if (task['notes'] != null && task['notes'] is String) {
        // Migrate old string notes to list format
        task['notes'] = [
          {
            'id': const Uuid().v4(),
            'text': task['notes'],
            'created_at': DateTime.now().toIso8601String(),
          }
        ];
      }
    }
    // Update the tasks in state
    setState(() {
      // Your state update logic here
    });
  }
}