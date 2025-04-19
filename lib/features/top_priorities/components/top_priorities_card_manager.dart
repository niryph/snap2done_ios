import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/card_service.dart';
import '../services/top_priorities_service.dart';
import '../models/top_priorities_model.dart';
import '../../../models/card_model.dart';

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
          content: const Text('You have unsaved changes. Would you like to save your changes or discard them?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 1),
              child: const Text('Save Changes'),
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

  // Check if a top priorities card already exists for the current date
  Future<String?> _findExistingCardForDate() async {
    try {
      // Get all cards
      final cards = await CardService.getCards();

      // Filter for top priorities cards
      final topPrioritiesCards = cards.where((card) =>
        card.metadata != null && card.metadata!['type'] == 'top_priorities').toList();

      // Get the date key for the selected date
      final dateKey = TopPrioritiesModel.dateToKey(selectedDate);

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

  Future<void> createCard() async {
    try {
      // Check if a card already exists for this date
      final existingCardId = await _findExistingCardForDate();

      if (existingCardId != null) {
        // Card already exists, just update it
        createdCardId = existingCardId;
        print('Using existing card: $createdCardId');

        // Update the card metadata
        final dateKey = TopPrioritiesModel.dateToKey(selectedDate);
        final updatedMetadata = {
          'type': 'top_priorities',
          'version': '1.0',
          'priorities': {
            dateKey: {
              'lastModified': DateTime.now().toIso8601String(),
              // We don't have tasks here, so we'll just update the lastModified timestamp
            }
          }
        };
        await CardService.updateCardMetadata(createdCardId!, updatedMetadata);
      } else {
        // No existing card, create a new one
        createdCardId = await onSave(TopPrioritiesModel.createDefaultMetadata());
        print('Created new card: $createdCardId');
      }

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
      print('Error creating/updating card: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    }
  }

  Future<void> createInitialCard() async {
    try {
      // Check if a card already exists for this date
      final existingCardId = await _findExistingCardForDate();

      if (existingCardId != null) {
        // Card already exists, just update it
        createdCardId = existingCardId;
        print('Using existing card for initial card: $createdCardId');

        // Update the card metadata
        final dateKey = TopPrioritiesModel.dateToKey(selectedDate);
        final updatedMetadata = {
          'type': 'top_priorities',
          'version': '1.0',
          'priorities': {
            dateKey: {
              'lastModified': DateTime.now().toIso8601String(),
              // We don't have tasks here, so we'll just update the lastModified timestamp
            }
          }
        };
        await CardService.updateCardMetadata(createdCardId!, updatedMetadata);
      } else {
        // No existing card, create a new one
        createdCardId = await onSave(TopPrioritiesModel.createDefaultMetadata());
        print('Created new initial card: $createdCardId');
      }

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
      print('Error creating/updating initial card: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
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