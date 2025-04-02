import 'package:flutter/material.dart';
import '../models/mood_gratitude_models.dart';
import '../../../services/mood_gratitude_service.dart';
import '../../../services/card_service.dart';

class MoodGratitudeCard extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onMetadataChanged;
  final MoodEntry? initialEntry;
  final bool isEditing;

  const MoodGratitudeCard({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onMetadataChanged,
    this.initialEntry,
    this.isEditing = false,
  }) : super(key: key);

  @override
  State<MoodGratitudeCard> createState() => _MoodGratitudeCardState();
}

class _MoodGratitudeCardState extends State<MoodGratitudeCard> {
  late String _selectedMood;
  late String _moodNotes;
  late List<String> _gratitudeItems;
  late DateTime _selectedDate;
  bool _isLoading = false;
  bool _isExpanded = false;
  bool _isRefreshing = false;
  late List<MoodEntry> _entries;
  final TextEditingController _gratitudeController = TextEditingController();
  final TextEditingController _moodNotesController = TextEditingController();

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
    print('MoodGratitudeCard: initState called - DEBUGGING');
    _initializeState();
    
    // Make sure the entries array exists in metadata and type is set correctly
    if (widget.metadata.isEmpty || widget.metadata == null) {
      print('MoodGratitudeCard: ERROR - metadata is empty or null');
      // Initialize the metadata with an empty entries array and type
      final updatedMetadata = {
        'type': 'mood_gratitude',
        'entries': [],
      };
      // Notify parent of the metadata change
      widget.onMetadataChanged(updatedMetadata);
    } else if (!widget.metadata.containsKey('entries')) {
      print('MoodGratitudeCard: Initializing entries array in metadata');
      final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
      updatedMetadata['entries'] = [];
      if (!updatedMetadata.containsKey('type')) {
        updatedMetadata['type'] = 'mood_gratitude';
      }
      widget.onMetadataChanged(updatedMetadata);
    } else if (!widget.metadata.containsKey('type') || widget.metadata['type'] != 'mood_gratitude') {
      print('MoodGratitudeCard: Setting correct type in metadata');
      final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
      updatedMetadata['type'] = 'mood_gratitude';
      widget.onMetadataChanged(updatedMetadata);
    }
    
    _entries = _getRecentEntries();
    
    // Trigger a refresh of entries from database
    _triggerRefreshEntries();
    
