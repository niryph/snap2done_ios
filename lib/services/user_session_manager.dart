import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSession {
  final String? token;
  final DateTime? expiryDate;
  final User? user;
  
  UserSession({this.token, this.expiryDate, this.user});
  
  bool get isValid {
    return user != null && (token != null && token!.isNotEmpty) && 
           (expiryDate != null && expiryDate!.isAfter(DateTime.now()));
  }
}

class UserSessionManager {
  static final UserSessionManager instance = UserSessionManager._internal();
  static final _supabase = Supabase.instance.client;
  
  UserSessionManager._internal();
  
  Future<UserSession?> get currentSession async {
    try {
      // Get Supabase session
      final supabaseSession = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;
      
      // If we have a valid Supabase session, use that
      if (supabaseSession != null && user != null) {
        print("Supabase session found, creating UserSession");
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(
          supabaseSession.expiresAt! * 1000 // Convert seconds to milliseconds
        );
        return UserSession(
          token: supabaseSession.accessToken,
          expiryDate: expiryDate,
          user: user
        );
      } else {
        print("No Supabase session found, checking local storage");
        // Fallback to shared preferences if no Supabase session
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('userToken');
        final expiryMs = prefs.getInt('tokenExpiryDate');
        
        if (token != null && token.isNotEmpty && expiryMs != null) {
          final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryMs);
          return UserSession(token: token, expiryDate: expiryDate);
        }
      }
      
      // No valid session found
      print("No valid session found");
      return null;
    } catch (e) {
      print('Error retrieving user session: $e');
      return null;
    }
  }
  
  Future<void> signOut() async {
    try {
      // Sign out from Supabase
      await _supabase.auth.signOut();
      print("Signed out from Supabase");
    } catch (e) {
      print("Error signing out from Supabase: $e");
    }
    
    // Clear local session data as well
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userToken');
      await prefs.remove('tokenExpiryDate');
      print("Cleared local session data");
    } catch (e) {
      print("Error clearing local session: $e");
    }
  }
  
  Future<void> saveSession({required String token, required DateTime expiryDate}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userToken', token);
      await prefs.setInt('tokenExpiryDate', expiryDate.millisecondsSinceEpoch);
      print("Saved session to local storage");
    } catch (e) {
      print("Error saving session: $e");
    }
  }

  // For testing/debugging: clear any existing session data
  Future<void> clearSession() async {
    await signOut();
  }
}
