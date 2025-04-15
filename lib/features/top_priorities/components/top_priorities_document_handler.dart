import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/storage_service.dart';
import '../../../services/attachment_service.dart';
import '../services/top_priorities_service.dart';
import '../models/top_priorities_model.dart';

class TopPrioritiesDocumentHandler {
  final BuildContext context;
  final Function setState;
  final bool isEditing;
  final DateTime selectedDate;

  TopPrioritiesDocumentHandler({
    required this.context,
    required this.setState,
    required this.isEditing,
    required this.selectedDate,
  });

  Future<void> addDocument(Map<String, dynamic> task) async {
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
          if (!context.mounted) return;
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('File Too Large'),
              content: const Text('The selected file is too large. Please choose a file smaller than 5MB.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }

        if (!TopPrioritiesModel.supportedDocumentTypes.contains(mimeType)) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported file type')),
          );
          return;
        }

        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        try {
          // Upload the file using AttachmentService
          final attachmentType = mimeType.startsWith('image/') ? 'image' : 'document';
          final uploadResult = await AttachmentService.uploadAttachment(
            File(file.path!),
            attachmentType,
            description: 'Uploaded via task attachment',
          );

          // Update the UI
          setState(() {
            if (task['documents'] == null) {
              task['documents'] = [];
            }
            task['documents'].add({
              'id': uploadResult['id'],
              'url': uploadResult['url'],
              'wasabi_path': uploadResult['wasabi_path'],
              'mime_type': uploadResult['mime_type'],
              'name': fileName,
              'task_id': task['id'],
            });
          });

          // Close loading indicator
          if (!context.mounted) return;
          Navigator.pop(context);
        } catch (e) {
          // Close loading indicator
          if (!context.mounted) return;
          Navigator.pop(context);
          
          // Show error
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload file: $e')),
          );
        }
      }
    } catch (e) {
      print('Error adding document: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding document: $e')),
      );
    }
  }

  Future<void> openDocument(Map<String, dynamic> doc) async {
    try {
      final signedUrl = await StorageService.getSignedUrl(doc['wasabi_path']);
      
      if (doc['mime_type'].startsWith('image/')) {
        // Show image in dialog using the signed URL
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Image.network(signedUrl),
          ),
        );
      } else {
        // For other file types, open in browser/system viewer
        final uri = Uri.parse(signedUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw 'Could not launch $signedUrl';
        }
      }
    } catch (e) {
      print('Error opening document: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening document: $e')),
      );
    }
  }
}