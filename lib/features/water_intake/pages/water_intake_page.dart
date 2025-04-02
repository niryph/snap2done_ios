import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:math' as math;
import '../models/water_intake_models.dart';
import '../widgets/water_gauge.dart';
import '../utils/unit_converter.dart';
import 'water_intake_onboarding.dart';
import 'water_intake_edit_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

// Add WaterBubblesPainter class
class WaterBubblesPainter extends CustomPainter {
  final Color color;
  final double opacity;

  WaterBubblesPainter({
    this.color = const Color.fromRGBO(200, 220, 255, 1.0),
    this.opacity = 0.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    final bubbles = 25;

    for (var i = 0; i < bubbles; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 30 + 10;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(WaterBubblesPainter oldDelegate) => false;
}

// Add RoundedEndProgressIndicatorPainter class
class RoundedEndProgressIndicatorPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color valueColor;
  final double strokeWidth;

  RoundedEndProgressIndicatorPainter({
    required this.progress,
    required this.backgroundColor,
    required this.valueColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress;

    // Draw background arc
    paint.color = backgroundColor;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, math.pi * 2, false, paint);

    // Draw progress arc
    paint.color = valueColor;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(RoundedEndProgressIndicatorPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class WaterIntakePage extends StatefulWidget {
  final String cardId;
  final Map<String, dynamic>? metadata;
  final Function(Map<String, dynamic>)? onMetadataChanged;

  const WaterIntakePage({
    Key? key,
    required this.cardId,
    this.metadata,
    this.onMetadataChanged,
  }) : super(key: key);

  @override
  State<WaterIntakePage> createState() => _WaterIntakePageState();
}

class _WaterIntakePageState extends State<WaterIntakePage> with TickerProviderStateMixin {
  late String _userId;
  WaterIntakeSettings? _settings;
  List<WaterEntry> _currentDayEntries = [];
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _customAmountController = TextEditingController();
  Map<String, dynamic>? _metadata;
  
  // Quick add options will be initialized based on unit type
  late List<Map<String, dynamic>> _quickAddOptions;
  bool _showGraph = false;
  String _graphPeriod = 'week'; // 'week' or 'month'
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  Map<String, List<WaterEntry>> _historicalEntries = {};

  @override
  void initState() {
    super.initState();
    _metadata = widget.metadata;
    _settings = _metadata != null && _metadata!['settings'] != null 
        ? WaterIntakeSettings.fromJson(_metadata!['settings'])
        : WaterIntakeSettings(
            dailyGoal: 2000,
            unitType: UnitType.milliliter,
            remindersEnabled: false,
            reminderIntervalHours: 2,
          );
    _userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _loadEntriesForSelectedDate();
    _initializeQuickAddOptions();
    
    // Initialize flip animation controller
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      setState(() {
        _userId = userId;
      });
    }
  }

  Future<void> _loadEntriesForSelectedDate() async {
    if (!mounted) return;

    // Create start and end of day in local time, then convert to UTC for database query
    final localStartOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final localEndOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23, 59, 59, 999,
    );

    // Convert to UTC for database query
    final utcStartOfDay = localStartOfDay.toUtc();
    final utcEndOfDay = localEndOfDay.toUtc();

    print('Loading entries for date: ${_selectedDate.toString()}');
    print('UTC query range: ${utcStartOfDay.toIso8601String()} to ${utcEndOfDay.toIso8601String()}');

    try {
      final data = await Supabase.instance.client
          .from('hydration_entries')
          .select()
          .eq('user_id', _userId)
          .gte('timestamp', utcStartOfDay.toIso8601String())
          .lte('timestamp', utcEndOfDay.toIso8601String())
          .order('timestamp');

      if (!mounted) return;

      if (data != null) {
        final entries = (data as List<dynamic>).map((entry) {
          final waterEntry = WaterEntry.fromJson(entry);
          print('Found entry: ${waterEntry.amount}ml at ${waterEntry.timestamp.toLocal()}');
          return waterEntry;
        }).toList();

        print('Loaded ${entries.length} entries for ${_selectedDate.toString()}');

        setState(() {
          _currentDayEntries = entries;
        });
      } else {
        print('No data returned from Supabase for ${_selectedDate.toString()}');
        setState(() {
          _currentDayEntries = [];
        });
      }
    } catch (error) {
      print('Error loading water entries: $error');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load water entries. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _currentDayEntries = [];
      });
    }
  }

  Future<void> _addWater(double amount) async {
    try {
      final entry = WaterEntry(
        amount: amount,
        timestamp: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
            .add(DateTime.now().difference(DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ))),
      );

      await Supabase.instance.client
          .from('hydration_entries')
          .insert({
            'user_id': _userId,
            'amount': entry.amount,
            'timestamp': entry.timestamp.toUtc().toIso8601String(),
          });

      setState(() {
        _currentDayEntries.add(entry);
        // Sort entries by timestamp
        _currentDayEntries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      
    } catch (error) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add water entry. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error adding water entry: $error');
    }
  }

  String get unitLabel => _settings?.unitType == UnitType.milliliter ? 'ml' : 'fl oz';
  UnitType get _unitType => _settings?.unitType ?? UnitType.fluidOunce;

  void _initializeQuickAddOptions() {
    if (_settings == null) return;
    
    if (_settings!.unitType == UnitType.fluidOunce) {
      _quickAddOptions = [
        {'amount': 8.0, 'label': '8 fl oz', 'icon': Icons.local_cafe_outlined},
        {'amount': 16.0, 'label': '16 fl oz', 'icon': Icons.water_drop_outlined},
        {'amount': 20.0, 'label': '20 fl oz', 'icon': Icons.water_drop_outlined},
        {'amount': 32.0, 'label': '32 fl oz', 'icon': Icons.water_drop_outlined},
      ];
    } else {
      _quickAddOptions = [
        {'amount': 240, 'label': '240 ml', 'icon': Icons.local_cafe_outlined},
        {'amount': 470, 'label': '470 ml', 'icon': Icons.water_drop_outlined},
        {'amount': 590, 'label': '590 ml', 'icon': Icons.water_drop_outlined},
        {'amount': 950, 'label': '950 ml', 'icon': Icons.water_drop_outlined},
      ];
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  double get _totalIntake {
    // Sum up all entries (stored in ml)
    final totalMl = _currentDayEntries.fold(0.0, (sum, entry) => sum + entry.amount);
    
    // Convert to the selected unit type if needed
    return _settings?.unitType == UnitType.fluidOunce 
        ? UnitConverter.mlToFlOz(totalMl) 
        : totalMl;
  }

  double get _progressPercentage {
    final dailyGoal = _settings?.dailyGoal ?? 2000.0; // Default to 2000ml if null
    return (_totalIntake / dailyGoal).clamp(0.0, 1.0);
  }

  String get _formattedTotalIntake {
    return UnitConverter.formatAmount(_totalIntake, _settings?.unitType ?? UnitType.milliliter);
  }

  String get _formattedGoal {
    return UnitConverter.formatAmount(_settings?.dailyGoal ?? 2000.0, _settings?.unitType ?? UnitType.milliliter);
  }

  String get _formattedRemainingAmount {
    final dailyGoal = _settings?.dailyGoal ?? 2000.0;
    var remainingAmount = dailyGoal - _totalIntake;
    if (remainingAmount < 0) {
      remainingAmount = 0;
    }
    return UnitConverter.formatAmount(remainingAmount, _settings?.unitType ?? UnitType.milliliter);
  }

  void _navigateDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (!newDate.isAfter(DateTime.now())) {
      setState(() {
        _selectedDate = newDate;
        _loadEntriesForSelectedDate();
      });
    }
  }

  void _handleCustomAmount() {
    final text = _customAmountController.text;
    if (text.isEmpty) return;

    final amount = double.tryParse(text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number'),
        ),
      );
      return;
    }

    _addWater(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_metadata == null) {
      return WaterIntakeOnboarding(
        onComplete: (metadata) {
          setState(() {
            _metadata = metadata;
            _loadEntriesForSelectedDate();
          });
        },
      );
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true, // Center align the title
        title: const Text('Hydration Tracker'),
        // Remove backgroundColor to use system theme
        actions: [
          IconButton(
            icon: Icon(_showGraph ? Icons.water_drop : Icons.bar_chart),
            onPressed: _toggleView,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WaterIntakeEditPage(
                    cardId: widget.cardId,
                    onSave: (dynamic updatedSettings) {
                      final settings = updatedSettings is Map<String, dynamic>
                          ? WaterIntakeSettings.fromJson(updatedSettings)
                          : updatedSettings as WaterIntakeSettings;
                      
                      setState(() {
                        _settings = settings;
                        _initializeQuickAddOptions();
                        _loadEntriesForSelectedDate();
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Navigation Bar or Period Selection
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _showGraph 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPeriodButton('Week', 'week'),
                              Container(
                                width: 1,
                                height: 24,
                                color: Theme.of(context).primaryColor.withOpacity(0.2),
                              ),
                              _buildPeriodButton('Month', 'month'),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left),
                          onPressed: () => _navigateDate(-1),
                        ),
                        Text(
                          _formatDate(_selectedDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: _selectedDate.isBefore(DateTime.now()) 
                            ? () => _navigateDate(1)
                            : null,
                        ),
                      ],
                    ),
              ),
              
              // Main Card with Water Progress and Stats
              Container(
                width: double.infinity,
                padding: _showGraph 
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                child: Column(
                  children: [
                    // Water Progress Circle or Graph
                    Container(
                      width: _showGraph ? MediaQuery.of(context).size.width : 200,
                      height: _showGraph ? 300 : 200,
                      padding: _showGraph ? EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.zero,
                      child: AnimatedBuilder(
                        animation: _flipAnimation,
                        builder: (context, child) {
                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_flipAnimation.value * math.pi),
                            alignment: Alignment.center,
                            child: _flipAnimation.value < 0.5
                                ? !_showGraph ? _buildGaugeWidget() : Container()
                                : Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: _showGraph ? _buildGraphWidget() : Container(),
                                  ),
                          );
                        },
                      ),
                    ),

                    if (!_showGraph) ...[
                      const SizedBox(height: 16),
                      // Daily Goal and Current Progress
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily Goal',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formattedGoal,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Remaining',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formattedRemainingAmount,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Quick Add Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickAddOptions.map((option) {
                  return Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          final amount = option['amount'] as num;
                          final convertedAmount = _unitType == UnitType.fluidOunce
                              ? UnitConverter.flOzToMl(amount.toDouble())
                              : amount.toDouble();
                          _addWater(convertedAmount);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              option['icon'] as IconData,
                              color: Theme.of(context).primaryColor,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option['label'],
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Custom input field
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customAmountController,
                        decoration: InputDecoration(
                          hintText: 'Custom ${_unitType == UnitType.fluidOunce ? 'fl oz' : 'ml'}',
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _handleCustomAmount();
                        _customAmountController.clear();
                      },
                      icon: Icon(
                        Icons.add,
                        color: Theme.of(context).primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Today's Entries Section
              Text(
                'Today\'s Entries',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Entries list
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _currentDayEntries.length,
                itemBuilder: (context, index) {
                  final entry = _currentDayEntries[index];
                  final displayAmount = _unitType == UnitType.fluidOunce
                      ? UnitConverter.mlToFlOz(entry.amount)
                      : entry.amount;
                  
                  return _buildSimpleEntryListItem(entry, displayAmount);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSimpleEntryListItem(WaterEntry entry, double displayAmount) {
    final hour = entry.timestamp.hour > 12 ? entry.timestamp.hour - 12 : entry.timestamp.hour;
    final amPm = entry.timestamp.hour >= 12 ? 'PM' : 'AM';
    final formattedTime = '${hour == 0 ? 12 : hour}:${entry.timestamp.minute.toString().padLeft(2, '0')} $amPm';
    
    return Slidable(
      key: ValueKey(entry.timestamp),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        children: [
          CustomSlidableAction(
            onPressed: (context) async {
              try {
                // Delete entry from the database
                await Supabase.instance.client
                    .from('hydration_entries')
                    .delete()
                    .match({
                      'user_id': _userId,
                      'timestamp': entry.timestamp.toIso8601String(),
                      'amount': entry.amount,
                    });

                setState(() {
                  _currentDayEntries.remove(entry);
                });
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete entry. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: Center(
              child: Icon(Icons.delete),
            ),
          ),
          CustomSlidableAction(
            onPressed: (context) {
              _showEditDialog(context, entry);
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: Center(
              child: Icon(Icons.edit),
            ),
          ),
        ],
      ),
      child: ListTile(
        minVerticalPadding: 0, // Remove vertical padding
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        visualDensity: VisualDensity(vertical: -4), // Reduce vertical density
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, // Reduced size
              height: 32, // Reduced size
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.water_drop,
                color: Colors.blue.shade900,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${displayAmount.toInt()} $unitLabel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
          ],
        ),
        trailing: Text(
          formattedTime,
          style: TextStyle(
            fontSize: 14,
            color: Colors.blue.shade900,
          ),
        ),
      ),
    );
  }

  void _initializeUnitType() {
    // Update settings with the latest metadata
    _initializeSettings();
  }

  void _updateUnitTypeDisplay() {
    setState(() {
      // Update the settings based on the current metadata
      _initializeSettings();
      // Reinitialize quick add options based on the new unit type
      _initializeQuickAddOptions();
    });
  }

  String _formatDate(DateTime date) {
    final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final day = date.day;
    
    return '$weekday, $month $day';
  }

  void _showEditDialog(BuildContext context, WaterEntry entry) {
    final TextEditingController editController = TextEditingController(
      text: (_unitType == UnitType.fluidOunce 
          ? UnitConverter.mlToFlOz(entry.amount)
          : entry.amount).toInt().toString()
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: unitLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () async {
                final newAmount = double.tryParse(editController.text);
                if (newAmount != null) {
                  try {
                    // Convert the amount if needed
                    final convertedAmount = _unitType == UnitType.fluidOunce
                        ? UnitConverter.flOzToMl(newAmount)
                        : newAmount;
                    
                    // Update the entry in the database
                    await Supabase.instance.client
                        .from('hydration_entries')
                        .update({
                          'amount': convertedAmount,
                        })
                        .match({
                          'user_id': _userId,
                          'timestamp': entry.timestamp.toIso8601String(),
                        });

                    setState(() {
                      final index = _currentDayEntries.indexOf(entry);
                      if (index != -1) {
                        _currentDayEntries[index] = WaterEntry(
                          amount: convertedAmount,
                          timestamp: entry.timestamp,
                        );
                      }
                    });
                    
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update entry. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('UPDATE'),
            ),
          ],
        );
      },
    );
  }

  void _initializeSettings() async {
    try {
      final data = await Supabase.instance.client
          .from('water_intake_settings')
          .select()
          .eq('user_id', _userId)
          .single();

      if (data != null) {
        setState(() {
          _settings = WaterIntakeSettings.fromJson(data);
          _initializeQuickAddOptions();
        });
      } else {
        // Create default settings if none exist
        final defaultSettings = WaterIntakeSettings(
          dailyGoal: 2000.0,
          unitType: UnitType.milliliter,
        );

        await Supabase.instance.client
            .from('water_intake_settings')
            .insert({
              'user_id': _userId,
              ...defaultSettings.toJson(),
            });

        setState(() {
          _settings = defaultSettings;
          _initializeQuickAddOptions();
        });
      }
    } catch (error) {
      print('Error initializing settings: $error');
      // Set default settings in case of error
      setState(() {
        _settings = WaterIntakeSettings(
          dailyGoal: 2000.0,
          unitType: UnitType.milliliter,
        );
        _initializeQuickAddOptions();
      });
    }
  }

  Future<void> _loadHistoricalData() async {
    print('Loading historical data...');
    final now = DateTime.now();
    final startDate = _graphPeriod == 'week' 
        ? now.subtract(Duration(days: 7))
        : now.subtract(Duration(days: 30));

    try {
      final data = await Supabase.instance.client
          .from('hydration_entries')
          .select('*')
          .eq('user_id', _userId)
          .gte('timestamp', startDate.toIso8601String())
          .lte('timestamp', now.toIso8601String())
          .order('timestamp');

      if (data != null) {
        final entries = (data as List<dynamic>)
            .map((entry) => WaterEntry.fromJson(entry))
            .toList();

        print('Loaded ${entries.length} entries');

        // Group entries by date
        _historicalEntries = {};
        for (var entry in entries) {
          final dateKey = _dateToKey(entry.timestamp);
          _historicalEntries[dateKey] = _historicalEntries[dateKey] ?? [];
          _historicalEntries[dateKey]!.add(entry);
        }
        print('Grouped entries by ${_historicalEntries.length} dates');
        setState(() {});
      } else {
        print('No data returned from Supabase');
      }
    } catch (error) {
      print('Error loading historical data: $error');
    }
  }

  void _toggleView() {
    if (_showGraph) {
      _flipController.reverse();
    } else {
      _loadHistoricalData();
      _flipController.forward();
    }
    setState(() {
      _showGraph = !_showGraph;
    });
  }

  Widget _buildGaugeWidget() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: RoundedEndProgressIndicatorPainter(
            progress: _progressPercentage,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
            valueColor: Theme.of(context).primaryColor,
            strokeWidth: 15,
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formattedTotalIntake.split(' ')[0],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _unitType == UnitType.fluidOunce ? 'fl oz' : 'ml',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGraphWidget() {
    if (_historicalEntries.isEmpty) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    final List<FlSpot> spots = [];
    final now = DateTime.now();
    final startDate = _graphPeriod == 'week'
        ? now.subtract(Duration(days: 7))
        : now.subtract(Duration(days: 30));

    // Generate spots for each day
    for (int i = 0; i <= (_graphPeriod == 'week' ? 6 : 29); i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = _dateToKey(date);
      final entries = _historicalEntries[dateKey] ?? [];
      
      double totalAmount = 0;
      for (var entry in entries) {
        totalAmount += _unitType == UnitType.fluidOunce
            ? UnitConverter.mlToFlOz(entry.amount)
            : entry.amount;
      }
      
      spots.add(FlSpot(i.toDouble(), totalAmount.abs()));
    }

    // Calculate min and max Y values
    double maxY = spots.fold(0.0, (max, spot) => math.max(max, spot.y));
    maxY = math.max(maxY, _settings?.dailyGoal ?? 2000);
    maxY = maxY * 1.2; // Add 20% padding

    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600]!;

    return Container(
      padding: EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          clipData: FlClipData.all(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              preventCurveOverShooting: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: primaryColor,
                    strokeWidth: 2,
                    strokeColor: Theme.of(context).cardColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: primaryColor.withOpacity(0.2),
                cutOffY: 0,
                applyCutOffY: true,
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Theme.of(context).cardColor,
              tooltipRoundedRadius: 8,
              tooltipMargin: 8,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final date = startDate.add(Duration(days: touchedSpot.x.toInt()));
                  return LineTooltipItem(
                    '${date.day}/${date.month}\n',
                    TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: '${touchedSpot.y.toInt()} ${_unitType == UnitType.fluidOunce ? 'fl oz' : 'ml'}',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateInterval(),
            checkToShowHorizontalLine: (value) => value >= 0,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: textColor.withOpacity(0.2),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _calculateInterval(),
                getTitlesWidget: (value, meta) {
                  if (value <= 0) return Container();
                  final interval = _calculateInterval();
                  if (value % interval != 0 || value > (maxY - interval)) return Container();
                  
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _graphPeriod == 'week' ? 1 : 5,
                getTitlesWidget: (value, meta) {
                  final date = startDate.add(Duration(days: value.toInt()));
                  return Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(
                color: textColor.withOpacity(0.2),
                width: 1,
              ),
              left: BorderSide(
                color: textColor.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _graphPeriod == period;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_graphPeriod != period) {
            setState(() {
              _graphPeriod = period;
              _loadHistoricalData();
            });
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  double _calculateInterval() {
    if (_historicalEntries.isEmpty) return 100;
    
    double maxValue = 0;
    _historicalEntries.values.forEach((entries) {
      double dailyTotal = 0;
      for (var entry in entries) {
        dailyTotal += _unitType == UnitType.fluidOunce
            ? UnitConverter.mlToFlOz(entry.amount)
            : entry.amount;
      }
      maxValue = math.max(maxValue, dailyTotal);
    });
    
    // Calculate a nice interval based on the max value
    final rawInterval = maxValue / 5;
    final magnitude = math.pow(10, (math.log(rawInterval) / math.ln10).floor());
    final normalized = rawInterval / magnitude;
    
    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = 1;
    } else if (normalized < 3) {
      niceInterval = 2;
    } else if (normalized < 7) {
      niceInterval = 5;
    } else {
      niceInterval = 10;
    }
    
    return (niceInterval * magnitude).roundToDouble();
  }

  // Add the missing _dateToKey method
  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}