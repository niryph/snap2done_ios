import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart' show navigatorKey;
import '../views/main_view.dart';

enum Screen {
  landing,
  signIn,
  main,
}

class NavigationState extends ChangeNotifier {
  // Always start with landing screen
  Screen _currentScreen = Screen.landing;
  bool _isSigningOut = false;
  Timer? _navigationTimer;
  int _navigationEventCounter = 0;
  
  NavigationState() {
    debugPrint("[NAV-DEBUG] ========= NavigationState INITIALIZED with screen: $_currentScreen =========");
    debugPrint("[NAV-DEBUG] Navigator key valid: ${navigatorKey != null}");
  }
  
  Screen get currentScreen => _currentScreen;
  
  void _cancelPendingNavigation() {
    _navigationTimer?.cancel();
    _navigationTimer = null;
  }
  
  // Reset to landing view (useful for sign-out or app restart)
  void resetToLanding() {
    _navigationEventCounter++;
    _cancelPendingNavigation();
    _isSigningOut = true;
    
    _currentScreen = Screen.landing;
    _forceNavigationClear(_navigationEventCounter);
    
    notifyListeners();
    
    _navigationTimer = Timer(Duration(milliseconds: 1000), () {
      _isSigningOut = false;
      notifyListeners();
      
      Future.delayed(Duration(milliseconds: 100), () {
        if (_currentScreen == Screen.landing) {
          notifyListeners();
        }
      });
    });
  }
  
  // Helper method to clear the navigation stack
  void _forceNavigationClear(int eventId) {
    if (navigatorKey.currentState != null && navigatorKey.currentContext != null) {
      Navigator.of(navigatorKey.currentContext!, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    }
  }
  
  void navigateToSignIn() {
    _navigationEventCounter++;
    _cancelPendingNavigation();
    
    if (_currentScreen != Screen.signIn && !_isSigningOut) {
      _currentScreen = Screen.signIn;
      notifyListeners();
    }
  }
  
  void navigateToMain() {
    _navigationEventCounter++;
    _cancelPendingNavigation();
    
    _currentScreen = Screen.main;
    notifyListeners();
    
    _navigationTimer = Timer(Duration(milliseconds: 500), () {
      if (_currentScreen == Screen.main && !_isSigningOut) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => MainView()),
            (route) => false
          );
        }
        notifyListeners();
      }
    });
  }
  
  @override
  void dispose() {
    debugPrint("[NAV-DEBUG] Disposing NavigationState");
    _cancelPendingNavigation();
    super.dispose();
  }
}
