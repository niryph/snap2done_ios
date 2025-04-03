import 'package:flutter/material.dart';
import '../models/mood_gratitude_models.dart';
import '../widgets/mood_gratitude_card.dart';
import '../widgets/mood_analytics_graph.dart';
import '../../../services/mood_gratitude_service.dart';

class MoodGratitudeLogPage extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const MoodGratitudeLogPage({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<MoodGratitudeLogPage> createState() => _MoodGratitudeLogPageState();
}

class _MoodGratitudeLogPageState extends State<MoodGratitudeLogPage> {
  late List<MoodEntry> _entries;
  bool _isLoading = true;
  DateTime _selectedDay = DateTime.now();
  String _selectedTimeRange = 'week';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final dbEntries = await MoodGratitudeService.getEntries();
      final List<dynamic> metadataEntriesData = widget.metadata['entries'] ?? [];
      
      final metadataEntries = metadataEntriesData
          .map((entry) => MoodEntry.fromMap(entry))
          .toList()
          .cast<MoodEntry>();
      
      final Map<String, MoodEntry> entriesMap = {};
      
      for (final entry in dbEntries) {
        final dateKey = entry.dateString;
        entriesMap[dateKey] = entry;
      }
      
      for (final entry in metadataEntries) {
        final dateKey = entry.dateString;
        if (!entriesMap.containsKey(dateKey)) {
          entriesMap[dateKey] = entry;
        }
      }
      
      _entries = entriesMap.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading entries: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _entries = [];
        });
      }
    }
  }

  void _onDateChanged(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
  }

  Widget _buildDateNavigation() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                _onDateChanged(_selectedDay.subtract(const Duration(days: 1)));
              },
            ),
            GestureDetector(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDay,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  _onDateChanged(picked);
                }
              },
              child: Row(
                children: [
                  Text(
                    '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today, size: 20),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _selectedDay.isBefore(DateTime.now()) 
                ? () {
                    _onDateChanged(_selectedDay.add(const Duration(days: 1)));
                  }
                : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood & Gratitude Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: MoodGratitudeCard(
                    cardId: widget.cardId,
                    metadata: widget.metadata,
                    onMetadataChanged: widget.onMetadataChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView(
                children: [
                  // Date Navigation
                  _buildDateNavigation(),
                  
                  // Time Range Selector for Analytics
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'week', label: Text('Week')),
                        ButtonSegment(value: 'month', label: Text('Month')),
                        ButtonSegment(value: 'year', label: Text('Year')),
                      ],
                      selected: {_selectedTimeRange},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _selectedTimeRange = newSelection.first;
                        });
                      },
                    ),
                  ),
                  
                  // Analytics Graph
                  MoodAnalyticsGraph(
                    entries: _entries,
                    timeRange: _selectedTimeRange,
                  ),
                  
                  // Selected Day's Entry or Recent Entries
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Entries for ${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ..._entries
                      .where((entry) => entry.dateString == 
                          '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}')
                      .map(_buildEntryCard)
                      .toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryCard(MoodEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _editEntry(entry),
                      tooltip: 'Edit Entry',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteEntry(entry),
                      tooltip: 'Delete Entry',
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mood: ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      _getMoodEmoji(entry.mood),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
            if (entry.moodNotes != null && entry.moodNotes!.isNotEmpty) ...[              
              const SizedBox(height: 8),
              Text(
                'Notes: ${entry.moodNotes}',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            if (entry.gratitudeItems.isNotEmpty) ...[              
              const SizedBox(height: 8),
              const Text(
                'Grateful for:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...entry.gratitudeItems.map((item) => Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                child: Text('• $item'),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editEntry(MoodEntry entry) async {
    // Show the MoodGratitudeCard in edit mode
    final editedEntry = await showDialog<MoodEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Entry'),
        content: SizedBox(
          width: double.maxFinite,
          child: MoodGratitudeCard(
            cardId: widget.cardId,
            metadata: widget.metadata,
            onMetadataChanged: widget.onMetadataChanged,
            initialEntry: entry,
            isEditing: true,
          ),
        ),
      ),
    );

    if (editedEntry != null) {
      try {
        // Update the entry in the database
        await MoodGratitudeService.updateEntry(entry.id!, editedEntry);
        
        // Refresh the entries list
        if (mounted) {
          _loadEntries();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating entry: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && entry.id != null) {
      try {
        // Delete the entry from the database
        await MoodGratitudeService.deleteEntry(entry.id!);
        
        // Refresh the entries list
        if (mounted) {
          _loadEntries();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting entry: $e')),
          );
        }
      }
    }
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
}

class MoodGratitudeSettingsPage extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;

  const MoodGratitudeSettingsPage({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<MoodGratitudeSettingsPage> createState() => _MoodGratitudeSettingsPageState();
}

class _MoodGratitudeSettingsPageState extends State<MoodGratitudeSettingsPage> {
  late MoodGratitudeSettings _settings;
  bool _isLoading = true;
  bool _isMigrating = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // First check if we need to migrate settings from user_settings
      setState(() {
        _isMigrating = true;
      });
      
      final migratedSettings = await MoodGratitudeService.migrateSettingsFromUserSettings();
      
      if (mounted) {
        setState(() {
          _isMigrating = false;
        });
      }
      
      // If migration returned settings, use them
      if (migratedSettings != null) {
        _settings = migratedSettings;
      } else {
        // Otherwise load from dedicated table
        _settings = await MoodGratitudeService.getMoodGratitudeSettings();
      }
      
      print('Settings loaded successfully: ${_settings.toMap()}');
    } catch (e) {
      print('Error loading settings: $e');
      // Fallback to default settings if error
      _settings = MoodGratitudeSettings.defaultSettings();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Save settings to database
      final updatedSettings = await MoodGratitudeService.saveMoodGratitudeSettings(_settings);
      
      // Update local state with the returned settings
      _settings = updatedSettings;

      // Also update card metadata
      final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
      updatedMetadata['settings'] = _settings.toMap();
      widget.onMetadataChanged(updatedMetadata);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      print('Error saving settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Helper to edit favorite moods
  Future<void> _editFavoriteMoods() async {
    List<String> tempMoods = List.from(_settings.favoriteMoods);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Favorite Moods'),
        content: SizedBox(
          width: double.maxFinite,
          child: FavoriteMoodsEditor(
            initialMoods: tempMoods,
            onMoodsChanged: (moods) {
              tempMoods = moods;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _settings = _settings.copyWith(favoriteMoods: tempMoods);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mood & Gratitude Settings'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              if (_isMigrating)
                const Text('Migrating settings...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood & Gratitude Settings'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reminders',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Enable Daily Reminders'),
                          subtitle: const Text('Get notifications to log your mood and gratitude'),
                          value: _settings.remindersEnabled,
                          onChanged: (value) {
                            setState(() {
                              _settings = _settings.copyWith(remindersEnabled: value);
                            });
                          },
                        ),
                        ListTile(
                          title: const Text('Reminder Time'),
                          subtitle: Text(
                            '${_settings.reminderTime.hour.toString().padLeft(2, '0')}:${_settings.reminderTime.minute.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.access_time),
                          enabled: _settings.remindersEnabled,
                          onTap: _settings.remindersEnabled
                              ? () async {
                                  final timeOfDay = await showTimePicker(
                                    context: context,
                                    initialTime: _settings.reminderTime,
                                  );
                                  if (timeOfDay != null && mounted) {
                                    setState(() {
                                      _settings = _settings.copyWith(reminderTime: timeOfDay);
                                    });
                                  }
                                }
                              : null,
                        ),
                        SwitchListTile(
                          title: const Text('Enable Notifications'),
                          subtitle: const Text('Show in-app notifications for mood updates'),
                          value: _settings.notificationEnabled,
                          onChanged: (value) {
                            setState(() {
                              _settings = _settings.copyWith(notificationEnabled: value);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Entry Settings',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Maximum Gratitude Items'),
                          subtitle: const Text('How many items you can add per entry'),
                          trailing: DropdownButton<int>(
                            value: _settings.maxGratitudeItems,
                            items: [1, 2, 3, 4, 5].map((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(value.toString()),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null && mounted) {
                                setState(() {
                                  _settings = _settings.copyWith(maxGratitudeItems: newValue);
                                });
                              }
                            },
                          ),
                        ),
                        ListTile(
                          title: const Text('Favorite Moods'),
                          subtitle: Text(_settings.favoriteMoods.join(', ')),
                          trailing: const Icon(Icons.edit),
                          onTap: _editFavoriteMoods,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Add save button at the bottom
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget to edit favorite moods
class FavoriteMoodsEditor extends StatefulWidget {
  final List<String> initialMoods;
  final Function(List<String>) onMoodsChanged;
  
  const FavoriteMoodsEditor({
    Key? key, 
    required this.initialMoods,
    required this.onMoodsChanged,
  }) : super(key: key);
  
  @override
  FavoriteMoodsEditorState createState() => FavoriteMoodsEditorState();
}

class FavoriteMoodsEditorState extends State<FavoriteMoodsEditor> {
  late List<String> _moods;
  final TextEditingController _controller = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _moods = List.from(widget.initialMoods);
  }
  
  List<String> getMoods() => _moods;
  
  void _addMood() {
    if (_controller.text.isEmpty) return;
    
    if (_moods.contains(_controller.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_controller.text} already exists')),
      );
      return;
    }
    
    setState(() {
      _moods.add(_controller.text);
      _controller.clear();
    });
    
    widget.onMoodsChanged(_moods);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Add or remove moods for your mood tracking'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'New Mood',
                  hintText: 'Enter a mood name',
                ),
                onSubmitted: (_) => _addMood(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addMood,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _moods.isEmpty
              ? const Center(child: Text('No moods added yet'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _moods.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_moods[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _moods.removeAt(index);
                          });
                          widget.onMoodsChanged(_moods);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}