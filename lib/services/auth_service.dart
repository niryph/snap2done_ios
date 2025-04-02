// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config_service.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:uuid/uuid.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';  // Add this import for StreamSubscription
import 'package:crypto/crypto.dart';
import '../main.dart' show navigatorKey;
import 'package:provider/provider.dart' as provider_pkg;
import '../app/navigation_state.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final supabase = Supabase.instance.client;
  
  // Get redirect URL based on platform and app bundle ID
  static String get _redirectUrl {
    // Determine the most appropriate redirect URL
    if (kIsWeb) {
      debugPrint('[AUTH-DEBUG] Using web redirect URL');
      return 'https://hbqptvpyvjrfggeqfuav.supabase.co/auth/v1/callback';
    }
    
    // For iOS, use the bundle ID format
    if (Platform.isIOS) {
      final redirectUrl = 'com.niryph.snap2done://auth/callback';
      debugPrint('[AUTH-DEBUG] Using iOS bundle redirect URL: $redirectUrl');
      return redirectUrl;
    }
    
    final redirectUrl = 'snap2done://auth/callback';
    debugPrint('[AUTH-DEBUG] Using mobile redirect URL: $redirectUrl');
    return redirectUrl;
  }
  
  // Get iOS-specific redirect URL - keeping this for backward compatibility
  static String get _iosRedirectUrl {
    return 'com.niryph.snap2done://login-callback/';
  }
  
  /// Get the current authenticated user
  static User? get currentUser => supabase.auth.currentUser;
  
  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
  
  // Sign in with Apple
  static Future<bool> signInWithApple() async {
    if (!ConfigService.getBool('ENABLE_APPLE_AUTH', defaultValue: true)) {
      throw Exception('Apple authentication is disabled');
    }
    
    try {
      // Generate a secure, random nonce for authentication
      final rawNonce = _generateRandomNonce();
      final nonce = _sha256ofString(rawNonce);
      
      // Step 1: Get credentials from Apple
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.niryph.snap2done.oauth',
          redirectUri: Uri.parse('https://hbqptvpyvjrfggeqfuav.supabase.co/auth/v1/callback'),
        ),
      );
      
      if (credential.identityToken == null) {
        throw Exception('No identity token received from Apple');
      }
      
      // Use the JWT token directly with Supabase's signInWithIdToken
      try {
        final response = await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.apple,
          idToken: credential.identityToken!,
          accessToken: credential.authorizationCode,
          nonce: rawNonce,
        );
        
        // Only continue if session is valid
        if (response.session != null) {
          // If we have a name from Apple (only provided on first sign-in), update the user metadata
          if (credential.givenName != null || credential.familyName != null) {
            final fullName = [
              credential.givenName ?? '',
              credential.familyName ?? ''
            ].where((name) => name.isNotEmpty).join(' ');
            
            if (fullName.isNotEmpty) {
              await supabase.auth.updateUser(
                UserAttributes(
                  data: {
                    'full_name': fullName,
                  },
                ),
              );
            }
          }
          
          return true;
        } else {
          throw Exception('Failed to authenticate with Supabase');
        }
      } catch (signInError) {
        if (signInError.toString().contains('audience')) {
          throw Exception('Authentication configuration error with token audience. Please contact support.');
        } else {
          throw Exception('Authentication failed: ${signInError.toString()}');
        }
      }
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException) {
        if (e.code == AuthorizationErrorCode.canceled) {
          throw Exception('Apple Sign-In was canceled by the user.');
        } else if (e.code == AuthorizationErrorCode.failed) {
          throw Exception('Apple Sign-In failed: ${e.message}');
        } else if (e.code == AuthorizationErrorCode.invalidResponse) {
          throw Exception('Invalid response from Apple Sign-In.');
        } else if (e.code == AuthorizationErrorCode.notHandled) {
          throw Exception('Apple Sign-In request was not handled.');
        } else if (e.code == AuthorizationErrorCode.notInteractive) {
          throw Exception('Apple Sign-In not interactive.');
        } else if (e.code == AuthorizationErrorCode.unknown) {
          throw Exception('Unknown error during Apple Sign-In.');
        }
      } else if (e is PlatformException) {
        if (e.message?.contains('Error while launching') == true) {
          throw Exception('Unable to open sign-in page. Please ensure the app is configured correctly for Apple Sign-In.');
        }
      }
      
      throw Exception('Unable to sign in with Apple. Please try again later.');
    }
  }
  
  /// Generates a cryptographically secure random nonce, used for Apple Sign-In
  static String _generateRandomNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
  
  /// Returns the sha256 hash of [input] in hex notation.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Sign in with Google
  static Future<void> signInWithGoogle() async {
    debugPrint('[OAUTH-DEBUG] Starting Google sign-in process');
    try {
      debugPrint('[OAUTH-DEBUG] Initializing GoogleSignIn');
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: Platform.isIOS ? '652867012511-fnu8nnik2ejttiu4j5tef6m2snaoqa30.apps.googleusercontent.com' : null,
        serverClientId: '652867012511-27hdn24dvl7tnlbs6l74bfqqod0m5lm3.apps.googleusercontent.com',
        scopes: ['email'],
      );

      debugPrint('[OAUTH-DEBUG] Attempting Google sign in');
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('[OAUTH-DEBUG] User cancelled Google sign-in');
        throw Exception('Google sign-in was cancelled by the user');
      }

      debugPrint('[OAUTH-DEBUG] Getting Google auth tokens');
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw Exception('No Access Token found.');
      }
      if (idToken == null) {
        throw Exception('No ID Token found.');
      }

      debugPrint('[OAUTH-DEBUG] Signing in to Supabase with Google tokens');
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.session == null) {
        debugPrint('[OAUTH-DEBUG] Failed to establish session');
        throw Exception('Failed to establish session after Google sign-in');
      }

      debugPrint('[OAUTH-DEBUG] Successfully signed in with Google. User ID: ${response.session!.user.id}');

      // Reset navigation state to main screen after successful sign in
      if (navigatorKey.currentContext != null) {
        provider_pkg.Provider.of<NavigationState>(navigatorKey.currentContext!, listen: false).navigateToMain();
      }

    } catch (error) {
      debugPrint('[OAUTH-ERROR] Error during Google sign-in: $error');
      rethrow;
    }
  }
  
  // Helper method to generate a unique state parameter
  static String _generateUniqueState() {
    // Use a combination of timestamp and random string
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomString = Uuid().v4().substring(0, 8);
    return '$timestamp-$randomString';
  }
  
  // Sign in with Twitter
  static Future<void> signInWithTwitter() async {
    if (!ConfigService.getBool('ENABLE_TWITTER_AUTH', defaultValue: true)) {
      throw Exception('Twitter authentication is disabled');
    }
    
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.twitter,
        redirectTo: _redirectUrl,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sign in with email and password
  static Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // Check email confirmation status
      final user = response.user;
      if (user != null && user.emailConfirmedAt == null) {
        // Sign out to prevent partial login
        await supabase.auth.signOut();
        
        // Throw a specific exception for unconfirmed email
        throw Exception('Email not confirmed. Please check your inbox and verify your email.');
      }
      
      return response;
    } catch (e) {
      if (e is Exception && e.toString().contains('Email not confirmed')) {
        throw Exception('Please verify your email before logging in. Check your inbox for the verification link.');
      }
      
      rethrow;
    }
  }
  
  /// Sign up with email and password
  static Future<AuthResponse> signUpWithEmail(String email, String password, {String? username, String? fullName}) async {
    try {
      debugPrint('[AUTH-DEBUG] Starting email signup process');
      debugPrint('[AUTH-DEBUG] Platform: ${Platform.operatingSystem}');
      debugPrint('[AUTH-DEBUG] Is Web: $kIsWeb');
      
      final redirectUrl = _redirectUrl;
      debugPrint('[AUTH-DEBUG] Using redirect URL: $redirectUrl');
      
      final data = {
        'username': username ?? email.split('@').first,
        'full_name': fullName,
        'email': email,
      };
      debugPrint('[AUTH-DEBUG] User data for signup: $data');
      
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
        data: data,
      );
      
      debugPrint('[AUTH-DEBUG] Sign up response - User: ${response.user?.id}');
      debugPrint('[AUTH-DEBUG] Sign up response - Session: ${response.session != null}');
      debugPrint('[AUTH-DEBUG] Email confirmation status: ${response.user?.emailConfirmedAt}');
      
      if (response.user != null) {
        debugPrint('[AUTH-DEBUG] User created successfully, awaiting email verification');
      } else {
        debugPrint('[AUTH-DEBUG] User creation failed or returned null user');
      }
      
      return response;
      
    } catch (e) {
      debugPrint('[AUTH-ERROR] Sign up error: $e');
      if (e is AuthException) {
        debugPrint('[AUTH-ERROR] AuthException message: ${e.message}');
        debugPrint('[AUTH-ERROR] AuthException statusCode: ${e.statusCode}');
        switch (e.message) {
          case 'User already exists':
            throw Exception('An account with this email already exists.');
          case 'Invalid email':
            throw Exception('Please enter a valid email address.');
          default:
            throw Exception('Sign-up failed: ${e.message}');
        }
      }
      
      rethrow;
    }
  }
  
  // Sign out the current user
  static Future<void> signOut() async {
    try {
      // Clear any cached data or state
      await clearUserData();
      
      // Sign out from Supabase
      await supabase.auth.signOut();
      
      // Add a small delay to ensure cleanup is complete
      await Future.delayed(Duration(milliseconds: 500));
      
      // Reset navigation state to landing
      if (navigatorKey.currentState != null) {
        provider_pkg.Provider.of<NavigationState>(navigatorKey.currentContext!, listen: false).resetToLanding();
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Handle deep link for email verification
  static Future<void> handleDeepLink(Uri uri) async {
    debugPrint('[AUTH-DEBUG] Handling deep link: $uri');
    
    try {
      if (uri.path.contains('auth/verify') || uri.path.contains('callback')) {
        debugPrint('[AUTH-DEBUG] Processing auth verification deep link');
        
        // Extract the verification token if present
        final code = uri.queryParameters['code'];
        if (code != null) {
          debugPrint('[AUTH-DEBUG] Found verification code: $code');
          
          try {
            // Exchange the code for a session
            final response = await supabase.auth.exchangeCodeForSession(code);
            debugPrint('[AUTH-DEBUG] Code exchange successful - Session established');
            
            // Get the current user after session exchange
            final user = supabase.auth.currentUser;
            if (user != null) {
              debugPrint('[AUTH-DEBUG] User authenticated - ID: ${user.id}');
              debugPrint('[AUTH-DEBUG] Email verification status: ${user.emailConfirmedAt != null}');
              
              // Ensure we're on the main screen after verification
              if (navigatorKey.currentContext != null) {
                debugPrint('[AUTH-DEBUG] Navigating to main screen');
                provider_pkg.Provider.of<NavigationState>(navigatorKey.currentContext!, listen: false).navigateToMain();
              } else {
                debugPrint('[AUTH-DEBUG] Navigator context not available');
              }
            } else {
              debugPrint('[AUTH-DEBUG] No user found after code exchange');
            }
          } catch (e) {
            debugPrint('[AUTH-ERROR] Error exchanging code: $e');
            rethrow;
          }
        } else {
          debugPrint('[AUTH-DEBUG] No verification code found in URI parameters');
        }
      } else {
        debugPrint('[AUTH-DEBUG] URI path does not contain expected verification paths');
      }
    } catch (e) {
      debugPrint('[AUTH-ERROR] Error handling deep link: $e');
      rethrow;
    }
  }
  
  // Listen for auth state changes
  static Stream<AuthState> get onAuthStateChange => 
    supabase.auth.onAuthStateChange;
  
  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;
      
      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return response;
    } catch (e) {
      return null;
    }
  }
  
  /// Update user profile
  static Future<void> updateUserProfile({String? username, String? fullName, String? avatarUrl}) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');
      
      final updates = {
        if (username != null) 'username': username,
        if (fullName != null) 'full_name': fullName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };
      
      if (updates.isNotEmpty) {
        await supabase
            .from('profiles')
            .update(updates)
            .eq('id', currentUser!.id);
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectUrl,
      );
    } catch (e) {
      if (e is AuthException) {
        switch (e.message) {
          case 'User not found':
            throw Exception('No account found with this email address.');
          case 'For security purposes, you can only request this once every 60 seconds':
            throw Exception('Too many reset attempts. Please wait a minute and try again.');
          default:
            throw Exception('Unable to send reset email: ${e.message}');
        }
      }
      
      throw Exception('Unable to send password reset email. Please try again later.');
    }
  }
  
  /// Handle auth state changes with detailed logging
  static Future<void> handleAuthStateChange(AuthState state) async {
    debugPrint('[AUTH-DEBUG] Auth state changed - Event: ${state.event}');
    debugPrint('[AUTH-DEBUG] Session present: ${state.session != null}');
    
    final session = state.session;
    final event = state.event;
    
    if (event == AuthChangeEvent.signedIn && session != null) {
      debugPrint('[AUTH-DEBUG] Processing signed in event');
      try {
        final user = session.user;
        debugPrint('[AUTH-DEBUG] User ID: ${user.id}');
        debugPrint('[AUTH-DEBUG] Email verified: ${user.emailConfirmedAt != null}');
        debugPrint('[AUTH-DEBUG] Auth provider: ${user.appMetadata['provider']}');
        
        await Future.delayed(Duration(milliseconds: 800));
        
        final existingProfile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        
        debugPrint('[AUTH-DEBUG] Existing profile found: ${existingProfile != null}');
        
        if (existingProfile == null) {
          debugPrint('[AUTH-DEBUG] Creating new user profile');
          final userMetadata = user.userMetadata;
          debugPrint('[AUTH-DEBUG] User metadata: $userMetadata');
          
          final profileData = {
            'id': user.id,
            'username': userMetadata?['username'] ?? userMetadata?['user_name'] ?? user.email?.split('@').first ?? 'user_${user.id.substring(0, 8)}',
            'full_name': userMetadata?['full_name'],
            'avatar_url': userMetadata?['avatar_url'],
            'provider': user.appMetadata['provider'] ?? 'email',
            'provider_id': user.appMetadata['provider_id'] ?? user.id,
            'provider_data': user.userMetadata,
          };
          
          debugPrint('[AUTH-DEBUG] Profile data to insert: $profileData');
          
          try {
            await supabase.from('profiles').insert(profileData);
            debugPrint('[AUTH-DEBUG] Profile created successfully');
          } catch (profileError) {
            debugPrint('[AUTH-ERROR] Error creating profile on first attempt: $profileError');
            try {
              await Future.delayed(Duration(milliseconds: 1000));
              await supabase.from('profiles').insert(profileData);
              debugPrint('[AUTH-DEBUG] Profile created successfully on retry');
            } catch (retryError) {
              debugPrint('[AUTH-ERROR] Error creating profile on retry: $retryError');
            }
          }
          
          await _createDefaultUserPreferences(user.id);
          debugPrint('[AUTH-DEBUG] Default user preferences created');
        }

        // Navigate to main screen after successful auth
        if (navigatorKey.currentContext != null) {
          debugPrint('[AUTH-DEBUG] Navigating to main screen');
          provider_pkg.Provider.of<NavigationState>(navigatorKey.currentContext!, listen: false).navigateToMain();
        } else {
          debugPrint('[AUTH-DEBUG] Navigator context not available for navigation');
        }
        
      } catch (e) {
        debugPrint('[AUTH-ERROR] Error in handleAuthStateChange: $e');
      }
    } else if (event == AuthChangeEvent.signedOut) {
      debugPrint('[AUTH-DEBUG] User signed out');
    } else if (event == AuthChangeEvent.passwordRecovery) {
      debugPrint('[AUTH-DEBUG] Password recovery event received');
    } else if (event == AuthChangeEvent.tokenRefreshed) {
      debugPrint('[AUTH-DEBUG] Token refreshed event received');
    } else if (event == AuthChangeEvent.userUpdated) {
      debugPrint('[AUTH-DEBUG] User updated event received');
    }
  }
  
  /// Create default user preferences
  static Future<void> _createDefaultUserPreferences(String userId) async {
    try {
      final existing = await supabase
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (existing != null) {
        return;
      }
      
      final prefsData = {
        'user_id': userId,
        'theme': 'system',
        'notification_enabled': true,
        'reminder_time': '09:00:00',
        'premium_tier': 'free',
        'scan_count': 0,
      };
      
      try {
        await supabase.from('user_preferences').insert(prefsData);
      } catch (insertError) {
        try {
          await supabase.rpc('create_user_preferences', params: {
            'user_id': userId,
            'user_theme': 'system',
            'notification_enabled': true,
            'reminder_time': '09:00:00',
            'premium_tier': 'free',
            'scan_count': 0,
          });
        } catch (rpcError) {
          // Handle RPC error
        }
      }
    } catch (e) {
      // Handle error
    }
  }
  
  /// Get user preferences
  static Future<Map<String, dynamic>?> getUserPreferences() async {
    try {
      if (currentUser == null) return null;
      
      final response = await supabase
          .from('user_preferences')
          .select()
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      
      return response;
    } catch (e) {
      return null;
    }
  }
  
  /// Update user preferences
  static Future<void> updateUserPreferences({
    String? theme,
    bool? notificationEnabled,
    String? reminderTime,
    String? premiumTier,
    int? scanCount,
  }) async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');
      
      final updates = {
        if (theme != null) 'theme': theme,
        if (notificationEnabled != null) 'notification_enabled': notificationEnabled,
        if (reminderTime != null) 'reminder_time': reminderTime,
        if (premiumTier != null) 'premium_tier': premiumTier,
        if (scanCount != null) 'scan_count': scanCount,
      };
      
      if (updates.isNotEmpty) {
        final existingPrefs = await getUserPreferences();
        
        if (existingPrefs != null) {
          await supabase
              .from('user_preferences')
              .update(updates)
              .eq('user_id', currentUser!.id);
        } else {
          await _createDefaultUserPreferences(currentUser!.id);
          await supabase
              .from('user_preferences')
              .update(updates)
              .eq('user_id', currentUser!.id);
        }
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Increment scan count
  static Future<int> incrementScanCount() async {
    try {
      if (currentUser == null) throw Exception('User not authenticated');
      
      final prefs = await getUserPreferences();
      if (prefs == null) {
        await _createDefaultUserPreferences(currentUser!.id);
        return 1;
      }
      
      final currentCount = prefs['scan_count'] as int? ?? 0;
      final newCount = currentCount + 1;
      
      await supabase
          .from('user_preferences')
          .update({'scan_count': newCount})
          .eq('user_id', currentUser!.id);
      
      return newCount;
    } catch (e) {
      return 0;
    }
  }
  
  /// Check if user has premium access
  static Future<bool> hasPremiumAccess() async {
    try {
      final prefs = await getUserPreferences();
      return prefs != null && prefs['premium_tier'] == 'premium';
    } catch (e) {
      return false;
    }
  }
  
  /// Update user password (for reset flow)
  static Future<void> updatePassword(String newPassword, {String? resetCode}) async {
    try {
      if (resetCode != null && resetCode.isNotEmpty) {
        final response = await supabase.auth.exchangeCodeForSession(resetCode);
        if (response.session == null) {
          throw Exception('Invalid or expired reset code. Please request a new password reset link.');
        }
        
        await supabase.auth.updateUser(
          UserAttributes(
            password: newPassword,
          ),
        );
      } else {
        await supabase.auth.updateUser(
          UserAttributes(
            password: newPassword,
          ),
        );
      }
    } catch (e) {
      if (e is AuthException) {
        switch (e.message) {
          case 'Invalid login credentials':
            throw Exception('Your password reset link has expired. Please request a new one.');
          case 'User not found':
            throw Exception('Account not found. Please request a new password reset link.');
          default:
            throw Exception('Unable to update password: ${e.message}');
        }
      }
      
      throw Exception('Unable to update password. Please try again later.');
    }
  }
  
  /// Delete user account and all associated data
  static Future<void> deleteUserAccount({
    required VoidCallback onAccountDeleted
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      
      if (currentUser == null) {
        throw Exception('No user is currently logged in');
      }
      
      final userId = currentUser.id;
      
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'deleted': true,
              'account_status': 'deleted',
              'deleted_at': DateTime.now().toIso8601String()
            }
          )
        );
      } catch (metadataError) {
        // Continue with the process even if this fails
      }
      
      try {
        final response = await Supabase.instance.client.rpc(
          'delete_user_account',
          params: {'p_user_id': userId}
        );
      } catch (deleteError) {
        try {
          final prefDeleteResponse = await Supabase.instance.client
            .from('user_preferences')
            .delete()
            .eq('user_id', userId);
        } catch (prefError) {
          // Handle prefError
        }
        
        try {
          await Supabase.instance.client
            .from('profiles')
            .delete()
            .eq('id', userId);
        } catch (profileError) {
          // Handle profileError
        }
      }
      
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (signOutError) {
        // Continue with the process even if this fails
      }
      
      onAccountDeleted();
      
    } catch (e) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (signOutError) {
        // Handle signOutError
      }
      
      throw Exception('Authentication error: ${e.toString()}');
    }
  }
  
  /// Clear all user-related data from the app
  static Future<void> clearUserData() async {
    try {
      await Future.wait([
        // Add specific cleanup tasks here when needed
      ]);
    } catch (e) {
      // Don't rethrow - we want to continue with sign out even if cleanup fails
    }
  }
  
  /// Sign in with magic link
  static Future<void> signInWithMagicLink(String email) async {
    try {
      debugPrint('[AUTH-DEBUG] Starting magic link sign-in process');
      debugPrint('[AUTH-DEBUG] Platform: ${Platform.operatingSystem}');
      debugPrint('[AUTH-DEBUG] Is Web: $kIsWeb');
      
      final redirectUrl = _redirectUrl;
      debugPrint('[AUTH-DEBUG] Using redirect URL: $redirectUrl');
      
      await supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectUrl,
        shouldCreateUser: true,
        data: {
          'username': email.split('@').first,
          'email': email,
        },
      );
      
      debugPrint('[AUTH-DEBUG] Magic link sent successfully to: $email');
    } catch (e) {
      debugPrint('[AUTH-ERROR] Magic link error: $e');
      if (e is AuthException) {
        switch (e.message) {
          case 'For security purposes, you can only request this once every 60 seconds':
            throw Exception('Please wait a minute before requesting another magic link.');
          case 'User not found':
            throw Exception('No account found with this email address.');
          default:
            throw Exception('Unable to send magic link: ${e.message}');
        }
      }
      throw Exception('Unable to send magic link. Please try again later.');
    }
  }
}