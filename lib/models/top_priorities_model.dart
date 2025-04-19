  static Map<String, dynamic> createDefaultMetadata() {
    final now = DateTime.now();
    final dateKey = dateToKey(now);
    
    return {
      'title': 'Daily Top Priorities',
      'description': 'Focus on your most important tasks',
      'color': 0xFFE53935,  // Red color
      'tags': ['Productivity'],
      'metadata': {
        'type': 'top_priorities',
        'version': '1.0',
        'priorities': {
          dateKey: {
            'lastModified': now.toIso8601String(),
            'tasks': getDefaultTasks(),
          }
        }
      }
    };
  } 