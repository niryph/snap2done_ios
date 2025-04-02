import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/navigation_state.dart';
import '../view_models/landing_view_model.dart';
import 'package:app_links/app_links.dart';

class LandingView extends StatefulWidget {
  const LandingView({Key? key}) : super(key: key);

  @override
  _LandingViewState createState() {
    print("Creating LandingView State");
    return _LandingViewState();
  }
}

class _LandingViewState extends State<LandingView> with SingleTickerProviderStateMixin {
  late LandingViewModel _viewModel;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  bool _authCheckComplete = false;
  late AppLinks _appLinks;
  
  @override
  void initState() {
    super.initState();
    
    _viewModel = LandingViewModel();
    _animationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    
    // Start animation when the widget is built
    _animationController.forward();
    
    // Initialize deep link handling
    _initAppLinks();
    
    // Check authentication status after animation completes
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_authCheckComplete) {
        _checkAuth();
      }
    });
  }
  
  // Initialize app links to handle deep links
  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    
    // Handle incoming links - first the initial one if the app was launched with one
    try {
      final uri = await _appLinks.getInitialAppLink();
      if (uri != null) {
        print('Initial deep link: $uri');
        // Handle the deep link, e.g. extract auth code and verify with Supabase
        await _handleDeepLink(uri);
      }
    } catch (e) {
      print('Error getting initial app link: $e');
    }
    
    // And then listen for new ones
    _appLinks.uriLinkStream.listen((uri) {
      print('Incoming deep link: $uri');
      _handleDeepLink(uri);
    }, onError: (error) {
      print('Error in deep link stream: $error');
    });
  }
  
  // Handle deep links with auth parameters
  Future<void> _handleDeepLink(Uri uri) async {
    try {
      if (uri.path.contains('login-callback')) {
        print('Handling auth callback with URI: $uri');
        // This will be automatically handled by Supabase
        // Force refresh auth after handling
        _checkAuth();
      }
    } catch (e) {
      print('Error handling deep link: $e');
    }
  }
  
  void _checkAuth() async {
    // Prevent multiple auth checks
    if (_authCheckComplete) return;
    
    _authCheckComplete = true;
    await _viewModel.checkAuthStatus();
    
    // Make sure context is still valid before accessing Provider
    if (!mounted) return;
    
    final navigationState = Provider.of<NavigationState>(context, listen: false);
    if (_viewModel.navigateToMainView) {
      navigationState.navigateToMain();
    } else if (_viewModel.navigateToSignIn) {
      navigationState.navigateToSignIn();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: FadeTransition(
        opacity: _opacityAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app_logo.png',
                width: 150,
                height: 150,
              ),
              SizedBox(height: 20),
              Text(
                'Snap2Done',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 30),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}