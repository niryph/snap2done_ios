import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../services/audio_recorder_service.dart';
import '../../../services/attachment_service.dart';
import '../services/top_priorities_service.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as path;

class TopPrioritiesVoiceNoteHandler {
  final BuildContext context;
  final Function setState;
  final bool isEditing;
  final DateTime selectedDate;

  TopPrioritiesVoiceNoteHandler({
    required this.context,
    required this.setState,
    required this.isEditing,
    required this.selectedDate,
  });

  Future<void> addVoiceNote(Map<String, dynamic> task) async {
    try {
      // First ensure the task is saved
      if (!isEditing || task['id'] == null) {
        // Generate an ID for the task if it doesn't have one
        if (task['id'] == null) {
          task['id'] = const Uuid().v4();
        }
        await TopPrioritiesService.savePriorityEntry(selectedDate, task);
      } else {
        // For existing tasks, ensure it exists in the database
        final taskExists = await TopPrioritiesService.checkTaskExists(task['id']);
        if (!taskExists) {
          await TopPrioritiesService.savePriorityEntry(selectedDate, task);
        }
      }

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
        if (!context.mounted) return;
        final shouldStop = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Recording Voice Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Recording in progress...'),
                const SizedBox(height: 16),
                const Text('Tap Stop when finished'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Stop Recording'),
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
            if (!context.mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Uploading Voice Note'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Please wait...'),
                  ],
                ),
              ),
            );

            try {
              // Upload using AttachmentService
              await _uploadVoiceNote(path, task);

              // Update UI
              setState(() {
                if (task['documents'] == null) {
                  task['documents'] = [];
                }
                task['documents'].add({
                  'id': response['id'],
                  'url': response['url'],
                  'wasabi_path': response['wasabi_path'],
                  'mime_type': response['mime_type'],
                  'name': 'Voice Note ${DateTime.now().toString()}',
                  'task_id': task['id'],
                });
              });

              // Close uploading dialog
              if (!context.mounted) return;
              Navigator.pop(context);
            } catch (e) {
              // Close uploading dialog
              if (!context.mounted) return;
              Navigator.pop(context);
              
              // Show error
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload voice note: $e')),
              );
            }
          }
        }
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      print('Error recording voice note: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording voice note: $e')),
      );
    }
  }

  Future<void> _uploadVoiceNote(String filePath, Map<String, dynamic> todoEntry) async {
    try {
      final File file = File(filePath);
      final String fileName = path.basename(filePath);
      final String mimeType = lookupMimeType(fileName) ?? 'audio/mpeg';
      final int sizeBytes = await file.length();

      final response = await AttachmentService.uploadAttachment(
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        attachmentType: 'voice_note',
        todoEntryId: todoEntry['id'],
        metadata: {
          'todo_entry_title': todoEntry['title'],
          'todo_entry_date': todoEntry['date'],
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      // ... existing code ...
    } catch (e) {
      print('Error uploading voice note: $e');
      // ... existing error handling code ...
    }
  }
}