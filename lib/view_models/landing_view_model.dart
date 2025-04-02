import 'package:flutter/foundation.dart';
import '../services/user_session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LandingViewModel extends ChangeNotifier {
  bool navigateToMainView = false;
  bool navigateToSignIn = false;
  
  Future<void> checkAuthStatus() async {
    print("========= LandingViewModel.checkAuthStatus() CALLED =========");
    
    // Reset navigation flags
    navigateToMainView = false;
    navigateToSignIn = false;
    
    // DEBUG: Force navigation to sign-in for testing
    final prefs = await SharedPreferences.getInstance();
    final debugMode = prefs.getBool('debug_force_signin') ?? false;
    
    if (debugMode) {
      print("DEBUG MODE: Forcing navigation to sign in page");
      navigateToSignIn = true;
      return;
    }
    
    print("Simulating delay for network call");
    // Simulate network delay (can be removed in production)
    await Future.delayed(Duration(seconds: 1));
    
    try {
      print("Checking user session");
      // Check if user is logged in using your authentication service
      final userSession = await UserSessionManager.instance.currentSession;
      
      // Get the current user from Supabase
      final currentUser = AuthService.currentUser;
      
      print("User session check result: ${userSession != null ? 'Session found' : 'No session'}");
      print("Current Supabase User: $currentUser");
      
      // Detailed logging of user properties
      if (currentUser != null) {
        print("User ID: ${currentUser.id}");
        print("User Email: ${currentUser.email}");
        print("Last Sign-In: ${currentUser.lastSignInAt}");
        
        // Check if email is confirmed using Supabase's method
        final isEmailConfirmed = currentUser.emailConfirmedAt != null;
        print("Email Confirmed: $isEmailConfirmed");
      }
      
      if (userSession != null && userSession.isValid) {
        // Check if email is confirmed
        final isEmailConfirmed = currentUser?.emailConfirmedAt != null;
        
        if (isEmailConfirmed) {
          print("User has valid session and confirmed email, navigating to main view");
          navigateToMainView = true;
        } else {
          print("User session valid but email not confirmed, navigating to sign in");
          navigateToSignIn = true;
        }
      } else {
        print("No valid session, navigating to sign in");
        navigateToSignIn = true;
      }
    } catch (e) {
      // If there's an error checking auth, default to sign in
      navigateToSignIn = true;
      print('Error checking authentication: $e');
    }
    
    print("Auth check complete. Navigate to Main: $navigateToMainView, Navigate to SignIn: $navigateToSignIn");
    
    // Notify listeners about the navigation state
    notifyListeners();
  }
}
