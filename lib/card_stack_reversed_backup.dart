import 'package:flutter/material.dart';
import 'dart:math' show max;
import 'dart:ui';
import 'image_capture_page.dart'; // Import the ImageCapturePage
import 'edit_card_page.dart'; // Import the EditCardPage
import 'services/card_service.dart'; // Import the CardService
import 'pages/review_todo_list_page.dart'; // Import the ReviewTodoListPage
import 'models/card_model.dart'; // Import the CardModel
import 'models/task_model.dart'; // Import the TaskModel
import 'pages/settings_page.dart'; // Import the SettingsPage
import 'package:provider/provider.dart'; // Import Provider
import 'utils/theme_provider.dart'; // Import ThemeProvider
// Import theme color classes
import 'utils/theme_provider.dart' show LightThemeColors, DarkThemeColors;
import 'utils/background_patterns.dart'; // Import BackgroundPatterns
import 'services/notification_service.dart'; // Import the NotificationService
import 'widgets/recommended_cards.dart'; // Import the RecommendedCards widget
import 'features/water_intake/widgets/water_intake_card.dart';
import 'features/water_intake/models/water_intake_models.dart';
import 'features/water_intake/pages/water_intake_onboarding.dart'; // Import WaterIntakeOnboarding
import 'features/water_intake/pages/water_intake_edit_page.dart'; // Import WaterIntakeEditPage
import 'features/top_priorities/widgets/top_priorities_card_content.dart'; // Import TopPrioritiesCardContent
import 'features/top_priorities/pages/top_priorities_page.dart'; // Import TopPrioritiesPage
import 'features/top_priorities/models/top_priorities_models.dart'; // Import TopPrioritiesModel
import 'features/calorie_tracker/widgets/calorie_tracker_card.dart'; // Import CalorieTrackerCard
import 'features/calorie_tracker/widgets/calorie_tracker_card_content.dart'; // Import CalorieTrackerCardContent
import 'features/calorie_tracker/pages/calorie_tracker_setup_page.dart'; // Import CalorieTrackerSetupPage
import 'package:uuid/uuid.dart'; // Import UUID for generating unique IDs
import 'services/auth_service.dart'; // Import the AuthService
import 'features/water_intake/pages/water_intake_page.dart';
import 'features/calorie_tracker/pages/calorie_tracker_page.dart';
import 'features/expense_tracker/pages/expense_tracker_page.dart';
import 'features/expense_tracker/pages/expense_tracker_setup_page.dart';
import 'features/expense_tracker/widgets/daily_expense_tracker_card.dart'; // Import DailyExpenseTrackerCard
import 'features/expense_tracker/models/expense_tracker_models.dart'; // Import ExpenseEntry and ExpenseCategories
import 'features/mood_gratitude/widgets/mood_gratitude_card.dart'; // Import MoodGratitudeCard
import 'features/mood_gratitude/widgets/mood_gratitude_card_content.dart'; // Import MoodGratitudeCardContent
import 'features/mood_gratitude/pages/mood_gratitude_setup_page.dart'; // Import MoodGratitudeSetupPage
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'services/task_service.dart';
import 'widgets/task_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class CardStackReversed extends StatefulWidget {
  const CardStackReversed({super.key});

  @override
  _CardStackReversedState createState() => _CardStackReversedState();
}

class _CardStackReversedState extends State<CardStackReversed> {
  Set<String> expandedCards = {}; 
  int _selectedIndex = 0; // Track the selected index for the navigation bar
  bool _isLoading = true;
  late ScrollController _tagsScrollController;
  
  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Reset state variables
    expandedCards = {};
    _selectedIndex = 0;
    _isLoading = true;
    cards = [];
    selectedTags = {'All'};
    _searchText = '';
    _sortOption = 'Newest';
    
