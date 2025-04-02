import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'navigation_state.dart';
import '../views/landing_view.dart';
import '../views/sign_in_view.dart';
import '../views/main_view.dart';

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  print("============= APP STARTING =============");
  
  // Run the app
  runApp(Snap2DoneApp());
}

class Snap2DoneApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print("Snap2DoneApp build called");
    return MaterialApp(
      debugShowCheckedModeBanner: true, // Show debug banner
      title: 'Snap2Done',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Use MultiProvider to provide all needed services
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            print("Creating NavigationState");
            return NavigationState();
          }),
        ],
        child: AppCoordinator(),
      ),
    );
  }
}

class AppCoordinator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final navigationState = provider_pkg.Provider.of<NavigationState>(context);
    
    print("AppCoordinator build: Current screen = ${navigationState.currentScreen}");
    
    // Calculate stack index
    final stackIndex = _getStackIndex(navigationState.currentScreen);
    print("IndexedStack using index: $stackIndex");

    // Use a more explicit structure to ensure proper layer ordering
    return IndexedStack(
      index: stackIndex,
      children: [
        // Landing view is the first page (index 0)
        Builder(builder: (context) {
          print("Building LandingView in IndexedStack");
          return LandingView();
        }),
        
        // Sign in view (index 1)
        Builder(builder: (context) {
          print("Building SignInView in IndexedStack");
          return SignInView();
        }),
        
        // Main view (index 2)
        Builder(builder: (context) {
          print("Building MainView in IndexedStack");
          return MainView();
        }),
      ],
    );
  }
  
  // Helper method to convert Screen enum to stack index
  int _getStackIndex(Screen screen) {
    switch (screen) {
      case Screen.landing:
        return 0;
      case Screen.signIn:
        return 1;
      case Screen.main:
        return 2;
      default:
        return 0;
    }
  }
}
