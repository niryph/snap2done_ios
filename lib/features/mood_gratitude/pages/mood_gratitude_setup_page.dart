import 'package:flutter/material.dart';
import '../models/mood_gratitude_models.dart';
import 'mood_gratitude_log_page.dart';
import '../../../utils/background_patterns.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../../../utils/theme_provider.dart';
import '../../../services/mood_gratitude_service.dart';

class MoodGratitudeSetupPage extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic> metadata;
  final Function(Map<String, dynamic>) onSave;

  const MoodGratitudeSetupPage({
    Key? key,
    required this.cardId,
    required this.metadata,
    required this.onSave,
  }) : super(key: key);

  @override
  State<MoodGratitudeSetupPage> createState() => _MoodGratitudeSetupPageState();
}

class _MoodGratitudeSetupPageState extends State<MoodGratitudeSetupPage> {
  late MoodGratitudeSettings _settings;
  late TimeOfDay _selectedTime;
  bool _remindersEnabled = true;

  // Background widget with programmatically generated pattern
  Widget get backgroundWidget {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    return Container(
      color: themeProvider.isDarkMode ? Color(0xFF1E1E2E) : Colors.transparent,
      child: themeProvider.isDarkMode
          ? BackgroundPatterns.darkThemeBackground()
          : BackgroundPatterns.lightThemeBackground(),
    );
  }

  @override
  void initState() {
    super.initState();
    _settings = widget.metadata['settings'] != null
        ? MoodGratitudeSettings.fromMap(widget.metadata['settings'])
        : MoodGratitudeSettings.defaultSettings();
    _selectedTime = _settings.reminderTime;
    _remindersEnabled = _settings.remindersEnabled;
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveSettings() {
    final settings = MoodGratitudeSettings(
      remindersEnabled: _remindersEnabled,
      reminderTime: _selectedTime,
      maxGratitudeItems: 3,
      favoriteMoods: const ["Happy", "Good", "Neutral", "Sad", "Angry"],
      notificationEnabled: true,
    );

    final updatedMetadata = {
      ...widget.metadata,
      'type': 'mood_gratitude',
      'settings': settings.toMap(),
      'entries': [],
    };

    MoodGratitudeService.saveMoodGratitudeSettings(settings).then((_) {
      print('MoodGratitudeSetupPage: Settings saved to database');
    }).catchError((error) {
      print('MoodGratitudeSetupPage: Error saving settings: $error');
    });

    widget.onSave(updatedMetadata);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Stack(
      children: [
        // Background pattern
        Positioned.fill(child: backgroundWidget),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              'Configure Mood & Gratitude',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: isDarkMode 
              ? Color(0xFF282A40).withOpacity(0.7) 
              : Colors.white.withOpacity(0.7),
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminder Settings',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? Color(0xFF282A40) : Colors.white,
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: Text(
                                'Enable Daily Reminders',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                'Get notified to log your mood and gratitude',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              value: _remindersEnabled,
                              activeColor: isDarkMode ? Colors.tealAccent : Colors.teal,
                              onChanged: (bool value) {
                                setState(() {
                                  _remindersEnabled = value;
                                });
                              },
                            ),
                            ListTile(
                              title: Text(
                                'Reminder Time',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              trailing: TextButton(
                                onPressed: () => _selectTime(context),
                                child: Text(
                                  _selectedTime.format(context),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.tealAccent : Colors.teal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'About Mood & Gratitude Log',
                        style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? Color(0xFF282A40) : Colors.white,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.emoji_emotions,
                                color: isDarkMode ? Colors.tealAccent : Colors.teal,
                              ),
                              title: Text(
                                'Track your daily mood with emoji reactions',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.favorite,
                                color: isDarkMode ? Colors.tealAccent : Colors.teal,
                              ),
                              title: Text(
                                'Log up to 3 things you\'re grateful for each day',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.history,
                                color: isDarkMode ? Colors.tealAccent : Colors.teal,
                              ),
                              title: Text(
                                'View your mood history and gratitude entries',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.psychology,
                                color: isDarkMode ? Colors.tealAccent : Colors.teal,
                              ),
                              title: Text(
                                'Reflect on your emotional well-being',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF282A40) : Colors.white,
                  border: Border(top: BorderSide(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        _saveSettings();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.tealAccent.shade700 : Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}