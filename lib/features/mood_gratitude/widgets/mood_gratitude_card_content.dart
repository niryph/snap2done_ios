import 'package:flutter/material.dart';
import '../models/mood_gratitude_models.dart';

class MoodGratitudeCardContent extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const MoodGratitudeCardContent({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<MoodGratitudeCardContent> createState() => _MoodGratitudeCardContentState();
}

class _MoodGratitudeCardContentState extends State<MoodGratitudeCardContent> {
  late DateTime _selectedDate;
  late List<MoodEntry> _entries;
  final TextEditingController _gratitudeController = TextEditingController();
  final List<String> _gratitudeItems = [];
  String? _selectedMood;
  final TextEditingController _moodNotesController = TextEditingController();
  bool _isExpanded = true; // Start expanded to show content
  bool _isUpdating = false; // Flag to prevent multiple simultaneous updates

  final List<Map<String, dynamic>> _moodOptions = [
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '🙂', 'label': 'Good'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😔', 'label': 'Sad'},
    {'emoji': '😡', 'label': 'Angry'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    
    // Ensure metadata has entries field initialized
    if (!widget.metadata.containsKey('entries')) {
      final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
      updatedMetadata['entries'] = [];
      widget.onMetadataChanged(updatedMetadata);
    }
    
    _loadEntriesForSelectedDate();
  }

  @override
  void dispose() {
    _gratitudeController.dispose();
    _moodNotesController.dispose();
    super.dispose();
  }

  List<MoodEntry> _getRecentEntries() {
    final List<dynamic> entriesData = widget.metadata['entries'] ?? [];
    if (entriesData.isEmpty) {
      return [];
    }
    
    try {
      final entries = entriesData
          .map((entry) => MoodEntry.fromMap(entry))
          .toList()
          .cast<MoodEntry>();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries.take(3).toList();
    } catch (e) {
      print('Error parsing mood entries: $e');
      return [];
    }
  }

  void _loadEntriesForSelectedDate() {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    _entries = _getRecentEntries();
    
    setState(() {
      _selectedMood = null;
      _moodNotesController.clear();
      _gratitudeItems.clear();
      _isUpdating = false;
    });
  }

  void _saveEntry() {
    if (_isUpdating) return;
    
    if (_selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your mood')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final entry = MoodEntry(
      date: _selectedDate,
      mood: _selectedMood!,
      moodNotes: _moodNotesController.text.isNotEmpty ? _moodNotesController.text : null,
      gratitudeItems: List.from(_gratitudeItems),
      createdAt: DateTime.now(),
    );

    final List<dynamic> currentEntries = List.from(widget.metadata['entries'] ?? []);
    currentEntries.add(entry.toMap());

    final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
    updatedMetadata['entries'] = currentEntries;

    widget.onMetadataChanged(updatedMetadata);

    setState(() {
      _entries = _getRecentEntries();
      _selectedMood = null;
      _moodNotesController.clear();
      _gratitudeItems.clear();
      _isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry saved successfully')),
    );
  }

  void _addGratitudeItem() {
    if (_gratitudeController.text.isEmpty) return;
    if (_gratitudeItems.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 gratitude items allowed')),
      );
      return;
    }

    setState(() {
      _gratitudeItems.add(_gratitudeController.text);
      _gratitudeController.clear();
    });
  }

  String _getMoodEmoji(String mood) {
    const moodEmojis = {
      'Happy': '😊',
      'Good': '🙂',
      'Neutral': '😐',
      'Sad': '😔',
      'Angry': '😡',
    };
    return moodEmojis[mood] ?? '😐';
  }

  @override
  Widget build(BuildContext context) {
    final recentEntries = _getRecentEntries();
    final latestEntry = recentEntries.isNotEmpty ? recentEntries.first : null;

    return Column(children: [
      // Date Display and Selector
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null && picked != _selectedDate) {
                setState(() {
                  _selectedDate = picked;
                  _loadEntriesForSelectedDate();
                });
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 16),

      // Mood Selection
      const Text(
        'How are you feeling today?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _moodOptions.map((option) => InkWell(
          onTap: () {
            setState(() {
              _selectedMood = option['label'];
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedMood == option['label']
                  ? Colors.blue.withOpacity(0.1)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  option['emoji'],
                  style: const TextStyle(fontSize: 24),
                ),
                Text(option['label']),
              ],
            ),
          ),
        )).toList(),
      ),
      const SizedBox(height: 16),

      // Mood Notes
      TextField(
        controller: _moodNotesController,
        decoration: const InputDecoration(
          labelText: 'Add notes about your mood (optional)',
          border: OutlineInputBorder(),
        ),
        maxLines: 2,
      ),
      const SizedBox(height: 16),

      // Gratitude Items
      const Text(
        'What are you grateful for today?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _gratitudeController,
              decoration: const InputDecoration(
                hintText: 'Enter a gratitude item',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addGratitudeItem,
          ),
        ],
      ),
      const SizedBox(height: 8),
      ..._gratitudeItems.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text('• $item'),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                setState(() {
                  _gratitudeItems.remove(item);
                });
              },
            ),
          ],
        ),
      )).toList(),
      const SizedBox(height: 16),

      // Save Button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saveEntry,
          child: const Text('Save Entry'),
        ),
      ),
    ]);
  }
}