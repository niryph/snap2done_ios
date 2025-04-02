import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/task_model.dart';
import '../services/card_service.dart';
import '../features/water_intake/models/water_intake_models.dart';
import '../features/water_intake/pages/water_intake_page.dart';
import '../features/water_intake/pages/water_intake_onboarding.dart';
import '../features/mood_gratitude/pages/mood_gratitude_setup_page.dart';
import '../features/calorie_tracker/pages/calorie_tracker_setup_page.dart';
import '../features/expense_tracker/pages/expense_tracker_setup_page.dart';
import '../features/top_priorities/pages/top_priorities_page.dart';
import '../services/auth_service.dart';
import 'package:uuid/uuid.dart';

class RecommendedCards extends StatefulWidget {
  final Function(CardModel) onCardSelected;

  const RecommendedCards({
    Key? key,
    required this.onCardSelected,
  }) : super(key: key);

  @override
  _RecommendedCardsState createState() => _RecommendedCardsState();
}

class _RecommendedCardsState extends State<RecommendedCards> {
  late ScrollController _scrollController;
  final _uuid = Uuid();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCardSelection(BuildContext context, CardModel template) async {
    print("_handleCardSelection called for template: ${template.id}");
    
    // Get the current user's ID
    final user = AuthService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create cards')),
      );
      return;
    }

    if (template.id == 'template_water') {
      // For water intake template, pass it directly to the onCardSelected handler
      // The CardStackReversed class will check if a water intake card already exists
      widget.onCardSelected(template);
      return;
    }
    
    if (template.id == 'template_priorities') {
      // Check for existing top priorities card
      final existingCards = await CardService.getCards();
      final existingTopPriorityCards = existingCards.where((card) => 
        card.metadata?['type'] == 'top_priorities').toList();

      if (existingTopPriorityCards.isNotEmpty) {
        // Open existing card
        final existingCard = existingTopPriorityCards.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopPrioritiesPage(
              cardId: existingCard.id,
              metadata: existingCard.metadata ?? {},
              isEditing: true,
              onSave: (updatedMetadata) async {
                try {
                  // Update card metadata in database first
                  await CardService.updateCardMetadata(existingCard.id, updatedMetadata);
                  
                  // Get the updated card
                  final updatedCard = await CardService.getCardById(existingCard.id);
                  if (updatedCard != null) {
                    widget.onCardSelected(updatedCard);
                  }
                } catch (e) {
                  print('Error updating top priorities metadata: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating top priorities: $e')),
                  );
                }
              },
            ),
          ),
        );
        return;
      }
      
      // If no existing card, pass to CardStackReversed to create new one
      widget.onCardSelected(template);
      return;
    }

    if (template.id == 'template_mood') {
      // For mood & gratitude template, show setup page first
      final cardData = template.toMap();
      cardData['id'] = _uuid.v4();
      cardData['user_id'] = user.id;
      
      // Update timestamps
      final now = DateTime.now();
      cardData['created_at'] = now.toIso8601String();
      cardData['updated_at'] = now.toIso8601String();
      
      final settings = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => MoodGratitudeSetupPage(
            cardId: cardData['id'],
            metadata: {},
            onSave: (metadata) async {
              // Create the card with the settings
              cardData['metadata'] = metadata;
              try {
                final newCard = await CardService.createCard(cardData);
                widget.onCardSelected(newCard);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating card: $e')),
                );
              }
            },
          ),
        ),
      );
      return;
    }
    
    if (template.id == 'template_calorie') {
      // For calorie tracker template, we'll let CardStackReversed handle it
      // since it needs to check if a card already exists and handle the setup page
      widget.onCardSelected(template);
      return;
    }
    
    if (template.id == 'template_expense') {
      print("Handling expense tracker template selection");
      // For expense tracker template, we'll pass it directly to the onCardSelected handler
      // The CardStackReversed class will handle checking for existing cards and navigation
      widget.onCardSelected(template);
      return;
    }
    
    // For other cards, create immediately
    final cardData = template.toMap();
    cardData['id'] = _uuid.v4();
    cardData['user_id'] = user.id;
    
    // Update timestamps
    final now = DateTime.now();
    cardData['created_at'] = now.toIso8601String();
    cardData['updated_at'] = now.toIso8601String();
    
    // Update tasks with new IDs and card ID
    if (cardData['tasks'] != null) {
      final List<Map<String, dynamic>> updatedTasks = [];
      for (var task in template.tasks) {
        final taskMap = task.toMap();
        taskMap['id'] = _uuid.v4();
        taskMap['card_id'] = cardData['id'];
        updatedTasks.add(taskMap);
      }
      cardData['tasks'] = updatedTasks;
    }
    
    try {
      // Create the card using CardService
      final newCard = await CardService.createCard(cardData);
      widget.onCardSelected(newCard);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating card: $e')),
      );
    }
  }

  TaskModel _createTask(String description, {
    String? id,
    String? cardId,
    String? notes,
    String priority = 'medium',
    bool isCompleted = false,
    int position = 0,
    DateTime? reminderDate,
    Map<String, dynamic>? metadata,
  }) {
    return TaskModel(
      id: id ?? const Uuid().v4(),
      cardId: cardId ?? const Uuid().v4(),
      description: description,
      notes: notes,
      priority: priority,
      isCompleted: isCompleted,
      position: position,
      reminderDate: reminderDate,
      metadata: metadata,
    );
  }

  // Pre-defined card templates
  List<CardModel> get _templates {
    final templateUserId = _uuid.v4(); // Generate a UUID for templates
    return [
      CardModel(
        id: 'template_water',
        userId: templateUserId,
        title: 'Hydration Tracker',
        description: 'Track daily water consumption',
        color: '0xFF00BCD4', // Cyan
        tags: ['Health', 'Habits'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Morning (2 glasses)', cardId: 'template_water', priority: 'high'),
          _createTask('Afternoon (3 glasses)', cardId: 'template_water', priority: 'high'),
          _createTask('Evening (3 glasses)', cardId: 'template_water', priority: 'high'),
        ],
      ),
      CardModel(
        id: 'template_priorities',
        userId: templateUserId,
        title: 'Daily Top 3 Priorities',
        description: 'Focus on your most important tasks',
        color: '0xFFE53935', // Red
        tags: ['Productivity'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Priority #1', cardId: 'template_priorities', priority: 'high'),
          _createTask('Priority #2', cardId: 'template_priorities', priority: 'high'),
          _createTask('Priority #3', cardId: 'template_priorities', priority: 'high'),
        ],
      ),
      CardModel(
        id: 'template_mood',
        userId: 'template',
        title: 'Mood & Gratitude Log',
        description: 'Track mood and practice gratitude',
        color: '0xFF9C27B0', // Purple
        tags: ['Wellness', 'Mental Health'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Morning mood check-in', cardId: 'template_mood', priority: 'high'),
          _createTask('Evening mood check-in', cardId: 'template_mood', priority: 'high'),
          _createTask('List 3 things you\'re grateful for', cardId: 'template_mood', priority: 'high'),
        ],
      ),
      CardModel(
        id: 'template_calorie',
        userId: templateUserId,
        title: 'Calorie & Nutrition Tracker',
        description: 'Track your daily food intake and macronutrients',
        color: '0xFFF9A825', // Orange
        tags: ['Health', 'Nutrition'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Log breakfast', cardId: 'template_calorie', priority: 'high'),
          _createTask('Log lunch', cardId: 'template_calorie', priority: 'high'),
          _createTask('Log dinner', cardId: 'template_calorie', priority: 'high'),
        ],
      ),
      CardModel(
        id: 'template_expense',
        userId: templateUserId,
        title: 'Daily Expense Tracker',
        description: 'Track your daily spending and budget',
        color: '0xFF2E7D32', // Dark Green
        tags: ['Finance', 'Budget'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Log essential expenses', cardId: 'template_expense', priority: 'high'),
          _createTask('Log discretionary spending', cardId: 'template_expense', priority: 'medium'),
          _createTask('Review daily spending', cardId: 'template_expense', priority: 'low'),
        ],
      ),
      CardModel(
        id: 'template_timeblock',
        userId: 'template',
        title: 'Time-Blocking Schedule',
        description: 'Plan your day in time blocks',
        color: '0xFF3F51B5', // Indigo
        tags: ['Productivity', 'Planning'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Morning block (8-11 AM)', cardId: 'template_timeblock', priority: 'high'),
          _createTask('Afternoon block (1-4 PM)', cardId: 'template_timeblock', priority: 'high'),
          _createTask('Evening block (4-6 PM)', cardId: 'template_timeblock', priority: 'medium'),
        ],
      ),
      CardModel(
        id: 'template_sleep',
        userId: 'template',
        title: 'Sleep Schedule Monitor',
        description: 'Track sleep patterns',
        color: '0xFF1E88E5', // Blue
        tags: ['Health', 'Wellness'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Record bedtime', cardId: 'template_sleep', priority: 'high'),
          _createTask('Record wake time', cardId: 'template_sleep', priority: 'high'),
          _createTask('Rate sleep quality (1-10)', cardId: 'template_sleep', priority: 'medium'),
        ],
      ),
      CardModel(
        id: 'template_workout',
        userId: 'template',
        title: 'Workout/Fitness Routine',
        description: 'Track your fitness activities',
        color: '0xFFE91E63', // Pink
        tags: ['Health', 'Fitness'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Warm-up (10 mins)', cardId: 'template_workout', priority: 'high'),
          _createTask('Main workout', cardId: 'template_workout', priority: 'high'),
          _createTask('Cool-down (10 mins)', cardId: 'template_workout', priority: 'medium'),
        ],
      ),
      CardModel(
        id: 'template_chores',
        userId: 'template',
        title: 'Household Chores Checklist',
        description: 'Track daily household tasks',
        color: '0xFF795548', // Brown
        tags: ['Home'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Morning chores', cardId: 'template_chores', priority: 'high'),
          _createTask('Evening chores', cardId: 'template_chores', priority: 'high'),
          _createTask('Weekly tasks', cardId: 'template_chores', priority: 'medium'),
        ],
      ),
      CardModel(
        id: 'template_evening',
        userId: 'template',
        title: 'Evening Wind-Down Routine',
        description: 'Prepare for restful sleep',
        color: '0xFF607D8B', // Blue Grey
        tags: ['Wellness', 'Habits'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          _createTask('Digital sunset (1hr before bed)', cardId: 'template_evening', priority: 'high'),
          _createTask('Relaxation routine', cardId: 'template_evening', priority: 'high'),
          _createTask('Prepare for tomorrow', cardId: 'template_evening', priority: 'medium'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {

    void _scrollLeft() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.offset - 150,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }

    void _scrollRight() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.offset + 150,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }

    return SizedBox(
      height: 70,
      width: MediaQuery.of(context).size.width,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (_scrollController.hasClients) {
            _scrollController.position.moveTo(
              _scrollController.offset - details.delta.dx,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
              decelerationRate: ScrollDecelerationRate.normal
            ),
            clipBehavior: Clip.none,
            child: Semantics(
              container: true,
              label: 'Recommended cards list',
              child: Row(
                key: const Key('recommended_cards_list'),
                children: _templates.map((template) {
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      button: true,
                      label: 'Select ${template.title} template',
                      child: GestureDetector(
                        onTap: () => _handleCardSelection(context, template),
                        child: Container(
                          decoration: BoxDecoration(
                            color: template.getColor().withOpacity(1.0),
                            borderRadius: BorderRadius.circular(12),
                            image: const DecorationImage(
                              image: AssetImage('assets/images/vawes.png'),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  template.title,
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: _getIconForCard(template.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getIconForCard(String templateId) {
    switch (templateId) {
      case 'template_water':
        return const Icon(Icons.water_drop, color: Colors.white, size: 20);
      case 'template_priorities':
        return const Icon(Icons.star, color: Colors.white, size: 20);
      case 'template_mood':
        return const Icon(Icons.mood, color: Colors.white, size: 20);
      case 'template_calorie':
        return const Icon(Icons.restaurant, color: Colors.white, size: 20);
      case 'template_expense':
        return const Icon(Icons.attach_money, color: Colors.white, size: 20);
      case 'template_timeblock':
        return const Icon(Icons.schedule, color: Colors.white, size: 20);
      case 'template_sleep':
        return const Icon(Icons.bedtime, color: Colors.white, size: 20);
      case 'template_workout':
        return const Icon(Icons.fitness_center, color: Colors.white, size: 20);
      case 'template_chores':
        return const Icon(Icons.home, color: Colors.white, size: 20);
      case 'template_evening':
        return const Icon(Icons.nights_stay, color: Colors.white, size: 20);
      default:
        return const Icon(Icons.check_circle, color: Colors.white, size: 20);
    }
  }
}