    // Force a rebuild after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('MoodGratitudeCard: Post-frame callback executed');
        setState(() {});
      }
    });
  }

  void _initializeState() {
    if (widget.initialEntry != null) {
      _selectedMood = widget.initialEntry!.mood;
      _moodNotes = widget.initialEntry!.moodNotes ?? '';
      _moodNotesController.text = _moodNotes;
      _gratitudeItems = List.from(widget.initialEntry!.gratitudeItems);
      _selectedDate = widget.initialEntry!.date;
    } else {
      _selectedMood = 'Neutral';
      _moodNotes = '';
      _moodNotesController.clear();
      _gratitudeItems = [];
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _saveEntry() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final entry = MoodEntry(
        id: widget.initialEntry?.id,
        date: _selectedDate,
        mood: _selectedMood,
        moodNotes: _moodNotes.isEmpty ? null : _moodNotes,
        gratitudeItems: _gratitudeItems,
      );

      Map<String, dynamic> savedEntry;
      if (widget.isEditing && widget.initialEntry?.id != null) {
        // Update existing entry
        savedEntry = await MoodGratitudeService.updateEntry(widget.initialEntry!.id!, entry);
      } else {
        // Save new entry
        savedEntry = await MoodGratitudeService.saveEntry(entry);
      }

      // Update metadata
      final List<dynamic> currentEntries = List.from(widget.metadata['entries'] ?? []);
      
      if (widget.isEditing) {
        // Replace the edited entry
        final index = currentEntries.indexWhere((e) => e['id'] == widget.initialEntry!.id);
        if (index != -1) {
          currentEntries[index] = savedEntry;
        }
      } else {
        // Add new entry
        currentEntries.add(savedEntry);
      }

      // Sort entries by date, most recent first
      currentEntries.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA);
      });

      final updatedMetadata = {
        ...widget.metadata,
        'entries': currentEntries,
        'todayMood': _selectedMood, // Update today's mood
      };

      widget.onMetadataChanged(updatedMetadata);

      if (mounted) {
        if (widget.isEditing) {
          Navigator.pop(context, MoodEntry.fromMap(savedEntry));
        } else {
          // Clear the form for a new entry
          setState(() {
            _selectedMood = 'Neutral';
            _moodNotes = '';
            _moodNotesController.clear();
            _gratitudeItems = [];
            _selectedDate = DateTime.now();
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry saved successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<MoodEntry> _getRecentEntries() {
    final List<dynamic> entriesData = widget.metadata['entries'] ?? [];
    if (entriesData.isEmpty) {
      print('MoodGratitudeCard: No entries found in metadata');
      return [];
    }
    
    try {
      final entries = entriesData
          .map((entry) => MoodEntry.fromMap(entry))
          .toList()
          .cast<MoodEntry>();
      
      // Make sure entries are sorted by date, most recent first
      entries.sort((a, b) => b.date.compareTo(a.date));
      
      final recentEntries = entries.take(3).toList();
      
      if (recentEntries.isNotEmpty) {
        print('MoodGratitudeCard: Latest entry in _getRecentEntries: ${recentEntries.first.mood} on ${recentEntries.first.date}');
      }
      
      return recentEntries;
    } catch (e) {
      print('Error parsing mood entries: $e');
      return [];
    }
  }

  void _loadEntriesForSelectedDate() {
    _entries = _getRecentEntries();
    setState(() {
      _selectedMood = 'Neutral';
      _moodNotesController.clear();
      _moodNotes = '';
      _gratitudeItems.clear();
    });
  }

  // Method to trigger refreshing entries without calling directly from build
  void _triggerRefreshEntries() {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _refreshLatestEntries().then((_) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    });
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
  void dispose() {
    _gratitudeController.dispose();
    _moodNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('MoodGratitudeCard: Building widget with expansion state: $_isExpanded - DEBUGGING');
    
    // Get the recent entries for display
    final recentEntries = _getRecentEntries();
    final latestEntry = recentEntries.isNotEmpty ? recentEntries.first : null;
    print('MoodGratitudeCard: Latest entry: ${latestEntry?.toMap()}');
    
    return Card(
      color: Colors.white,
      elevation: 4.0,
      margin: const EdgeInsets.all(8.0),
      // Add physics property to prevent scrolling
      child: InkWell(
        onTap: () {
          // Instead of expanding in-place, show a modal bottom sheet
          if (!_isExpanded) {
            _showExpandedContent(context);
          }
        },
        // Add a fixed height container to prevent layout shifts
        child: Stack(
          children: [
            Container(
              height: latestEntry != null && latestEntry.gratitudeItems.isNotEmpty ? 120 : 100,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mood & Gratitude',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showExpandedContent(context),
                      ),
                    ],
                  ),
                  if (latestEntry != null) ...[
                    Row(
                      children: [
                        Text(
                          'Latest Mood: ',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          _getMoodEmoji(latestEntry.mood),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                    if (latestEntry.gratitudeItems.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Recent Gratitude: ${latestEntry.gratitudeItems.first}',
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ] else
                    const Text(
                      'No entries yet. Tap to start tracking!',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
            // Show a loading indicator when refreshing
            if (_isRefreshing)
              Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to update metadata from database entries
  void _updateMetadataFromDbEntries(List<MoodEntry> dbEntries) {
    print('MoodGratitudeCard: Updating metadata with DB entries');
    
    // Make sure entries are sorted by date, most recent first
    dbEntries.sort((a, b) => b.date.compareTo(a.date));
    
    if (dbEntries.isNotEmpty) {
      print('MoodGratitudeCard: Latest entry from DB: ${dbEntries.first.mood} on ${dbEntries.first.date}');
    }
    
    // Take the top 10 most recent entries to keep metadata size manageable
    final entriesToStore = dbEntries.take(10).toList();
    
    // Convert entries to maps
    final entryMaps = entriesToStore.map((entry) {
      // Ensure we preserve the exact date format from the database entry
      final map = entry.toMap();
      
      // The toMap already converts to ISO8601, but ensure all dates are normalized
      // to handle any date format inconsistencies
      if (map['date'] is String) {
        // Normalize to just the date part (YYYY-MM-DD) to avoid time differences
        final datePart = DateTime.parse(map['date']).toIso8601String().split('T')[0];
        map['date'] = "${datePart}T00:00:00.000";
      }
      
      return map;
    }).toList();
    
    // Update metadata
    final updatedMetadata = Map<String, dynamic>.from(widget.metadata);
    updatedMetadata['entries'] = entryMaps;
    updatedMetadata['type'] = 'mood_gratitude';
    if (entriesToStore.isNotEmpty) {
      updatedMetadata['todayMood'] = entriesToStore.first.mood;
      print('MoodGratitudeCard: Setting todayMood to ${entriesToStore.first.mood}');
    }
    
    print('MoodGratitudeCard: Updating metadata with ${entryMaps.length} entries');
    
    // Notify parent of metadata change
    widget.onMetadataChanged(updatedMetadata);
  }

  // Modified to better handle date formats
  Future<void> _refreshLatestEntries() async {
    print('MoodGratitudeCard: Refreshing latest entries');
    
    // Check if widget is still mounted before proceeding
    if (!mounted) {
      print('MoodGratitudeCard: Widget not mounted, skipping refresh');
      return;
    }
    
    try {
      // Get the latest entry from the database
      final dbEntries = await MoodGratitudeService.getEntries(
        // Limit to one month back to keep it efficient
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      
      // Check mounted again after the async operation
      if (!mounted) {
        print('MoodGratitudeCard: Widget no longer mounted after database query');
        return;
      }
      
      if (dbEntries.isEmpty) {
        print('MoodGratitudeCard: No entries found in database');
        return;
      }
      
      print('MoodGratitudeCard: Found ${dbEntries.length} entries in database');
      
      // Check if the most recent DB entry is newer than what's in metadata
      final List<dynamic> metadataEntries = widget.metadata['entries'] ?? [];
      
      if (metadataEntries.isEmpty) {
        print('MoodGratitudeCard: No entries in metadata, updating with DB entries');
        _updateMetadataFromDbEntries(dbEntries);
        return;
      }
      
      try {
        print('MoodGratitudeCard: Comparing database entries with metadata entries');
        
        // Get the most recent entry from both sources
        final latestDbEntry = dbEntries.first;
        print('MoodGratitudeCard: Latest DB entry date: ${latestDbEntry.date}');
        
        // For metadata, sort first to ensure we're getting the most recent
        metadataEntries.sort((a, b) => 
          DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
          
        final latestMetadataEntry = MoodEntry.fromMap(metadataEntries.first);
        print('MoodGratitudeCard: Latest metadata entry date: ${latestMetadataEntry.date}');
        
        // Normalize the dates to strip time for comparison
        final dbDateString = "${latestDbEntry.date.year}-${latestDbEntry.date.month.toString().padLeft(2, '0')}-${latestDbEntry.date.day.toString().padLeft(2, '0')}";
        final metaDateString = "${latestMetadataEntry.date.year}-${latestMetadataEntry.date.month.toString().padLeft(2, '0')}-${latestMetadataEntry.date.day.toString().padLeft(2, '0')}";
        
        print('MoodGratitudeCard: Comparing dates - DB: $dbDateString, Metadata: $metaDateString');
        
        // Compare the date strings and update if needed
        if (dbDateString != metaDateString || latestDbEntry.mood != latestMetadataEntry.mood) {
          print('MoodGratitudeCard: Different entries found, updating metadata');
          _updateMetadataFromDbEntries(dbEntries);
        } else {
          print('MoodGratitudeCard: Entries match, no update needed');
        }
      } catch (e) {
        print('MoodGratitudeCard: Error comparing entries: $e');
        // If there's an error comparing, just update with DB entries
        if (mounted) {
          _updateMetadataFromDbEntries(dbEntries);
        }
      }
    } catch (e) {
      print('MoodGratitudeCard: Error refreshing entries: $e');
    }
  }

  void _showExpandedContent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      // Add these properties to better control the modal
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mood & Gratitude',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    // Date selector
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
                    const Text(
                      'How are you feeling today?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    
                    // Mood options
                    Wrap(
                      spacing: 8,
                      children: _moodOptions.map((option) {
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedMood = option['label'];
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedMood == option['label']
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                              ),
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
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    TextField(
                      controller: _moodNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'How are you feeling?',
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 24),
                    const Text(
                      'What are you grateful for today?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    
                    // Gratitude list
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _gratitudeItems.isEmpty
                          ? const Center(child: Text('No items yet'))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _gratitudeItems.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(_gratitudeItems[index]),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        _gratitudeItems.removeAt(index);
                                      });
                                      Navigator.pop(context);
                                      _showExpandedContent(context);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // Add gratitude item
                    if (_gratitudeItems.length < 3)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _gratitudeController,
                              decoration: const InputDecoration(
                                hintText: 'Enter something you\'re grateful for',
                              ),
                              onSubmitted: (_) {
                                _addGratitudeItem();
                                Navigator.pop(context);
                                _showExpandedContent(context);
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              _addGratitudeItem();
                              Navigator.pop(context);
                              _showExpandedContent(context);
                            },
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _saveEntry();
                          Navigator.pop(context);
                        },
                        child: const Text('Save Entry'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}