    _tagsScrollController = ScrollController();
    _loadCards();
  }
  
  @override
  void dispose() {
    _tagsScrollController.dispose();
    super.dispose();
  }
  
  // List of cards from database
  List<CardModel> cards = [];
  
  // Selected tags for filtering
  Set<String> selectedTags = {'All'};
  
  // All available tags
  Set<String> uniqueTags = {'All', 'Health', 'Hydration', 'Productivity', 'Priorities', 'health', 'nutrition', 'water', 'exercise', 'work', 'personal', 'family', 'shopping', 'travel', 'finance', 'education', 'entertainment', 'social', 'technology', 'home'};

  // Search and sort options
  String _searchText = '';
  String _sortOption = 'Newest'; // Default sort option
  
  // Available sort options
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Completion Rate'];
  
  // Notification service
  final NotificationService _notificationService = NotificationService();

  // Helper method to estimate text height based on content
  double _estimateTextHeight(String text, double width, TextStyle style) {
    final fontSize = style.fontSize ?? 14.0;
    final lineHeight = fontSize * 1.2; // Standard line height multiplier

    // Estimate number of characters per line
    final charsPerLine = (width / (fontSize * 0.6)).floor();
    
    // Estimate number of lines
    final lineCount = (text.length / charsPerLine).ceil();

    // Calculate total height
    final totalHeight = lineCount * lineHeight;

    return totalHeight;
  }

  // Calculate dynamic height for a card based on its content
  double _calculateCardHeight(CardModel card, double availableWidth) {
    // Special case for water intake cards
    if (card.metadata?['type'] == 'water_intake') {
      // Set a specific fixed height for water intake cards
      // Base height (100) + expanded content height (600) + some padding
      return expandedCards.contains(card.id) ? 700.0 : 180.0;
    }
    
    // Special case for top priorities cards
    if (card.metadata?['type'] == 'top_priorities') {
      // Set a specific fixed height for top priorities cards
      return expandedCards.contains(card.id) ? 600.0 : 180.0;
    }
    
    // Special case for calorie tracker cards
    if (card.metadata?['type'] == 'calorie_tracker') {
      // Set a specific fixed height for calorie tracker cards
      // Increased height to accommodate 5 entries plus extra padding
      return expandedCards.contains(card.id) ? 780.0 : 180.0;
    }
    
    // Special case for expense tracker cards
    if (card.metadata?['type'] == 'expense_tracker') {
      // Set a specific fixed height for expense tracker cards - increased height for expanded state
      // Increased further to accommodate calendar navigation
      return expandedCards.contains(card.id) ? 680.0 : 180.0;
    }
    
    // Special case for mood & gratitude cards
    if (card.metadata?['type'] == 'mood_gratitude') {
      // Set a specific fixed height for mood & gratitude cards
      return expandedCards.contains(card.id) ? 600.0 : 180.0;
    }
    
    // For regular cards
    if (expandedCards.contains(card.id)) {
      // For expanded regular cards, calculate based on task count
      return 180.0 + (card.tasks.length * 80.0);
    } else {
      // For collapsed regular cards
      return 180.0;
    }
  }
  
  // Load cards from database
  Future<void> _loadCards() async {
    print("_loadCards called");
    
    if (mounted) {
    setState(() {
      _isLoading = true;
    });
    }
    
    try {
      // Get cards from database
      final loadedCards = await CardService.getCards();
      print("Loaded ${loadedCards.length} cards from database");
      
      // Debug: Print all card types
      for (var card in loadedCards) {
        print("Card ID: ${card.id}, Type: ${card.metadata?['type'] ?? 'unknown'}, Title: ${card.title}");
      }
      
      // Extract all unique tags
      final Set<String> uniqueTagsSet = {'All'};
      for (var card in loadedCards) {
        if (card.tags != null) {
          uniqueTagsSet.addAll(card.tags!);
        }
      }
      
      // Check for expense tracker cards
      final expenseTrackerCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'expense_tracker').toList();
      print("Found ${expenseTrackerCards.length} expense tracker cards");
      if (expenseTrackerCards.isNotEmpty) {
        print("Expense tracker card IDs: ${expenseTrackerCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for water intake cards
      final waterIntakeCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'water_intake').toList();
      print("Found ${waterIntakeCards.length} water intake cards");
      if (waterIntakeCards.isNotEmpty) {
        print("Water intake card IDs: ${waterIntakeCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for top priorities cards
      final topPrioritiesCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'top_priorities').toList();
      print("Found ${topPrioritiesCards.length} top priorities cards");
      if (topPrioritiesCards.isNotEmpty) {
        print("Top priorities card IDs: ${topPrioritiesCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for calorie tracker cards
      final calorieTrackerCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'calorie_tracker').toList();
      print("Found ${calorieTrackerCards.length} calorie tracker cards");
      if (calorieTrackerCards.isNotEmpty) {
        print("Calorie tracker card IDs: ${calorieTrackerCards.map((c) => c.id).join(', ')}");
      }
      
      if (mounted) {
      setState(() {
        cards = loadedCards;
          uniqueTags = uniqueTagsSet;
        _isLoading = false;
        
          // Sort cards to ensure special cards are at the top
          // and regular cards are at the bottom (with newest regular cards at the top of the regular cards section)
          cards.sort((a, b) {
            // Special cards come before regular cards
            final aIsSpecial = a.metadata != null && a.metadata!['type'] != null;
            final bIsSpecial = b.metadata != null && b.metadata!['type'] != null;
            
            if (aIsSpecial && !bIsSpecial) return -1;
            if (!aIsSpecial && bIsSpecial) return 1;
            
            // If both are special or both are regular, sort by date (newest first)
            return b.createdAt.compareTo(a.createdAt);
          });
          
          // Clear all expanded cards first
          expandedCards.clear();
          
          // Don't auto-expand any regular cards when the app opens
          // Removed the code that auto-expands the most recent regular card
        });
        
        // Force a rebuild after a short delay to ensure UI updates
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
          }
        });
      }
    } catch (e) {
      print("Error loading cards: $e");
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cards: $e')),
        );
      }
    }
  }
  
  // Filter cards based on selected tags
  List<CardModel> get filteredCards {
    List<CardModel> filtered;
    
    // First filter by tags
    if (selectedTags.contains('All')) {
      filtered = List.from(cards);
    } else {
      filtered = cards.where((card) {
        return card.tags.any((tag) => selectedTags.contains(tag));
      }).toList();
    }
    
    // Then filter by search text if provided
    if (_searchText.isNotEmpty) {
      final searchLower = _searchText.toLowerCase();
      filtered = filtered.where((card) {
        // Search in title
        if (card.title.toLowerCase().contains(searchLower)) {
          return true;
        }
        
        // Search in tasks
        for (var task in card.tasks) {
          if (task.description.toLowerCase().contains(searchLower) || 
              (task.notes != null && task.notes!.toLowerCase().contains(searchLower))) {
            return true;
          }
        }
        
        // Search in tags
        for (var tag in card.tags) {
          if (tag.toLowerCase().contains(searchLower)) {
            return true;
          }
        }
        
        return false;
      }).toList();
    }
    
    // Separate pinned cards so they stay at the top
    final pinnedCards = filtered.where((card) => card.isFavorited).toList();
    final unpinnedCards = filtered.where((card) => !card.isFavorited).toList();
    
    // Sort unpinned cards based on sort option
    switch (_sortOption) {
      case 'Newest':
        unpinnedCards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Oldest':
        unpinnedCards.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'Completion Rate':
        // Parse progress string (e.g. "75%") to numeric value for sorting
        unpinnedCards.sort((a, b) {
          final aProgress = int.tryParse(a.progress.replaceAll('%', '')) ?? 0;
          final bProgress = int.tryParse(b.progress.replaceAll('%', '')) ?? 0;
          return bProgress.compareTo(aProgress); // Higher percentage first
        });
        break;
    }
    
    // Combine pinned cards at the top with sorted unpinned cards
    return [...pinnedCards, ...unpinnedCards];
  }

  // Toggle tag selection
  void _toggleTag(String tag) {
    setState(() {
      if (tag == 'All') {
        selectedTags = {'All'};
      } else {
        // Remove 'All' when selecting specific tags
        selectedTags.remove('All');
        
        // Toggle the selected tag
        if (selectedTags.contains(tag)) {
          selectedTags.remove(tag);
          
          // If no tags are selected, default to 'All'
          if (selectedTags.isEmpty) {
            selectedTags = {'All'};
          }
        } else {
          selectedTags.add(tag);
        }
      }
      
      // Remove the auto-expansion of the last card in filtered list
      // List<CardModel> currentFilteredCards = filteredCards;
      // if (currentFilteredCards.isNotEmpty) {
      //   expandedCards.add(currentFilteredCards.last.id);
      // }
    });
  }
  
  // Toggle card expansion
  void toggleCard(String id) {
    print("Toggling card: $id");
    setState(() {
      if (expandedCards.contains(id)) {
        // Allow collapsing any card, including the last card
        expandedCards.remove(id);
        print("Card collapsed: $id");
      } else {
        expandedCards.add(id);
        print("Card expanded: $id");
      }
      
      // Force a rebuild to ensure the UI updates
      Future.microtask(() {
        if (mounted) {
          setState(() {});
        }
      });
    });
  }

  // Handle navigation item tap
  void _onItemTapped(int index) {
    if (index == 2) {
      // For settings tab, navigate to settings page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
    } else if (index == 1) {
      // For add tab, directly navigate to image capture
      _navigateToImageCapture(context);
    } else {
      // For home tab, update the selected index
      setState(() {
        _selectedIndex = index;
      });
    }
  }
  
  // Navigate to add card page
  void _navigateToAddCard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCardPage(
          card: {
            'id': '',
            'title': '',
            'description': '',
            'color': '0xFF6C5CE7',
            'tags': <String>[],
            'tasks': <Map<String, dynamic>>[],
          },
          onSave: (cardData) async {
            try {
              await _addNewCard(cardData);
              // Refresh cards from database after adding a new card
              await _refreshCards();
              
              // Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Card added successfully'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              print('Error saving card: $e');
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving card: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          onDelete: (cardId) {
            // No need to do anything for a new card
          },
        ),
      ),
    );
  }
  
  // Navigate to image capture page
  void _navigateToImageCapture(BuildContext context) {
    print("Navigating to ImageCapturePage");
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageCapturePage(
          onCardCreated: (cardData) async {
            print("Card created from ImageCapturePage");
            print("Card data: ${json.encode(cardData)}");
            
            try {
              // Show loading indicator
              setState(() {
                _isLoading = true;
              });
              
              // Add the new card to the database and get the saved card
              final savedCard = await _addNewCard(cardData);
              
              // Update the UI with the new card without a full refresh
              setState(() {
                _isLoading = false;
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Card added successfully'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              });
            } catch (e) {
              print('Error saving card from ImageCapturePage: $e');
              
              // Update UI state
              setState(() {
                _isLoading = false;
              });
              
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error saving card: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  // Add method to handle new cards
  Future<CardModel> _addNewCard(Map<String, dynamic> newCard) async {
    try {
      // Create UUID instance for generating IDs
      final _uuid = Uuid();
      
      // Ensure the card has an ID
      if (newCard['id'] == null || newCard['id'].isEmpty) {
        newCard['id'] = _uuid.v4();
      }
      
      print("Adding new card with ID: ${newCard['id']}");
      print("Card data before saving: ${json.encode(newCard)}");
      
      // Check if user is authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;
      print("Current user: ${currentUser?.id ?? 'Not authenticated'}");
      
      if (currentUser == null) {
        print("ERROR: User not authenticated. Cannot save card.");
        throw Exception("User not authenticated. Please log in and try again.");
      }
      
      // Ensure user_id is set
      newCard['user_id'] = currentUser.id;
      
      // Save card to database with notifyListeners set to false to prevent immediate UI refresh
      print("Saving card to database...");
      final savedCard = await CardService.createCard(newCard, notifyListeners: false);
      print("Card saved successfully with ID: ${savedCard.id}");
      
      // Check if this is a special card type
      bool isWaterIntakeCard = newCard['metadata'] != null && 
                              newCard['metadata']['type'] == 'water_intake';
      bool isTopPrioritiesCard = newCard['metadata'] != null && 
                                newCard['metadata']['type'] == 'top_priorities';
      bool isCalorieTrackerCard = newCard['metadata'] != null && 
                                 newCard['metadata']['type'] == 'calorie_tracker';
      
      // Update the UI immediately with the new card
      setState(() {
        // First, close all expanded regular cards if this is a regular card
        if (!isWaterIntakeCard && !isTopPrioritiesCard && !isCalorieTrackerCard) {
          final regularCardIds = cards
              .where((c) => c.metadata == null || c.metadata!['type'] == null)
              .map((c) => c.id)
              .toList();
          
          for (var cardId in regularCardIds) {
            expandedCards.remove(cardId);
          }
        }
        
        // Add the new card to the list
        cards.insert(0, savedCard);
        
        // Update tags
        final tags = {'All'};
        for (final card in cards) {
          tags.addAll(card.tags ?? []);
        }
        uniqueTags = tags;
        
        // Expand the new card
        expandedCards.add(savedCard.id);
        
        // Sort cards to ensure special cards are at the top
        cards.sort((a, b) {
          // Special cards come before regular cards
          final aIsSpecial = a.metadata != null && a.metadata!['type'] != null;
          final bIsSpecial = b.metadata != null && b.metadata!['type'] != null;
          
          if (aIsSpecial && !bIsSpecial) return -1;
          if (!aIsSpecial && bIsSpecial) return 1;
          
          // If both are special or both are regular, sort by date (newest first)
          return b.createdAt.compareTo(a.createdAt);
        });
      });
      
      // Handle special card types if needed
      if (isWaterIntakeCard) {
        await _ensureWaterIntakeCardsVisible();
      } else if (isTopPrioritiesCard) {
        await _ensureTopPrioritiesCardsVisible();
      } else if (isCalorieTrackerCard) {
        await _ensureCalorieTrackerCardsVisible();
      }
      
      // Schedule a background refresh to ensure data consistency
      // but don't wait for it to complete
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          CardService.getCards().then((updatedCards) {
            if (mounted) {
              setState(() {
                // Update cards while preserving expanded state
                final expandedCardIds = Set<String>.from(expandedCards);
                cards = updatedCards;
                expandedCards = expandedCardIds;
              });
            }
          }).catchError((e) {
            print("Error in background refresh: $e");
          });
        }
      });
      
      return savedCard;
    } catch (e) {
      print('Error saving card: $e');
      // Rethrow the error to be handled by the caller
      rethrow;
    }
  }

  // Open edit page for a card
  Future<void> _openEditPage(CardModel card) async {
    print('CardStackReversed: Opening edit page for card ${card.id}');
    print('CardStackReversed: Card metadata type: ${card.metadata?['type']}');
    
    // Check if this is a water intake card
    if (card.metadata?['type'] == 'water_intake') {
      print('CardStackReversed: Opening WaterIntakeEditPage');
      // Open the water intake edit page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaterIntakeEditPage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            onSave: (updatedMetadata) async {
              try {
                // Update card metadata
                await CardService.updateCardMetadata(card.id, updatedMetadata);
                
                // Refresh the card in the UI
                setState(() {
                  // Find and update just this card in the list
                  final index = cards.indexWhere((c) => c.id == card.id);
                  if (index != -1) {
                    // Create a new card with updated metadata
                    final updatedCard = CardModel.fromMap({
                      ...cards[index].toMap(),
                      'metadata': updatedMetadata,
                    });
                    cards[index] = updatedCard;
                  }
                });
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hydration settings updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating hydration settings: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
      return;
    }
    
    // Check if this is a calorie tracker card
    if (card.metadata?['type'] == 'calorie_tracker') {
      print('CardStackReversed: Opening CalorieTrackerSetupPage');
      // Open the calorie tracker setup page for editing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalorieTrackerSetupPage(
            isEditing: true,
            cardId: card.id,
            initialMetadata: card.metadata ?? {},
            onSave: (updatedMetadata) async {
              try {
                // Update card metadata
                await CardService.updateCardMetadata(card.id, updatedMetadata);
                
                // Refresh the card in the UI
                setState(() {
                  // Find and update just this card in the list
                  final index = cards.indexWhere((c) => c.id == card.id);
                  if (index != -1) {
                    // Create a new card with updated metadata
                    final updatedCard = CardModel.fromMap({
                      ...cards[index].toMap(),
                      'metadata': updatedMetadata,
                    });
                    cards[index] = updatedCard;
                  }
                  
                  // Make sure the card is expanded to show changes
                  expandedCards.add(card.id);
                });
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Calorie tracker settings updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating calorie tracker settings: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
      return;
    }
    
    // Check if this is a top priorities card
    if (card.metadata?['type'] == 'top_priorities') {
      print('CardStackReversed: Opening TopPrioritiesPage');
      
      // Open the top priorities edit page
      final updatedCard = await Navigator.push<CardModel>(
        context,
        MaterialPageRoute(
          builder: (context) => TopPrioritiesPage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            isEditing: true,
            onSave: (updatedMetadata) async {
              try {
                // Update card metadata first
                await CardService.updateCardMetadata(card.id, updatedMetadata);
                
                // Get the fully updated card with all changes including task deletions
                final freshCard = await CardService.getCardById(card.id);
                return freshCard;
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating top priorities: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                return null;
              }
            },
          ),
        ),
      );
      
      print('CardStackReversed: Returned from TopPrioritiesPage with card: ${updatedCard?.id}');
      
      // If a card was returned, update it directly in our cards list to avoid flickering
      if (updatedCard != null) {
        setState(() {
          // Find and update the card in the list
          final index = cards.indexWhere((c) => c.id == updatedCard.id);
          if (index != -1) {
            // Replace with the fresh card that includes all changes
            cards[index] = updatedCard;
            
            // Ensure the card is expanded
            expandedCards.add(updatedCard.id);
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Top priorities updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      return;
    }
    
    // Check if this is an expense tracker card
    if (card.metadata?['type'] == 'expense_tracker') {
      print('CardStackReversed: Opening ExpenseTrackerSetupPage');
      // Open the expense tracker setup page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseTrackerSetupPage(
            cardId: card.id,
            initialMetadata: card.metadata ?? {},
            isEditing: true,
            onSave: (updatedMetadata) async {
              try {
                // Update card metadata
                await CardService.updateCardMetadata(card.id, updatedMetadata);
                
                // Refresh the card in the UI
                setState(() {
                  // Find and update just this card in the list
                  final index = cards.indexWhere((c) => c.id == card.id);
                  if (index != -1) {
                    // Create a new card with updated metadata
                    final updatedCard = CardModel.fromMap({
                      ...cards[index].toMap(),
                      'metadata': updatedMetadata,
                    });
                    cards[index] = updatedCard;
                  }
                });
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Expense tracker settings updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating expense tracker settings: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
      return;
    }
    
    // Check if this is a mood & gratitude card
    if (card.metadata?['type'] == 'mood_gratitude') {
      print('CardStackReversed: Opening MoodGratitudeSetupPage');
      // Open the mood & gratitude setup page for editing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MoodGratitudeSetupPage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            onSave: (updatedMetadata) async {
              try {
                // Update card metadata
                await CardService.updateCardMetadata(card.id, updatedMetadata);
                
                // Refresh the card in the UI
                setState(() {
                  // Find and update just this card in the list
                  final index = cards.indexWhere((c) => c.id == card.id);
                  if (index != -1) {
                    // Create a new card with updated metadata
                    final updatedCard = CardModel.fromMap({
                      ...cards[index].toMap(),
                      'metadata': updatedMetadata,
                    });
                    cards[index] = updatedCard;
                  }
                  
                  // Make sure the card is expanded to show changes
                  expandedCards.add(card.id);
                });
                
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mood & Gratitude settings updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating Mood & Gratitude settings: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
      return;
    }
    
    print('CardStackReversed: Opening ReviewTodoListPage (standard edit page)');
    // For regular cards, open the standard edit page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewTodoListPage(
          ocrText: '', // Empty since we're editing an existing card
          initialResult: card.toUiMap(), // Convert CardModel to Map for backward compatibility
          onSaveCard: (updatedCard) async {
            try {
              // Update card in database
              final savedCard = await CardService.updateCard(updatedCard);
              
              setState(() {
                // Find and update the card in the list
                final index = cards.indexWhere((c) => c.id == savedCard.id);
                if (index != -1) {
                  cards[index] = savedCard;
                }
                
                // Update tags
                final tags = {'All'};
                for (final card in cards) {
                  tags.addAll(card.tags);
                }
                uniqueTags = tags;
              });
            } catch (e) {
              print('Error updating card: $e');
              // Show error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating card: $e')),
              );
            }
          },
          onDeleteCard: (cardId) async {
            try {
              // Delete card from database
              await CardService.deleteCard(cardId);
              
              setState(() {
                // Remove the card from the list
                cards.removeWhere((c) => c.id == cardId);
                // Remove from expanded cards if it was expanded
                expandedCards.remove(cardId);
                
                // Update tags
                final tags = {'All'};
                for (final card in cards) {
                  tags.addAll(card.tags);
                }
                uniqueTags = tags;
              });
            } catch (e) {
              print('Error deleting card: $e');
              // Show error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting card: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  // Refresh cards from database
  Future<void> _refreshCards() async {
    print("_refreshCards called");
    
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // Check if user is authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;
      print("Current user during refresh: ${currentUser?.id ?? 'Not authenticated'}");
      
      if (currentUser == null) {
        print("WARNING: User not authenticated during refresh. This may cause issues.");
      }
      
      // Get cards from database
      print("Fetching cards from database...");
      final loadedCards = await CardService.getCards();
      print("Loaded ${loadedCards.length} cards from database");
      
      // Debug: Print all card types
      for (var card in loadedCards) {
        print("Card ID: ${card.id}, Type: ${card.metadata?['type'] ?? 'unknown'}, Title: ${card.title}");
      }
      
      // Extract all unique tags
      final Set<String> uniqueTagsSet = {'All'};
      for (var card in loadedCards) {
        if (card.tags != null) {
          uniqueTagsSet.addAll(card.tags!);
        }
      }
      
      // Check for expense tracker cards
      final expenseTrackerCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'expense_tracker').toList();
      print("Found ${expenseTrackerCards.length} expense tracker cards");
      if (expenseTrackerCards.isNotEmpty) {
        print("Expense tracker card IDs: ${expenseTrackerCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for water intake cards
      final waterIntakeCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'water_intake').toList();
      print("Found ${waterIntakeCards.length} water intake cards");
      if (waterIntakeCards.isNotEmpty) {
        print("Water intake card IDs: ${waterIntakeCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for top priorities cards
      final topPrioritiesCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'top_priorities').toList();
      print("Found ${topPrioritiesCards.length} top priorities cards");
      if (topPrioritiesCards.isNotEmpty) {
        print("Top priorities card IDs: ${topPrioritiesCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for calorie tracker cards
      final calorieTrackerCards = loadedCards.where((card) => 
        card.metadata != null && card.metadata!['type'] == 'calorie_tracker').toList();
      print("Found ${calorieTrackerCards.length} calorie tracker cards");
      if (calorieTrackerCards.isNotEmpty) {
        print("Calorie tracker card IDs: ${calorieTrackerCards.map((c) => c.id).join(', ')}");
      }
      
      // Check for regular todo cards
      final regularCards = loadedCards.where((card) => 
        card.metadata == null || card.metadata!['type'] == null).toList();
      print("Found ${regularCards.length} regular todo cards");
      if (regularCards.isNotEmpty) {
        print("Regular card IDs: ${regularCards.map((c) => c.id).join(', ')}");
      }
      
      if (mounted) {
        setState(() {
          print("Updating state with ${loadedCards.length} cards");
          cards = loadedCards;
          uniqueTags = uniqueTagsSet;
          _isLoading = false;
          
          // Sort cards to ensure special cards are at the top
          // and regular cards are at the bottom (with newest regular cards at the top of the regular cards section)
          cards.sort((a, b) {
            // Special cards come before regular cards
            final aIsSpecial = a.metadata != null && a.metadata!['type'] != null;
            final bIsSpecial = b.metadata != null && b.metadata!['type'] != null;
            
            if (aIsSpecial && !bIsSpecial) return -1;
            if (!aIsSpecial && bIsSpecial) return 1;
            
            // If both are special or both are regular, sort by date (newest first)
            return b.createdAt.compareTo(a.createdAt);
          });
          
          // Clear all expanded cards first
          expandedCards.clear();
          
          // Don't auto-expand any regular cards when refreshing
          // Removed the code that auto-expands the most recent regular card
        });
        
        // Force a rebuild after a short delay to ensure UI updates
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              print("Forcing UI update after refresh");
            });
          }
        });
      }
    } catch (e) {
      print("Error loading cards: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading cards: $e')),
        );
      }
    }
  }

  // Force a complete UI refresh
  void _forceUIRefresh() {
    print("Smooth UI refresh");
    setState(() {
      // Single refresh, no multiple delayed setState calls
    });
  }

  // Add template card
  Future<void> _addTemplateCard(String templateType) async {
    print("Adding template card: $templateType");
    
    dynamic result;
    
    if (templateType == 'expense_tracker') {
      // Navigate to expense tracker setup page
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ExpenseTrackerSetupPage(),
        ),
      );
      
      print("Returned from ExpenseTrackerSetupPage with result: $result");
      
      if (result == true) {
        print("Card created successfully, refreshing cards");
        
        // Wait for database operations to complete
        await Future.delayed(const Duration(seconds: 1));
        
        // Refresh cards from database
        await _refreshCards();
        
        // Force a complete UI refresh
        _forceUIRefresh();
        
        // Try loading cards again if no expense tracker cards were found
        final updatedExpenseTrackerCards = cards.where(
          (card) => card.metadata != null && card.metadata!['type'] == 'expense_tracker'
        ).toList();
        
        if (updatedExpenseTrackerCards.isEmpty) {
          print("No expense tracker cards found after refresh, trying again");
          await Future.delayed(const Duration(seconds: 1));
          await _loadCards();
          _forceUIRefresh();
        }
      } else {
        print("User cancelled expense tracker creation or there was an error");
      }
    } else if (templateType == 'water_intake') {
      // Check if a water intake card already exists
      final existingWaterIntakeCards = cards.where(
        (card) => card.metadata != null && card.metadata!['type'] == 'water_intake'
      ).toList();
      
      if (existingWaterIntakeCards.isNotEmpty) {
        // Get the first water intake card
        final existingWaterIntakeCard = existingWaterIntakeCards.first;
        
        // If a water intake card already exists, expand it instead of creating a new one
        setState(() {
          // Make sure the card is expanded
          if (!expandedCards.contains(existingWaterIntakeCard.id)) {
            expandedCards.add(existingWaterIntakeCard.id);
          }
          
          // Show a message to the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You already have a Hydration Tracker card'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        });
        
        return; // Exit early, don't create a new card
      }
      
      // No existing water intake card, show the onboarding page
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaterIntakeOnboarding(
            onComplete: (Map<String, dynamic> metadata) async {
              // Create a new card with the water intake metadata
              final _uuid = Uuid();
              final now = DateTime.now();
              
              // Create the card data
              final cardData = {
                'id': _uuid.v4(),
                'user_id': Supabase.instance.client.auth.currentUser?.id,
                'title': 'Hydration Tracker',
                'description': 'Track your daily water consumption',
                'color': '0xFF00BCD4', // Cyan
                'tags': ['Health', 'Habits'],
                'created_at': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'metadata': {
                  'type': 'water_intake',
                  ...metadata,
                },
              };
              
              try {
                // Create the card in the database
                await CardService.createCard(cardData);
                
                // Ensure the card is visible
                await _ensureWaterIntakeCardsVisible();
                
                return true;
              } catch (e) {
                print("Error creating water intake card: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error creating water intake card: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                return false;
              }
            },
          ),
        ),
      );
      
      print("Returned from WaterIntakeOnboarding with result: $result");
      
      if (result == true) {
        print("Card created successfully, ensuring it's visible");
        
        // Wait for database operations to complete
        await Future.delayed(const Duration(seconds: 1));
        
        // Use the specialized method to ensure water intake cards are visible
        await _ensureWaterIntakeCardsVisible();
        
        // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hydration card added to your home screen'),
              duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
            ),
          );
      } else {
        print("User cancelled water intake creation or there was an error");
      }
    } else if (templateType == 'top_priorities') {
      // Navigate to top priorities page
      final result = await Navigator.push<CardModel>(
          context,
          MaterialPageRoute(
            builder: (context) => const TopPrioritiesPage(),
          ),
      );
      
      print("Returned from TopPrioritiesPage with result: $result");
      
      if (result != null) {
        print("Top priorities card created successfully, ensuring it's visible");
        
        // Wait for database operations to complete
        await Future.delayed(const Duration(seconds: 1));
        
        // Use the specialized method to ensure top priorities cards are visible
        await _ensureTopPrioritiesCardsVisible();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Top Priorities card added to your home screen'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print("User cancelled top priorities creation or there was an error");
      }
    } else if (templateType == 'calorie_tracker') {
      // Navigate to calorie tracker setup page
      result = await Navigator.push(
          context,
          MaterialPageRoute(
          builder: (context) => const CalorieTrackerSetupPage(),
        ),
      );
      
      print("Returned from CalorieTrackerSetupPage with result: $result");
      
      if (result == true) {
        print("Calorie tracker card created successfully, ensuring it's visible");
        
        // Wait for database operations to complete
        await Future.delayed(const Duration(seconds: 1));
        
        // Use the specialized method to ensure calorie tracker cards are visible
        await _ensureCalorieTrackerCardsVisible();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calorie Tracker card added to your home screen'),
            duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
      } else {
        print("User cancelled calorie tracker creation or there was an error");
      }
    }
    
    return result;
  }

  Future<void> _ensureWaterIntakeCardsVisible() async {
    print("Ensuring water intake cards are visible");
    
    // First attempt - refresh cards
    await _refreshCards();
    _forceUIRefresh();
    
    // Check for water intake cards
    var waterIntakeCards = cards.where(
      (card) => card.metadata != null && card.metadata!['type'] == 'water_intake'
    ).toList();
    
    print("First attempt: Found ${waterIntakeCards.length} water intake cards");
    
    // Second attempt if no cards found
    if (waterIntakeCards.isEmpty) {
      print("No water intake cards found, trying second attempt");
      await Future.delayed(const Duration(seconds: 1));
      await _loadCards();
      _forceUIRefresh();
      
      waterIntakeCards = cards.where(
        (card) => card.metadata != null && card.metadata!['type'] == 'water_intake'
      ).toList();
      
      print("Second attempt: Found ${waterIntakeCards.length} water intake cards");
      
      // Third attempt with longer delay if still no cards found
      if (waterIntakeCards.isEmpty) {
        print("Still no water intake cards found, trying third attempt with longer delay");
        await Future.delayed(const Duration(seconds: 2));
        await _loadCards();
        _forceUIRefresh();
        
        waterIntakeCards = cards.where(
          (card) => card.metadata != null && card.metadata!['type'] == 'water_intake'
        ).toList();
        
        print("Third attempt: Found ${waterIntakeCards.length} water intake cards");
      }
    }
    
    // No longer auto-expanding water intake cards
    if (waterIntakeCards.isNotEmpty) {
      print("Water intake card IDs: ${waterIntakeCards.map((c) => c.id).join(', ')}");
    } else {
      print("WARNING: No water intake cards found after multiple attempts");
    }
  }
  
  // Ensure top priorities cards are visible after creation
  Future<void> _ensureTopPrioritiesCardsVisible() async {
    print('Ensuring top priorities cards are visible');
    
    try {
      // Get the latest cards from the database in a single call
      final latestCards = await CardService.getCards();
      
      // Check if we need to update our state
      if (latestCards != null && latestCards.isNotEmpty) {
        setState(() {
          // Create a map of expanded state to preserve it
          final expandedMap = Map<String, bool>.fromIterable(
            expandedCards, 
            key: (card) => card, 
            value: (_) => true
          );
          
          // Update the cards list with the latest data
          cards = latestCards;
          
          // Sort to ensure special cards are at the top
          _sortCards();
          
          // Restore expanded state and ensure top priority cards are expanded
          expandedCards.clear();
          for (final card in cards) {
            // Restore previous expanded state
            if (expandedMap.containsKey(card.id)) {
              expandedCards.add(card.id);
            }
            
            // Make sure top priority cards are expanded
            if (card.metadata?['type'] == 'top_priorities') {
              expandedCards.add(card.id);
            }
          }
        });
      }
    } catch (e) {
      print('Error ensuring top priority cards visible: $e');
    }
  }

  // Update with more efficient implementation to reduce flickering and ensure proper refresh
  Future<void> _ensureCalorieTrackerCardsVisible() async {
    print("Ensuring calorie tracker cards are visible");
    
    // First attempt - refresh cards
    await _refreshCards();
    _forceUIRefresh();
    
    // Check for calorie tracker cards
    var calorieTrackerCards = cards.where(
      (card) => card.metadata != null && card.metadata!['type'] == 'calorie_tracker'
    ).toList();
    
    print("First attempt: Found ${calorieTrackerCards.length} calorie tracker cards");
    
    // Second attempt if no cards found
    if (calorieTrackerCards.isEmpty) {
      print("No calorie tracker cards found, trying second attempt");
      await Future.delayed(const Duration(seconds: 1));
      await _loadCards();
      _forceUIRefresh();
      
      calorieTrackerCards = cards.where(
        (card) => card.metadata != null && card.metadata!['type'] == 'calorie_tracker'
      ).toList();
      
      print("Second attempt: Found ${calorieTrackerCards.length} calorie tracker cards");
      
      // Third attempt with longer delay if still no cards found
      if (calorieTrackerCards.isEmpty) {
        print("Still no calorie tracker cards found, trying third attempt with longer delay");
        await Future.delayed(const Duration(seconds: 2));
        await _loadCards();
        _forceUIRefresh();
        
        calorieTrackerCards = cards.where(
          (card) => card.metadata != null && card.metadata!['type'] == 'calorie_tracker'
        ).toList();
        
        print("Third attempt: Found ${calorieTrackerCards.length} calorie tracker cards");
      }
    }
    
    // No longer auto-expanding calorie tracker cards
    if (calorieTrackerCards.isNotEmpty) {
      print("Calorie tracker card IDs: ${calorieTrackerCards.map((c) => c.id).join(', ')}");
    } else {
      print("WARNING: No calorie tracker cards found after multiple attempts");
    }
  }

  // Toggle pin status of a card
  void _togglePinCard(CardModel card) async {
    try {
      // Update card in database
      final updatedCard = await CardService.updateCard({
        ...card.toMap(),
        'isFavorited': !card.isFavorited,
      });
      
      setState(() {
        // Find and update the card in the list
        final index = cards.indexWhere((c) => c.id == updatedCard.id);
        if (index != -1) {
          cards[index] = updatedCard;
        }
      });
    } catch (e) {
      print('Error updating card pin status: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating card pin status: $e')),
      );
    }
  }

  // Toggle task completion status
  void _toggleTaskCompletion(TaskModel task) async {
    try {
      // Update task in database
      final updatedCard = await CardService.updateTaskCompletion(
        task.cardId, 
        task.id, 
        !task.isCompleted
      );
      
      setState(() {
        // Find and update the card in the list
        final index = cards.indexWhere((c) => c.id == updatedCard.id);
        if (index != -1) {
          cards[index] = updatedCard;
        }
      });
    } catch (e) {
      print('Error updating task completion status: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task completion status: $e')),
      );
    }
  }

  // Build a task item widget
  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    return TaskItem(
      task: task,
      onToggleCompletion: (bool value) => _toggleTaskCompletion(task),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Add debug prints
    print("CardStackReversed build method called");
    print("Cards count: ${cards.length}");
    print("Is loading: $_isLoading");
    
    // Get theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // Create background widget
    final backgroundWidget = themeProvider.isDarkMode
        ? BackgroundPatterns.darkThemeBackground()
        : BackgroundPatterns.lightThemeBackground();
    
    // Default page (home/cards)
    Widget currentPage = Stack(
      children: [
        // Background pattern as the bottom layer for the entire page
        Positioned.fill(child: backgroundWidget),
        
        // All UI elements on top
        SafeArea(
          child: Column(
            children: [
              // Top App Bar with app name and settings button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App name with logo
                    Row(
                      children: [
                        Icon(Icons.menu, color: themeProvider.isDarkMode ? Colors.white : Colors.black87),
                        SizedBox(width: 12),
                        Text(
                          'Snap2Done',
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black87
                          ),
                        ),
                      ],
                    ),
                    // Empty space where settings button was
                    SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Add Recommended Cards section
              RecommendedCards(
                onCardSelected: _handleCardSelection,
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Search icon
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, right: 8.0),
                        child: Icon(
                          Icons.search,
                          color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                          size: 20,
                        ),
                      ),
                      // Search text field
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search in cards...',
                            hintStyle: TextStyle(
                              color: themeProvider.isDarkMode ? Colors.white60 : Colors.grey.shade500,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          style: TextStyle(
                            color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      // Divider
                      Container(
                        height: 24,
                        width: 1,
                        color: themeProvider.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                      ),
                      // Sort by Newest
                      InkWell(
                        onTap: () {
                          setState(() {
                            _sortOption = 'Newest';
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_downward,
                            color: _sortOption == 'Newest' 
                              ? Color(0xFF6C5CE7) 
                              : themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                      ),
                      // Sort by Oldest
                      InkWell(
                        onTap: () {
                          setState(() {
                            _sortOption = 'Oldest';
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_upward,
                            color: _sortOption == 'Oldest' 
                              ? Color(0xFF6C5CE7) 
                              : themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                      ),
                      // Sort by Completion Rate
                      InkWell(
                        onTap: () {
                          setState(() {
                            _sortOption = 'Completion Rate';
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.percent,
                            color: _sortOption == 'Completion Rate' 
                              ? Color(0xFF6C5CE7) 
                              : themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                      ),
                      if (_searchText.isNotEmpty)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _searchText = '';
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.clear,
                              color: themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Tags list
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Container(
                  height: 32, // Reduced from 48 (about 1/3 reduction)
                  child: _isLoading 
                    ? Center(child: CircularProgressIndicator())
                    : GestureDetector(
                        // Add horizontal drag support to make scrolling more responsive
                        onHorizontalDragUpdate: (details) {
                          if (_tagsScrollController.hasClients) {
                            _tagsScrollController.position.jumpTo(
                              _tagsScrollController.offset - details.delta.dx
                            );
                          }
                        },
                        child: ShaderMask(
                          shaderCallback: (Rect rect) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: themeProvider.isDarkMode 
                                ? [
                                    Colors.black, 
                                    Colors.transparent, 
                                    Colors.transparent, 
                                    Colors.black
                                  ]
                                : [
                                    Colors.white, 
                                    Colors.transparent, 
                                    Colors.transparent, 
                                    Colors.white
                                  ],
                              stops: [0.0, 0.03, 0.97, 1.0], // More pronounced fade effect
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.dstOut,
                          child: ListView.builder(
                            controller: _tagsScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: uniqueTags.length + 1, // +1 for the extra padding at the end
                            itemBuilder: (context, index) {
                              if (index == uniqueTags.length) {
                                // Last item is just padding
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Container(width: 8.0),
                                );
                              }
                              
                              final tag = uniqueTags.elementAt(index);
                              final isSelected = selectedTags.contains(tag);
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => _toggleTag(tag),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16), // Reduced vertical padding from 8 to 4
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                        ? Color(0xFF6C5CE7) 
                                        : themeProvider.isDarkMode 
                                          ? Colors.grey.shade800 
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center( // Added Center widget to ensure vertical centering
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          color: isSelected 
                                            ? Colors.white 
                                            : themeProvider.isDarkMode 
                                              ? Colors.white.withOpacity(0.9) 
                                              : Colors.black87,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                ),
              ),
              
              // Cards list
              Expanded(
                child: Stack(
                  children: [
                    // Main content
                    RefreshIndicator(
                      onRefresh: _refreshCards,
                      child: _isLoading 
                        ? Center(child: CircularProgressIndicator())
                        : filteredCards.isEmpty
                          ? Center(child: Text(
                              'No cards found',
                              style: TextStyle(
                                fontSize: 16, 
                                color: themeProvider.isDarkMode 
                                  ? Colors.white.withOpacity(0.7) 
                                  : Colors.grey.shade600
                              )
                            ))
                          : SingleChildScrollView(
                              physics: AlwaysScrollableScrollPhysics(),
                              child: Container(
                                color: Colors.transparent,
                                padding: EdgeInsets.only(top: 16, bottom: 100),
                                // Calculate height based on cards and their expanded state
                                height: filteredCards.fold<double>(0, (height, card) {
                                  // Calculate dynamic height based on content
                                  double cardHeight = _calculateCardHeight(
                                    card, 
                                    MediaQuery.of(context).size.width - 40
                                  );
                                  // Add spacing between cards - scaled based on task count
                                  double spacing = 16.0; // Adjusted spacing
                                  if (card.tasks.length <= 2) {
                                    spacing = 12.0; // Smaller spacing for cards with fewer tasks
                                  } else if (card.tasks.length >= 7) {
                                    spacing = 20.0; // Larger spacing for cards with many tasks
                                  }
                                  
                                  // Add extra height for expanded cards to ensure proper spacing
                                  if (expandedCards.contains(card.id)) {
                                    spacing += 10.0;
                                    
                                    // Add extra spacing for calorie tracker cards
                                    if (card.metadata?['type'] == 'calorie_tracker') {
                                      spacing += 20.0;
                                    }
                                  }
                                  
                                  return height + cardHeight + spacing;
                                }) + 150.0, // Extra space at the bottom to ensure the last card is fully visible
                                child: Stack(
                                  children: filteredCards.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    var card = entry.value;
                                    bool isExpanded = expandedCards.contains(card.id);
                                    
                                    return buildCard(context, card, index, isExpanded);
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: currentPage,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8,
        color: themeProvider.isDarkMode ? DarkThemeColors.cardColor : Colors.white,
        elevation: themeProvider.isDarkMode ? 0 : 8,
        height: 60,
        child: Container(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home button
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.home,
                        color: _selectedIndex == 0 
                          ? LightThemeColors.primaryColor 
                          : themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                      ),
                      onPressed: () => _onItemTapped(0),
                      tooltip: 'Home',
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
              
              // Space for FAB
              SizedBox(width: 80),
              
              // Settings button
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: _selectedIndex == 2 
                          ? LightThemeColors.primaryColor 
                          : themeProvider.isDarkMode ? Colors.white70 : Colors.grey.shade600,
                      ),
                      onPressed: () => _onItemTapped(2),
                      tooltip: 'Settings',
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: LightThemeColors.primaryColor.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _onItemTapped(1),
          backgroundColor: LightThemeColors.primaryColor,
          child: Image.asset(
            'assets/images/app_icon.png', // Replace with your actual app icon path
            color: Colors.white,
            width: 42,
            height: 42,
          ),
          elevation: 4.0,
          tooltip: 'Add New Card',
          shape: CircleBorder(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget buildCard(BuildContext context, CardModel card, int index, bool isExpanded) {
    // Calculate vertical position based on index and expanded state
    double top = 0;
    if (index > 0) {
      // Calculate positions based on previous cards' actual heights
      for (int i = 0; i < index; i++) {
        CardModel prevCard = filteredCards[i];
        bool isPrevExpanded = expandedCards.contains(prevCard.id);
        
        // Base offset depends on whether previous card is expanded and its task count
        if (isPrevExpanded) {
          // Use the calculated height for expanded cards
          double cardHeight = _calculateCardHeight(
            prevCard,
            MediaQuery.of(context).size.width - 40
          );
          top += cardHeight;
        } else {
          // For collapsed cards, use a formula based on task count
          top += 60.0 + (prevCard.tasks.length > 5 ? 15.0 : 
                        prevCard.tasks.length > 2 ? 10.0 : 5.0);
        }
        
        // Add spacing between cards based on task count
        if (prevCard.tasks.length <= 3) {
          top += -2.0;  // Adjusted from 8.0
        } else if (prevCard.tasks.length > 3 && prevCard.tasks.length <= 6) {
          top += -4.0;  // Adjusted from 10.0
        } else {
          top += -6.0;  // Adjusted from 12.0
        }
        
        // Add extra spacing after calorie tracker card to prevent overlap
        if (prevCard.metadata?['type'] == 'calorie_tracker' && isPrevExpanded) {
          top +=75.0;  // Add extra spacing specifically for expanded calorie tracker card
        }
      }
    }
    
    // Determine card background color based on card type
    Color cardColor = Colors.white;
    if (card.metadata?['type'] == 'water_intake') {
      cardColor = Color(0xFF48dbfb).withOpacity(0.9); // Light blue for water intake
    } else if (card.metadata?['type'] == 'top_priorities') {
      cardColor = Color(0xFFff7675).withOpacity(0.9); // Light red for priorities
    } else if (card.metadata?['type'] == 'calorie_tracker') {
      cardColor = Color(0xFFffeaa7).withOpacity(0.9); // Light yellow for calorie
    } else if (card.metadata?['type'] == 'expense_tracker') {
      cardColor = Color(0xFF55efc4).withOpacity(0.9); // Light green for expense
    } else if (card.metadata?['type'] == 'mood_gratitude') {
      cardColor = Color(0xFFa29bfe).withOpacity(0.9); // Light purple for mood
    }
    
    // Determine card content based on type
    Widget cardContent;
    
    // Special card content for different card types
    if (card.metadata?['type'] == 'water_intake') {
      cardContent = WaterIntakeCard(
        cardId: card.id,
        metadata: WaterIntakeMetadata.fromJson(card.metadata!),
        onTapSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WaterIntakePage(
                cardId: card.id,
                metadata: card.metadata,
                onMetadataChanged: (updatedMetadata) {
                  _updateCardMetadata(card.id, updatedMetadata);
                },
              ),
            ),
          );
        },
        isExpanded: expandedCards.contains(card.id),
        onExpandChanged: (expanded) {
          toggleCard(card.id);
        },
      );
    } else if (card.metadata?['type'] == 'top_priorities' && isExpanded) {
      cardContent = TopPrioritiesCardContent(
        metadata: card.metadata ?? {},
        cardId: card.id,
        onMetadataChanged: (updatedMetadata) async {
          try {
            await _updateCardMetadata(card.id, updatedMetadata);
          } catch (e) {
            print('Error updating top priorities metadata: $e');
          }
        },
      );
    } else if (card.metadata?['type'] == 'calorie_tracker' && isExpanded) {
      cardContent = CalorieTrackerCardContent(
        cardId: card.id,
        metadata: card.metadata ?? {},
        onMetadataChanged: (updatedMetadata) async {
          try {
            await _updateCardMetadata(card.id, updatedMetadata);
          } catch (e) {
            print('Error updating calorie tracker metadata: $e');
          }
        },
      );
    } else if (card.metadata?['type'] == 'expense_tracker' && isExpanded) {
      // Use our new DailyExpenseTrackerCard
      cardContent = DailyExpenseTrackerCard(
        cardId: card.id,
        metadata: card.metadata ?? {},
        onMetadataChanged: (updatedMetadata) async {
          try {
            await _updateCardMetadata(card.id, updatedMetadata);
          } catch (e) {
            print('Error updating expense tracker metadata: $e');
          }
        },
        onSnapReceipt: () {
          // Navigate to camera for receipt capture
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageCapturePage(
                onCardCreated: (cardData) async {
                  // Process the receipt image (OCR would be implemented here)
                  // For now, just add a placeholder expense
                  final imagePath = cardData['imagePath'] as String?;
                  
                  final newExpense = ExpenseEntry(
                    id: Uuid().v4(),
                    amount: 15.99,
                    category: 'Food',
                    description: 'Receipt Scan',
                    receiptImageUrl: imagePath,
                    timestamp: DateTime.now(),
                  );
                  
                  // Add the new expense to the card metadata
                  final updatedMetadata = Map<String, dynamic>.from(card.metadata ?? {});
                  final expenses = List<Map<String, dynamic>>.from(updatedMetadata['expenses'] ?? []);
                  expenses.add(newExpense.toMap());
                  updatedMetadata['expenses'] = expenses;
                  
                  // Update the card
                  await _updateCardMetadata(card.id, updatedMetadata);
                },
              ),
            ),
          );
        },
        onAddManualEntry: () {
          // Show dialog to add manual expense entry
          _showAddExpenseDialog(context, card);
        },
        onDeleteEntry: (expense) async {
          // Delete the expense entry
          final updatedMetadata = Map<String, dynamic>.from(card.metadata ?? {});
          final expenses = List<Map<String, dynamic>>.from(updatedMetadata['expenses'] ?? []);
          expenses.removeWhere((e) => e['id'] == expense.id);
          updatedMetadata['expenses'] = expenses;
          
          // Update the card
          await _updateCardMetadata(card.id, updatedMetadata);
        },
        onToggleReminder: (enabled) async {
          // This functionality is now controlled from settings page
          // We'll keep the method for compatibility but it won't be used in the UI
          // The reminders state is still stored in the card metadata for future use
          final updatedMetadata = Map<String, dynamic>.from(card.metadata ?? {});
          final reminders = Map<String, dynamic>.from(updatedMetadata['reminders'] ?? {});
          reminders['enabled'] = enabled;
          updatedMetadata['reminders'] = reminders;
          
          // Update the card
          await _updateCardMetadata(card.id, updatedMetadata);
        },
      );
    } else if (card.metadata?['type'] == 'mood_gratitude' && isExpanded) {
      // For mood & gratitude, we'll use a generic task list for now
      cardContent = _buildTaskList(context, card);
    } else {
      // Default task list for regular cards
      cardContent = isExpanded ? _buildTaskList(context, card) : Container();
    }
    
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: MediaQuery.of(context).size.width - 32,
        constraints: BoxConstraints(
          minHeight: isExpanded ? 
            (card.metadata?['type'] == 'water_intake' ? 700.0 :
             card.metadata?['type'] == 'top_priorities' ? 600.0 :
             card.metadata?['type'] == 'calorie_tracker' ? 980.0 :
             card.metadata?['type'] == 'expense_tracker' ? 680.0 :
             card.metadata?['type'] == 'mood_gratitude' ? 750.0 :
             200.0 + card.tasks.length * 60.0) : 
            180.0,
        ),
        margin: EdgeInsets.only(bottom: card.metadata?['type'] == 'calorie_tracker' && isExpanded ? 20.0 : 8.0),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header - This is the only part that will be tappable to expand/collapse
            Stack(
              children: [
                GestureDetector(
                  onTap: () => toggleCard(card.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add some top padding for the pin icon when it's pinned
                      SizedBox(height: card.isFavorited ? 15 : 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              card.title,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Expand/collapse indicator
                              Container(
                                padding: EdgeInsets.all(4),
                                margin: EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade700,
                                  size: 20,
                                ),
                              ),
                              if (!card.isFavorited)
                                GestureDetector(
                                  onTap: () {
                                    // Prevent the card from toggling
                                    _togglePinCard(card);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    margin: EdgeInsets.only(right: 12.0),
                                    child: Icon(
                                      Icons.push_pin_outlined,
                                      color: Colors.grey.shade700,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () {
                                  // Prevent the card from toggling
                                  _openEditPage(card);
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    Icons.more_horiz,
                                    color: Colors.grey.shade700,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Show task count and progress only for regular cards
                      if (card.metadata == null || 
                          (card.metadata?['type'] != 'water_intake' && 
                           card.metadata?['type'] != 'top_priorities' && 
                           card.metadata?['type'] != 'calorie_tracker' && 
                           card.metadata?['type'] != 'expense_tracker' && 
                           card.metadata?['type'] != 'mood_gratitude'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${card.tasks.length} TODOs',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                card.progress,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Show date only for regular cards
                      if (card.metadata == null || 
                          (card.metadata?['type'] != 'water_intake' && 
                           card.metadata?['type'] != 'top_priorities' && 
                           card.metadata?['type'] != 'calorie_tracker' && 
                           card.metadata?['type'] != 'expense_tracker' && 
                           card.metadata?['type'] != 'mood_gratitude'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(card.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Pin icon for favorited cards
                if (card.isFavorited)
                  Positioned(
                    top: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _togglePinCard(card),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.push_pin,
                            size: 22,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Card Content - This part won't be tappable to expand/collapse
            if (isExpanded)
              Padding(
                padding: EdgeInsets.only(
                  top: (card.metadata != null && 
                        (card.metadata?['type'] == 'water_intake' || 
                         card.metadata?['type'] == 'top_priorities' || 
                         card.metadata?['type'] == 'calorie_tracker' || 
                         card.metadata?['type'] == 'expense_tracker' || 
                         card.metadata?['type'] == 'mood_gratitude')) ? 16.0 : 16.0
                ),
                child: cardContent,
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to build task list for regular cards
  Widget _buildTaskList(BuildContext context, CardModel card) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: card.tasks.map<Widget>((task) {
          return Container(
            margin: EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () => _toggleTaskCompletion(task),
              borderRadius: BorderRadius.circular(8),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: _buildTaskItem(context, task),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Adapter method to convert from CardModel to String for template cards
  void _handleCardSelection(dynamic card) async {
    print('_handleCardSelection called with card ID: ${card.id}');
    
    // Check if this is a template card (starts with template_)
    if (card.id.startsWith('template_')) {
      // Handle template card selection
      String templateType;
      
      // Map the template ID to the corresponding card type
      if (card.id == 'template_water') {
        templateType = 'water_intake';
      } else if (card.id == 'template_priorities') {
        templateType = 'top_priorities';
      } else if (card.id == 'template_expense') {
        templateType = 'expense_tracker';
      } else if (card.id == 'template_fitness') {
        templateType = 'fitness_tracker';
      } else if (card.id == 'template_sleep') {
        templateType = 'sleep_tracker';
      } else if (card.id == 'template_mood') {
        templateType = 'mood_tracker';
      } else {
        templateType = 'generic';
      }
      
      // Add the template card
      _addTemplateCard(templateType);
    } else {
      // This is a newly created or edited card
      // For top priority cards, get the latest data to ensure task deletions are reflected
      if (card.metadata?['type'] == 'top_priorities') {
        try {
          // Get fresh card data from database to ensure deleted todos are not shown
          final freshCard = await CardService.getCardById(card.id);
          if (freshCard != null) {
            card = freshCard;
          }
        } catch (e) {
          print('Error refreshing top priority card: $e');
        }
      }
      
      setState(() {
        // Check if the card already exists in our list
        int existingIndex = cards.indexWhere((c) => c.id == card.id);
        
        if (existingIndex != -1) {
          // Update existing card with new data
          cards[existingIndex] = card;
        } else {
          // Add the new card to the list
          cards.add(card);
          
          // Sort cards to ensure special cards are at the top
          _sortCards();
        }
        
        // Expand the card in the UI
        expandedCards.add(card.id);
      });
    }
  }

  // Method to show dialog for adding a manual expense entry
  void _showAddExpenseDialog(BuildContext context, CardModel card) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedCategory = 'Food';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Amount field
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description field
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: ExpenseCategories.categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category.name,
                          child: Row(
                            children: [
                              Icon(category.icon, color: category.color, size: 20),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    // Validate input
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    
                    final description = descriptionController.text.trim();
                    if (description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a description')),
                      );
                      return;
                    }
                    
                    // Create new expense entry
                    final newExpense = ExpenseEntry(
                      id: Uuid().v4(),
                      amount: amount,
                      category: selectedCategory,
                      description: description,
                      timestamp: DateTime.now(),
                    );
                    
                    // Add to card metadata
                    final updatedMetadata = Map<String, dynamic>.from(card.metadata ?? {});
                    final expenses = List<Map<String, dynamic>>.from(updatedMetadata['expenses'] ?? []);
                    expenses.add(newExpense.toMap());
                    updatedMetadata['expenses'] = expenses;
                    
                    // Update card
                    try {
                      await _updateCardMetadata(card.id, updatedMetadata);
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error adding expense: $e')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Method to update card metadata
  Future<void> _updateCardMetadata(String cardId, Map<String, dynamic> updatedMetadata) async {
    try {
      // Update card metadata in the database
      await CardService.updateCardMetadata(cardId, updatedMetadata);
      
      // Update the card locally without refreshing the entire stack
      if (mounted) {
        setState(() {
          // Find and update just this card in the list
          final index = cards.indexWhere((c) => c.id == cardId);
          if (index != -1) {
            // Create a new card with updated metadata
            final updatedCard = CardModel.fromMap({
              ...cards[index].toMap(),
              'metadata': updatedMetadata,
            });
            cards[index] = updatedCard;
          }
        });
      }
    } catch (e) {
      print('Error updating card metadata: $e');
      rethrow; // Rethrow to handle in the calling method
    }
  }

  // Helper method to consistently sort cards
  void _sortCards() {
    // Sort cards to ensure special cards are at the top
    // and regular cards at the bottom (with newest regular cards at the top of the regular cards section)
    cards.sort((a, b) {
      // Special cards come before regular cards
      final aIsSpecial = a.metadata != null && a.metadata!['type'] != null;
      final bIsSpecial = b.metadata != null && b.metadata!['type'] != null;
      
      if (aIsSpecial && !bIsSpecial) return -1;
      if (!aIsSpecial && bIsSpecial) return 1;
      
      // Sort special cards by type to keep them in consistent order
      if (aIsSpecial && bIsSpecial) {
        // Define the order of special card types
        final specialCardTypes = ['top_priorities', 'water_intake', 'expense_tracker', 
                                 'fitness_tracker', 'sleep_tracker', 'mood_tracker'];
        
        final aType = a.metadata!['type'] as String;
        final bType = b.metadata!['type'] as String;
        
        final aIndex = specialCardTypes.indexOf(aType);
        final bIndex = specialCardTypes.indexOf(bType);
        
        // If both types are in our predefined list, sort by their order
        if (aIndex != -1 && bIndex != -1) {
          return aIndex.compareTo(bIndex);
        }
        
        // If one type is not in our list, the one in the list comes first
        if (aIndex != -1) return -1;
        if (bIndex != -1) return 1;
      }
      
      // If both are special cards of the same type or both are regular cards, 
      // sort by date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}