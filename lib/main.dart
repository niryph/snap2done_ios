import 'package:flutter/material.dart';
import 'card_stack_reversed.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/config_service.dart';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:io' show Platform;
import 'screens/login_screen.dart'; 
import 'services/auth_service.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'utils/theme_provider.dart';
import 'utils/supabase_debug.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'app/navigation_state.dart';
import 'views/landing_view.dart';
import 'views/sign_in_view.dart';
import 'views/main_view.dart';
import 'services/user_session_manager.dart';
import 'package:app_links/app_links.dart';
import 'screens/reset_password_screen.dart';
import 'package:flutter/services.dart' as services;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';

// Global navigator key for accessing navigator context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase
    debugPrint('[TRACE] INIT: Starting Supabase initialization');
    debugPrint('[TRACE] INIT: Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    
    await Supabase.initialize(
      url: 'https://hbqptvpyvjrfggeqfuav.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhicXB0dnB5dmpyZmdnZXFmdWF2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA3NDc5MzEsImV4cCI6MjA1NjMyMzkzMX0.wdu8e9LXqM6PWOkRlU4tA6GPLs2Ql4yzRst1SU3Rz9o',
      debug: true, // Enable debug logs
    );
    
    debugPrint('[TRACE] INIT: Supabase initialized successfully');
    debugPrint('[TRACE] INIT: Client instance available: ${Supabase.instance != null}');
    debugPrint('[TRACE] INIT: Auth initialized: ${Supabase.instance.client.auth != null}');
    
    // Initialize configuration services
    await ConfigService.initialize();
    debugPrint('[TRACE] INIT: ConfigService initialized');
    
    // Initialize storage service
    await StorageService.initialize();
    debugPrint('[TRACE] INIT: StorageService initialized');
    
    // Set up deep link handling for initial link
    final appLinks = AppLinks();
    Uri? initialLink;
    try {
      initialLink = await appLinks.getInitialAppLink();
      debugPrint('[TRACE] INIT: Initial deep link: $initialLink');
    } on PlatformException {
      debugPrint('[TRACE] INIT: Failed to get initial deep link');
    }
    
    // Run the app
    runApp(
      provider_pkg.MultiProvider(
        providers: [
          provider_pkg.ChangeNotifierProvider(create: (_) => ThemeProvider()),
          provider_pkg.ChangeNotifierProvider(create: (_) => NavigationState()),
          // Add other providers here
        ],
        child: MyApp(initialDeepLink: initialLink),
      ),
    );
    
    // Set up app_links listener for deep link handling
    appLinks.uriLinkStream.listen((uri) {
      debugPrint('Got app_links deep link: $uri');
      _handleDeepLink(uri);
    });
    
  } catch (e) {
    developer.log('Initialization error', error: e);
    // Fallback error handling
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: ${e.toString()}'),
          ),
        ),
      ),
    );
  }
}

// Helper function to safely fetch config values
Future<void> _fetchConfigSafely(String key) async {
  try {
    await ConfigService.fetchAndSecurePrivateConfig(key);
  } catch (e) {
    developer.log('Error fetching config for $key: $e', name: 'ConfigService');
    // Config will use fallback values if fetch fails
  }
}

// Top-level function to handle deep links
void _handleDeepLink(Uri uri) {
  try {
    debugPrint('[TRACE] DEEPLINK: Handling deep link: $uri');
    debugPrint('[TRACE] DEEPLINK: URI components - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}');
    debugPrint('[TRACE] DEEPLINK: Query parameters: ${uri.queryParameters}');

    // Safety check: wait until navigator is ready
    if (navigatorKey.currentState == null) {
      debugPrint('[TRACE] DEEPLINK: Navigator not ready. Delaying deep link handling...');
      Future.delayed(const Duration(milliseconds: 1500), () {
        _handleDeepLink(uri);
      });
      return;
    }

    // ✅ Handle OAuth Callback from Supabase (extended patterns)
    if (uri.toString().contains('auth-callback') || 
        uri.toString().contains('login-callback') || 
        uri.toString().contains('snap2done://')) {
      
      debugPrint('[TRACE] DEEPLINK: URI matches auth callback pattern');

      // Convert custom scheme URL to https URL that Supabase expects
      final code = uri.queryParameters['code'];
      if (code != null) {
        final supabaseUrl = 'https://hbqptvpyvjrfggeqfuav.supabase.co/auth/v1/callback?code=$code';
        debugPrint('[TRACE] DEEPLINK: Converting to Supabase URL: $supabaseUrl');

        // Pass the converted URL to Supabase
        debugPrint('[TRACE] DEEPLINK: Attempting to get session from URL');
        Supabase.instance.client.auth
            .getSessionFromUrl(Uri.parse(supabaseUrl))
            .then((response) {
          final session = response.session;
          if (session != null) {
            debugPrint('[TRACE] DEEPLINK: Session recovered successfully');
            debugPrint('[TRACE] DEEPLINK: User ID: ${session.user.id}');
            debugPrint('[TRACE] DEEPLINK: User signed in successfully! Redirecting to home...');
            
            // Force close the OAuth browser window and bring app to foreground
            SystemNavigator.routeInformationUpdated(location: '/');
            
            // Small delay to ensure the browser is closed before navigation
            Future.delayed(Duration(milliseconds: 500), () {
              // Use NavigationState instead of direct navigation
              if (navigatorKey.currentContext != null) {
                provider_pkg.Provider.of<NavigationState>(navigatorKey.currentContext!, listen: false).navigateToMain();
              }
            });
          } else {
            debugPrint('[TRACE] DEEPLINK: OAuth callback received but no session was found.');
          }
        }).catchError((error) {
          debugPrint('[TRACE] DEEPLINK ERROR: Error getting session: $error');
          debugPrint('[TRACE] DEEPLINK ERROR: Error type: ${error.runtimeType}');
        });
      } else {
        debugPrint('[TRACE] DEEPLINK ERROR: No code parameter found in callback URL');
      }

      return;
    }

    // ✅ Handle Password Reset via Supabase Links
    if (uri.path.contains('reset-password') || uri.fragment.contains('type=recovery')) {
      debugPrint('Received password reset link: $uri');

      String? code = uri.queryParameters['code'];

      if (code != null && code.isNotEmpty) {
        debugPrint('Password reset code: ${code.substring(0, min(5, code.length))}...');
        navigatorKey.currentState!.pushNamed('/reset-password', arguments: {'code': code});
        return;
      }

      debugPrint('No valid reset code found in link.');
    }

    debugPrint('Unhandled deep link: $uri');
  } catch (e) {
    debugPrint('Error handling deep link: $e');
  }
}

