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
import '../features/top_priorities/models/top_priorities_models.dart';
import '../services/auth_service.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _handleTemplateSelection(String templateId) async {
    if (templateId == 'template_priorities') {
      // Check for existing top priority cards
      final existingCards = await CardService.getCards();
      final existingTopPriorityCards = existingCards.where((card) => 
        card.metadata != null && 
        card.metadata!['type'] == 'top_priorities' &&
        card.metadata!['priorities'] != null).toList();

      if (existingTopPriorityCards.isNotEmpty) {
        // Open existing card
        final existingCard = existingTopPriorityCards.first;
        if (!mounted) return;
        
        // First, notify the main screen about the selected card
        widget.onCardSelected(existingCard);
        
        // Then navigate to the edit page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopPrioritiesPage(
              cardId: existingCard.id,
              metadata: existingCard.metadata ?? {},
              isEditing: true,
              onSave: (updatedMetadata) async {
                await CardService.updateCardMetadata(existingCard.id, updatedMetadata);
                // Force a refresh of all cards to ensure UI updates
                await CardService.getCards();
                return existingCard.id;
              },
            ),
          ),
        );
        return; // Exit early to prevent card creation
      }

      // Only proceed with creation if no existing card was found
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to create cards')),
        );
        return;
      }

      if (!mounted) return;

      // Navigate to TopPrioritiesPage in creation mode
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TopPrioritiesPage(
            isEditing: false,
            onSave: (metadata) async {
              try {
                // Create the card with initial metadata
                final cardData = {
                  'title': 'Daily Top 3 Priorities',
                  'type': 'top_priorities',
                  'metadata': metadata,
                  'description': 'Focus on your most important tasks',
                  'color': '0xFFE53935',
                  'tags': ['Productivity'],
                  'user_id': userId,
                  'is_archived': false,
                  'is_favorited': false,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                };
                
                print("DEBUG: Creating top priorities card with data: $cardData");
                print("DEBUG: Metadata structure: ${metadata['priorities']?.keys ?? 'No priorities found'}");
                
                // Ensure we set notifyListeners to true for the card creation
                final newCard = await CardService.createCard(cardData, notifyListeners: true);
                print("DEBUG: Top priorities card created with ID: ${newCard.id}");
                print("DEBUG: Metadata in created card: ${newCard.metadata}");
                
                // Force reload all cards to ensure the UI updates
                await CardService.getCards();
                
                // Notify the main page about the new card
                widget.onCardSelected(newCard);
                
                return newCard.id;
              } catch (e) {
                print('Error creating top priorities card: $e');
                throw e; // Re-throw to be handled by the page
              }
            },
          ),
        ),
      );
      return;
    }

    if (templateId == 'template_water') {
      // For water intake template, pass it directly to the onCardSelected handler
      // The CardStackReversed class will check if a water intake card already exists
      widget.onCardSelected(CardModel(
        id: templateId,
        userId: _uuid.v4(),
        title: 'Hydration Tracker',
        description: 'Track daily water consumption',
        color: '0xFF00BCD4', // Cyan
        tags: ['Health', 'Habits'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_water',
            description: 'Morning (2 glasses)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_water',
            description: 'Afternoon (3 glasses)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_water',
            description: 'Evening (3 glasses)',
            priority: 'high',
          ),
        ],
      ));
      return;
    }
    
    if (templateId == 'template_mood') {
      // For mood & gratitude template, show setup page first
      final cardData = CardModel(
        id: templateId,
        userId: 'template',
        title: 'Mood & Gratitude Log',
        description: 'Track mood and practice gratitude',
        color: '0xFF9C27B0', // Purple
        tags: ['Wellness', 'Mental Health'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_mood',
            description: 'Morning mood check-in',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_mood',
            description: 'Evening mood check-in',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_mood',
            description: 'List 3 things you\'re grateful for',
            priority: 'high',
          ),
        ],
      ).toMap();
      cardData['id'] = _uuid.v4();
      cardData['user_id'] = AuthService.currentUser?.id;
      
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
    
    if (templateId == 'template_calorie') {
      // For calorie tracker template, we'll let CardStackReversed handle it
      // since it needs to check if a card already exists and handle the setup page
      widget.onCardSelected(CardModel(
        id: templateId,
        userId: _uuid.v4(),
        title: 'Calorie & Nutrition Tracker',
        description: 'Track your daily food intake and macronutrients',
        color: '0xFFF9A825', // Orange
        tags: ['Health', 'Nutrition'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_calorie',
            description: 'Log breakfast',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_calorie',
            description: 'Log lunch',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_calorie',
            description: 'Log dinner',
            priority: 'high',
          ),
        ],
      ));
      return;
    }
    
    if (templateId == 'template_expense') {
      print("Handling expense tracker template selection");
      // For expense tracker template, we'll pass it directly to the onCardSelected handler
      // The CardStackReversed class will handle checking for existing cards and navigation
      widget.onCardSelected(CardModel(
        id: templateId,
        userId: _uuid.v4(),
        title: 'Daily Expense Tracker',
        description: 'Track your daily spending and budget',
        color: '0xFF2E7D32', // Dark Green
        tags: ['Finance', 'Budget'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tasks: [
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_expense',
            description: 'Log essential expenses',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_expense',
            description: 'Log discretionary spending',
            priority: 'medium',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_expense',
            description: 'Review daily spending',
            priority: 'low',
          ),
        ],
      ));
      return;
    }
    
    // For other cards, create immediately
    final cardData = CardModel(
      id: templateId,
      userId: _uuid.v4(),
      title: 'New Card',
      description: 'Description for new card',
      color: '0xFF000000', // Default color
      tags: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tasks: [
        TaskModel(
          id: _uuid.v4(),
          cardId: templateId,
          description: 'New task',
          priority: 'medium',
        ),
      ],
    ).toMap();
    
    // Update timestamps
    final now = DateTime.now();
    cardData['created_at'] = now.toIso8601String();
    cardData['updated_at'] = now.toIso8601String();
    
    // Update tasks with new IDs and card ID
    if (cardData['tasks'] != null) {
      final List<Map<String, dynamic>> updatedTasks = [];
      for (var task in cardData['tasks'] as List) {
        final taskMap = task as Map<String, dynamic>;
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_water',
            description: 'Morning (2 glasses)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_water',
            description: 'Afternoon (3 glasses)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_water',
            description: 'Evening (3 glasses)',
            priority: 'high',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_priorities',
            description: 'Priority #1',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_priorities',
            description: 'Priority #2',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_priorities',
            description: 'Priority #3',
            priority: 'high',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_mood',
            description: 'Morning mood check-in',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_mood',
            description: 'Evening mood check-in',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_mood',
            description: 'List 3 things you\'re grateful for',
            priority: 'high',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_calorie',
            description: 'Log breakfast',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_calorie',
            description: 'Log lunch',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_calorie',
            description: 'Log dinner',
            priority: 'high',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_expense',
            description: 'Log essential expenses',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_expense',
            description: 'Log discretionary spending',
            priority: 'medium',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_expense',
            description: 'Review daily spending',
            priority: 'low',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_timeblock',
            description: 'Morning block (8-11 AM)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_timeblock',
            description: 'Afternoon block (1-4 PM)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_timeblock',
            description: 'Evening block (4-6 PM)',
            priority: 'medium',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_sleep',
            description: 'Record bedtime',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_sleep',
            description: 'Record wake time',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_sleep',
            description: 'Rate sleep quality (1-10)',
            priority: 'medium',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_workout',
            description: 'Warm-up (10 mins)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_workout',
            description: 'Main workout',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_workout',
            description: 'Cool-down (10 mins)',
            priority: 'medium',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_chores',
            description: 'Morning chores',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_chores',
            description: 'Evening chores',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_chores',
            description: 'Weekly tasks',
            priority: 'medium',
          ),
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
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_evening',
            description: 'Digital sunset (1hr before bed)',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_evening',
            description: 'Relaxation routine',
            priority: 'high',
          ),
          TaskModel(
            id: _uuid.v4(),
            cardId: 'template_evening',
            description: 'Prepare for tomorrow',
            priority: 'medium',
          ),
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
                        onTap: () => _handleTemplateSelection(template.id),
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