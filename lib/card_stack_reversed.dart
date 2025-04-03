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
import 'package:provider/provider.dart' as provider_pkg; // Import Provider
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
import 'constants/card_constants.dart';
import 'features/mood_gratitude/pages/mood_gratitude_log_page.dart'; // Import MoodGratitudeLogPage

class CardStackReversed extends StatefulWidget {
  const CardStackReversed({super.key});

  @override
  _CardStackReversedState createState() => _CardStackReversedState();
}

class _CardStackReversedState extends State<CardStackReversed> {
  List<CardModel> cards = [];
  Set<String> uniqueTags = {'All'};
  Set<String> selectedTags = {'All'};
  bool isLoading = true;
  String? error;
  Timer? _debounceTimer;
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();
  FocusNode _searchFocusNode = FocusNode();
  bool _showSearchBar = false;
  String _searchText = '';
  String _sortOption = 'Newest';
  ScrollController _tagsScrollController = ScrollController();
  int _selectedIndex = 0;
  final _uuid = Uuid(); // Add this line to define _uuid
  
  // Get filtered cards based on search and tags
  List<CardModel> get _filteredCards {
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
  
  @override
  void initState() {
    super.initState();
    _loadCards();
  }
  
  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  // Load cards from database
  Future<void> _loadCards() async {
    print("_loadCards called");
    
    if (mounted) {
    setState(() {
      isLoading = true;
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
        isLoading = false;
        
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
          // expandedCards.clear();
          
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
        isLoading = false;
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
    print("Navigating to card: $id");
    // Find the card by id
    final card = cards.firstWhere((card) => card.id == id);
    
    // Navigate to the appropriate page based on card type
    if (card.metadata?['type'] == 'calorie_tracker') {
      print("Opening CalorieTrackerPage for card: ${card.id}");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalorieTrackerPage(
            userId: Supabase.instance.client.auth.currentUser!.id,
            cardId: card.id,
            metadata: card.metadata,
            onMetadataChanged: (newMetadata) {
              onCardMetadataChanged(card.id, newMetadata);
            },
          ),
        ),
      );
    } else if (card.metadata?['type'] == 'water_intake') {
      print('CardStackReversed: Opening WaterIntakePage');
      // Open the water intake page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaterIntakePage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            onMetadataChanged: (newMetadata) {
              onCardMetadataChanged(card.id, newMetadata);
            },
          ),
        ),
      );
    } else if (card.metadata?['type'] == 'expense_tracker') {
      print('CardStackReversed: Opening ExpenseTrackerPage');
      // Open the expense tracker page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpenseTrackerPage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            onMetadataChanged: (newMetadata) {
              onCardMetadataChanged(card.id, newMetadata);
            },
          ),
        ),
      );
    } else if (card.metadata?['type'] == 'mood_gratitude') {
      print('CardStackReversed: Opening MoodGratitudeLogPage');
      // Open the mood & gratitude log page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MoodGratitudeLogPage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            onMetadataChanged: (newMetadata) {
              onCardMetadataChanged(card.id, newMetadata);
            },
          ),
        ),
      );
    } else if (card.metadata?['type'] == 'top_priorities') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TopPrioritiesPage(
            cardId: card.id,
            metadata: card.metadata ?? {},
            isEditing: true,
            onSave: (updatedMetadata) async {
              try {
                // Update card metadata in database first
                await CardService.updateCardMetadata(card.id, updatedMetadata);
                
                // Only update state if the widget is still mounted
                if (mounted) {
                  setState(() {
                    final index = cards.indexWhere((c) => c.id == card.id);
                    if (index != -1) {
                      cards[index] = CardModel.fromMap({
                        ...cards[index].toMap(),
                        'metadata': updatedMetadata,
                      });
                    }
                  });
                }
                return card.id; // Return the card ID
              } catch (e) {
                print('Error updating top priorities metadata: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating top priorities: $e')),
                  );
                }
                throw e; // Re-throw to handle in the page
              }
            },
          ),
        ),
      );
    } else {
      // For regular todo cards, open in view mode
      print('CardStackReversed: Opening ReviewTodoListPage in view mode');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewTodoListPage(
            ocrText: '', // Empty since we're viewing an existing card
            initialResult: card.toUiMap(), // Convert CardModel to Map for backward compatibility
            isViewMode: true, // Add this flag to indicate view mode
            onSaveCard: (updatedCard) async {
              try {
                // Make sure we preserve the original color format
                if (updatedCard.containsKey('color') && updatedCard['color'] is String) {
                  // String color value from edit page
                  print('Updating card with color: ${updatedCard['color']}');
                } else if (updatedCard.containsKey('color')) {
                  // Convert int color to string if needed
                  updatedCard['color'] = '0x${updatedCard['color'].toString().padLeft(8, '0')}';
                  print('Converted color to string: ${updatedCard['color']}');
                }
                
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
          ),
        ),
      );
    }
  }

  // Helper method to update card metadata
  void _updateCardMetadata(String cardId, Map<String, dynamic> updatedMetadata) {
    setState(() {
      final index = cards.indexWhere((card) => card.id == cardId);
      if (index != -1) {
        // Create a new card with updated metadata instead of directly setting the property
        final updatedCard = CardModel.fromMap({
          ...cards[index].toMap(),
          'metadata': updatedMetadata,
        });
        cards[index] = updatedCard;
        CardService.updateCardMetadata(cardId, updatedMetadata);
      }
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
                isLoading = true;
              });
              
              // Add the new card to the database and get the saved card
              final savedCard = await _addNewCard(cardData);
              
              // Update the UI with the new card without a full refresh
              setState(() {
                isLoading = false;
                
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
                isLoading = false;
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
      // Validate required fields
      if (newCard['title'] == null || newCard['title'].toString().trim().isEmpty) {
        throw Exception("Card title cannot be empty");
      }
      
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
            // expandedCards.remove(cardId);
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
        // expandedCards.add(savedCard.id);
        
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
                // final expandedCardIds = Set<String>.from(expandedCards);
                cards = updatedCards;
                // expandedCards = expandedCardIds;
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
  void _openEditPage(CardModel card) {
    print('Opening edit page for card: ${card.id}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewTodoListPage(
          ocrText: '',
          initialResult: card.toUiMap(),
          onSaveCard: (updatedCard) async {
            try {
              if (updatedCard['deleted'] == true) {
                // Handle deletion
                await CardService.deleteCard(card.id);
                setState(() {
                  cards.removeWhere((c) => c.id == card.id);
                  // Update tags
                  final tags = {'All'};
                  for (final card in cards) {
                    tags.addAll(card.tags);
                  }
                  uniqueTags = tags;
                });
              } else {
                // Handle update
                final savedCard = await CardService.updateCard(updatedCard);
                setState(() {
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
              }
            } catch (e) {
              print('Error updating/deleting card: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating/deleting card: $e')),
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
        isLoading = true;
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
          isLoading = false;
          
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
          // expandedCards.clear();
          
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
          isLoading = false;
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
  Future<CardModel?> _addTemplateCard(String templateType) async {
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
          // Show a message to the user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You already have a Hydration Tracker card'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        });
        
        return null; // Return null instead of empty return
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
      }
      
      return null; // Return null instead of empty return
    } else if (templateType == 'top_priorities') {
      // Check for existing top priorities cards
      final existingTopPriorityCards = cards.where((card) => 
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
                  
                  // Only update state if the widget is still mounted
                  if (mounted) {
                    setState(() {
                      final index = cards.indexWhere((c) => c.id == existingCard.id);
                      if (index != -1) {
                        cards[index] = CardModel.fromMap({
                          ...cards[index].toMap(),
                          'metadata': updatedMetadata,
                        });
                      }
                    });
                  }
                  return existingCard.id;
                } catch (e) {
                  print('Error updating top priorities metadata: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating top priorities: $e')),
                    );
                  }
                  throw e; // Re-throw to handle in the page
                }
              },
            ),
          ),
        );
        return null; // Return null instead of empty return
      }

      // Create new top priorities card
      final cardData = {
        'id': _uuid.v4(),
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'title': 'Daily Top 3 Priorities',
        'description': 'Focus on your most important tasks',
        'color': '0xFFE53935',
        'tags': ['Productivity'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'metadata': TopPrioritiesModel.createDefaultMetadata(),
      };

      try {
        // Create card and add to state in a single operation
        final newCard = await CardService.createCard(cardData, notifyListeners: false);
        setState(() {
          cards.insert(0, newCard);
        });
        
        // Open the TopPrioritiesPage for the new card
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopPrioritiesPage(
              cardId: newCard.id,
              metadata: newCard.metadata ?? {},
              isEditing: true,
              onSave: (updatedMetadata) async {
                try {
                  // Update card metadata in database first
                  await CardService.updateCardMetadata(newCard.id, updatedMetadata);
                  
                  // Update local state directly without fetching from database
                  if (mounted) {
                    setState(() {
                      final index = cards.indexWhere((c) => c.id == newCard.id);
                      if (index != -1) {
                        cards[index] = CardModel.fromMap({
                          ...cards[index].toMap(),
                          'metadata': updatedMetadata,
                        });
                      }
                    });
                  }
                  return newCard.id;
                } catch (e) {
                  print('Error updating top priorities metadata: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating top priorities: $e')),
                    );
                  }
                  throw e; // Re-throw to handle in the page
                }
              },
            ),
          ),
        );
        
        return newCard;
      } catch (e) {
        print('Error creating top priorities card: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating top priorities card: $e')),
          );
        }
        return null;
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
          // final expandedMap = Map<String, bool>.fromIterable(
          //   expandedCards, 
          //   key: (card) => card, 
          //   value: (_) => true
          // );
          
          // Update the cards list with the latest data
          cards = latestCards;
          
          // Sort to ensure special cards are at the top
          _sortCards();
          
          // Restore expanded state and ensure top priority cards are expanded
          // expandedCards.clear();
          // for (final card in cards) {
          //   // Restore previous expanded state
          //   if (expandedMap.containsKey(card.id)) {
          //     expandedCards.add(card.id);
          //   }
          //   
          //   // Make sure top priority cards are expanded
          //   if (card.metadata?['type'] == 'top_priorities') {
          //     expandedCards.add(card.id);
          //   }
          // }
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
    print("Is loading: $isLoading");
    
    // Get theme provider
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    
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
                  child: isLoading 
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
                      child: isLoading 
                        ? Center(child: CircularProgressIndicator())
                        : _filteredCards.isEmpty
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
                                height: _filteredCards.fold<double>(0, (height, card) {
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
                                  
                                  return height + cardHeight + spacing;
                                }) + 150.0, // Extra space at the bottom to ensure the last card is fully visible
                                child: Stack(
                                  children: _filteredCards.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    var card = entry.value;
                                    return buildCard(context, card, index);
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

  Widget buildCard(BuildContext context, CardModel card, int index) {
    // Calculate vertical position based on index
    double top = 0;
    if (index > 0) {
      // Calculate positions based on previous cards
      for (int i = 0; i < index; i++) {
        top += CardConstants.CARD_HEIGHT + 8.0; // 8.0 is the standard spacing
      }
    }
    
    // Determine card background color based on card type
    Color cardColor = Colors.white;
    if (card.metadata?['type'] == 'water_intake') {
      cardColor = Color(0xFF48dbfb).withOpacity(0.9);
    } else if (card.metadata?['type'] == 'top_priorities') {
      cardColor = Color(0xFFff7675).withOpacity(0.9);
    } else if (card.metadata?['type'] == 'calorie_tracker') {
      cardColor = Color(0xFFffeaa7).withOpacity(0.9);
    } else if (card.metadata?['type'] == 'expense_tracker') {
      cardColor = Color(0xFF55efc4).withOpacity(0.9);
    } else if (card.metadata?['type'] == 'mood_gratitude') {
      cardColor = Color(0xFFa29bfe).withOpacity(0.9);
    } else {
      // For regular todo cards, use the card's color property
      cardColor = card.getColor();
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
          minHeight: CardConstants.CARD_HEIGHT,
        ),
        margin: EdgeInsets.only(bottom: 8.0),
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
            // Card Header
            Stack(
              children: [
                GestureDetector(
                  onTap: () => toggleCard(card.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: card.isFavorited ? 15 : 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              // Change title for top priorities card
                              card.metadata?['type'] == 'top_priorities' 
                                ? "Today's Top Priorities"
                                : card.title,
                              style: TextStyle(
                                fontSize: card.metadata?['type'] == 'top_priorities' ? 16 : 18,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!card.isFavorited)
                                GestureDetector(
                                  onTap: () {
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
                      // Summary line under title
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _getCardSummary(card),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87.withOpacity(0.7),
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
      } else if (card.id == 'template_calorie') {
        templateType = 'calorie_tracker';
      } else if (card.id == 'template_sleep') {
        templateType = 'sleep_tracker';
      } else if (card.id == 'template_mood') {
        templateType = 'mood_tracker';
      } else {
        templateType = 'generic';
      }
      
      print("Selected template type: $templateType");
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
        // expandedCards.add(card.id);
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
                      _updateCardMetadata(card.id, updatedMetadata);
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

  String _getCardSummary(CardModel card) {
    if (card.metadata?['type'] == 'water_intake') {
      final dailyGoal = card.metadata?['dailyGoal'] ?? 0;
      final currentIntake = card.metadata?['currentIntake'] ?? 0;
      return 'Water intake: ${currentIntake}ml / ${dailyGoal}ml';
    } else if (card.metadata?['type'] == 'top_priorities') {
      try {
        final prioritiesData = card.metadata?['priorities'];
        List<dynamic> priorities = [];
        if (prioritiesData is Map) {
          priorities = prioritiesData.values.toList();
        } else if (prioritiesData is List) {
          priorities = prioritiesData;
        }
        final completedCount = priorities.where((p) => p is Map && p['isCompleted'] == true).length;
        return 'Completed priorities: $completedCount / ${priorities.length}';
      } catch (e) {
        print('Error processing top priorities: $e');
        return 'Priorities: 0 / 0';
      }
    } else if (card.metadata?['type'] == 'calorie_tracker') {
      final dailyGoal = card.metadata?['dailyGoal'] ?? 2000;
      final currentCalories = card.metadata?['currentCalories'] ?? 0;
      return 'Calories: $currentCalories / $dailyGoal kcal';
    } else if (card.metadata?['type'] == 'expense_tracker') {
      try {
        final expenses = (card.metadata?['expenses'] as List? ?? [])
            .where((e) => DateTime.parse(e['timestamp']).day == DateTime.now().day)
            .map((e) => e['amount'] as num)
            .fold(0.0, (sum, amount) => sum + amount);
        return 'Today\'s spending: \$${expenses.toStringAsFixed(2)}';
      } catch (e) {
        print('Error processing expenses: $e');
        return 'Today\'s spending: \$0.00';
      }
    } else if (card.metadata?['type'] == 'mood_gratitude') {
      final todayMood = card.metadata?['todayMood'] ?? 'Not set';
      return 'Today\'s mood: $todayMood';
    } else {
      // For regular cards
      final completedTasks = card.tasks.where((task) => task.isCompleted).length;
      return 'Completed tasks: $completedTasks / ${card.tasks.length} (${card.progress})';
    }
  }

  // Calculate card height based on content
  double _calculateCardHeight(CardModel card, double cardWidth) {
    return CardConstants.CARD_HEIGHT;
  }

  // Add the onCardMetadataChanged method
  Future<void> onCardMetadataChanged(String cardId, Map<String, dynamic> newMetadata) async {
    try {
      print("Updating card metadata for card: $cardId");
      // Update card metadata in database first
      await CardService.updateCardMetadata(cardId, newMetadata);
      
      // Only update state if the widget is still mounted
      if (mounted) {
        setState(() {
          final index = cards.indexWhere((c) => c.id == cardId);
          if (index != -1) {
            cards[index] = CardModel.fromMap({
              ...cards[index].toMap(),
              'metadata': newMetadata,
            });
          }
        });
      }
    } catch (e) {
      print('Error updating card metadata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating card: $e')),
        );
      }
    }
  }
}