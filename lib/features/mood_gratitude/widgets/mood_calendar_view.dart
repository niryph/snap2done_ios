import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/mood_gratitude_models.dart';

class MoodCalendarView extends StatefulWidget {
  final List<MoodEntry> entries;
  final Function(DateTime) onDaySelected;
  final DateTime? selectedDay;

  const MoodCalendarView({
    Key? key,
    required this.entries,
    required this.onDaySelected,
    this.selectedDay,
  }) : super(key: key);

  @override
  State<MoodCalendarView> createState() => _MoodCalendarViewState();
}

class _MoodCalendarViewState extends State<MoodCalendarView> {
  late DateTime _focusedDay;
  late DateTime? _selectedDay;
  late Map<DateTime, List<MoodEntry>> _entriesMap;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.selectedDay ?? DateTime.now();
    _selectedDay = widget.selectedDay;
    _updateEntriesMap();
  }

  @override
  void didUpdateWidget(MoodCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries != oldWidget.entries) {
      _updateEntriesMap();
    }
    if (widget.selectedDay != oldWidget.selectedDay) {
      _selectedDay = widget.selectedDay;
    }
  }

  void _updateEntriesMap() {
    _entriesMap = {};
    for (var entry in widget.entries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      _entriesMap[date] = _entriesMap[date] ?? [];
      _entriesMap[date]!.add(entry);
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: TableCalendar<MoodEntry>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.now(),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          widget.onDaySelected(selectedDay);
        },
        eventLoader: (day) {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          return _entriesMap[normalizedDay] ?? [];
        },
        calendarStyle: const CalendarStyle(
          markersMaxCount: 1,
          markerDecoration: BoxDecoration(
            color: Colors.transparent,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return null;
            final entry = events.first as MoodEntry;
            return Positioned(
              right: 1,
              bottom: 1,
              child: Text(
                _getMoodEmoji(entry.mood),
                style: const TextStyle(fontSize: 16),
              ),
            );
          },
        ),
      ),
    );
  }
} 