class MyApp extends StatefulWidget {
  final Uri? initialDeepLink;
  
  const MyApp({Key? key, this.initialDeepLink}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  
  @override
  void initState() {
    super.initState();
    debugPrint('[DEEP-LINK-DEBUG] Initializing deep link handling');
    
    // Initialize deep linking
    _initializeDeepLinking();
  }

  Future<void> _initializeDeepLinking() async {
    debugPrint('[DEEP-LINK-DEBUG] Setting up deep link listeners');
    
    _appLinks = AppLinks();
    
    // Handle initial URI if the app was started by a deep link
    try {
      final initialLink = await _appLinks.getInitialAppLink();
      debugPrint('[DEEP-LINK-DEBUG] Initial deep link: $initialLink');
      if (initialLink != null) {
        _handleDeepLink(initialLink.toString());
      }
    } catch (e) {
      debugPrint('[DEEP-LINK-ERROR] Error getting initial deep link: $e');
    }

    // Listen for deep link events while the app is running
    _appLinks.uriLinkStream.listen((Uri? uri) {
      debugPrint('[DEEP-LINK-DEBUG] Received deep link while app running: $uri');
      if (uri != null) {
        _handleDeepLink(uri.toString());
      }
    }, onError: (err) {
      debugPrint('[DEEP-LINK-ERROR] Error in deep link stream: $err');
    });
  }

  void _handleDeepLink(String link) {
    debugPrint('[DEEP-LINK-DEBUG] Processing deep link: $link');
    
    try {
      final uri = Uri.parse(link);
      debugPrint('[DEEP-LINK-DEBUG] Parsed URI - path: ${uri.path}, query: ${uri.queryParameters}');
      
      // Check if this is an OAuth callback
      if (link.contains('login-callback')) {
        debugPrint('[DEEP-LINK-DEBUG] Detected OAuth callback');
        
        // Check for error parameters
        if (uri.queryParameters.containsKey('error')) {
          debugPrint('[DEEP-LINK-ERROR] OAuth error: ${uri.queryParameters['error']}');
          debugPrint('[DEEP-LINK-ERROR] Error description: ${uri.queryParameters['error_description']}');
        }
        
        // Check for success parameters
        if (uri.queryParameters.containsKey('access_token')) {
          debugPrint('[DEEP-LINK-DEBUG] OAuth success - received access token');
        }
      }
    } catch (e) {
      debugPrint('[DEEP-LINK-ERROR] Error handling deep link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building MyApp widget with NavigationState');
    
    // Get theme from provider
    final theme = _getAppTheme(context);
    
    // Get the navigation state
    final navigationState = provider_pkg.Provider.of<NavigationState>(context);
    
    print('Current navigation screen: ${navigationState.currentScreen}');

    return MaterialApp(
      title: 'Snap2Done',
      theme: theme,
      navigatorKey: navigatorKey,
      home: _buildCurrentScreen(navigationState.currentScreen),
      routes: {
        '/reset-password': (context) => const ResetPasswordScreen(),
      },
      onGenerateRoute: (settings) {
        // This allows for dynamic route generation in case we need more complex routing
        if (settings.name == '/reset-password') {
          return MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(
              code: settings.arguments is Map ? 
                (settings.arguments as Map)['code'] : null,
              hash: settings.arguments is Map ? 
                (settings.arguments as Map)['hash'] : null,
            ),
          );
        }
        return null;
      },
    );
  }
  
  // Build the correct screen based on navigation state
  Widget _buildCurrentScreen(Screen currentScreen) {
    print('Building screen for: $currentScreen');
    switch (currentScreen) {
      case Screen.landing:
        return LandingView();
      case Screen.signIn:
        return SignInView();
      case Screen.main:
        return MainView();
      default:
        return LandingView();  // Default to landing
    }
  }
  
  // Safe method to get theme
  ThemeData _getAppTheme(BuildContext context) {
    try {
      final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
      // Try to access the theme safely
      return ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
    } catch (e) {
      print('Error getting theme: $e');
      return ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
    }
  }
}
