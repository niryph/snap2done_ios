import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class TopPrioritiesModel {
  static const int maxDescriptionLength = 200;
  static const int maxNoteLength = 500;
  static final _uuid = Uuid();

  static final supportedDocumentTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'audio/mpeg',
    'audio/wav',
    'audio/m4a',
  ];

  static String dateToKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDate(DateTime date, BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    final tomorrow = today.add(Duration(days: 1));
    final yesterday = today.subtract(Duration(days: 1));

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == tomorrow) {
      return 'Tomorrow';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
    }
  }

  static Map<String, dynamic> createDefaultTask(int index) {
    return {
      'id': _uuid.v4(),
      'description': '',
      'notes': <String>[],
      'isCompleted': false,
      'position': index,
      'documents': <Map<String, dynamic>>[],
      'metadata': {
        'type': 'top_priority',
        'order': index + 1,
        'placeholder': true,
      },
    };
  }

  static List<Map<String, dynamic>> getDefaultTasks() {
    return List.generate(3, (index) => createDefaultTask(index));
  }

  static Map<String, dynamic> createDefaultMetadata() {
    final now = DateTime.now();
    final dateKey = dateToKey(now);
    
    return {
      'type': 'top_priorities',
      'version': '1.0',
      'priorities': {
        dateKey: {
          'lastModified': now.toIso8601String(),
          'tasks': getDefaultTasks(),
        }
      }
    };
  }

  static String getDocumentTypeIcon(String? mimeType) {
    if (mimeType == null) return 'assets/images/document_icon.png';
    
    if (mimeType.startsWith('image/')) {
      return 'assets/images/image_icon.png';
    } else if (mimeType.startsWith('audio/')) {
      return 'assets/images/audio_icon.png';
    } else if (mimeType.startsWith('application/pdf')) {
      return 'assets/images/pdf_icon.png';
    } else if (mimeType.startsWith('application/msword') || 
              mimeType.startsWith('application/vnd.openxmlformats-officedocument.wordprocessingml')) {
      return 'assets/images/doc_icon.png';
    }
    
    return 'assets/images/document_icon.png';
  }
} 