import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../utils/theme_provider.dart';
import '../utils/background_patterns.dart';
import '../services/auth_service.dart'; // Import AuthService for sign out
import '../services/notification_service.dart'; // Import NotificationService
import 'dart:async'; // Import for Timer
import 'dart:developer' as developer; // Import for developer logging
import '../screens/login_screen.dart'; // Import LoginScreen
import '../app/navigation_state.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;  // Add Platform import
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final NotificationService _notificationService = NotificationService();
  bool _isCountingDown = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    print('SettingsPage: initState called');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    print('SettingsPage: dispose called');
    super.dispose();
  }

  // Request notification permission
  Future<void> _requestNotificationPermission() async {
    final bool granted = await _notificationService.requestPermission();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted 
              ? 'Notification permission granted!' 
              : 'Notification permission denied. Please enable in settings.',
        ),
        backgroundColor: granted ? Colors.green : Colors.red,
      ),
    );
  }
  
  // Start countdown for test notification
  void _startNotificationTest() async {
    developer.log('Starting notification test', name: 'SettingsPage');
    
    try {
      // First ensure the notification service is initialized
      await _notificationService.initialize();
      
      // For macOS, check if we can show notifications without requesting permission
      bool canProceed = false;
      if (Platform.isMacOS) {
        final prefs = await SharedPreferences.getInstance();
        final permissionGranted = prefs.getBool('notification_permission_granted') ?? false;
        if (permissionGranted) {
          canProceed = true;
        }
      }
      
      // If not macOS or permission not granted, request permission
      if (!canProceed) {
        canProceed = await _notificationService.requestPermission();
      }
      
      developer.log('Can proceed with notification: $canProceed', name: 'SettingsPage');
      
      if (canProceed) {
        // First try to show an immediate test notification
        await _notificationService.showTestNotification();
        developer.log('Immediate test notification sent', name: 'SettingsPage');
        
        // Then start countdown for scheduled notification
        _startCountdown();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test notification sent! You should see it immediately.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show a dialog with instructions for enabling notifications
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Notification Permission Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Please enable notifications for Snap2Done in your device settings:'),
                SizedBox(height: 16),
                Text('1. Open System Settings'),
                Text('2. Click on Notifications'),
                Text('3. Find Snap2Done'),
                Text('4. Enable Allow Notifications'),
                SizedBox(height: 16),
                Text('After enabling, return to the app and try again.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
              if (Platform.isMacOS)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await AppSettings.openAppSettings();
                  },
                  child: Text('Open Settings'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      developer.log('Error during notification test: $e', name: 'SettingsPage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing notifications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Start countdown timer
  void _startCountdown() {
    developer.log('Starting countdown for test notification', name: 'SettingsPage');
    
    setState(() {
      _isCountingDown = true;
      _countdownSeconds = 3;
    });
    
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
          developer.log('Countdown: $_countdownSeconds seconds remaining', name: 'SettingsPage');
        } else {
          _isCountingDown = false;
          timer.cancel();
          
          // Schedule the notification
          developer.log('Countdown finished, scheduling test notification', name: 'SettingsPage');
          _notificationService.scheduleTestNotification(1);
        }
      });
    });
  }

  // Method to show delete account confirmation dialog
  void _showDeleteAccountDialog() {
    // Store a local reference to BuildContext before the async gap
    final BuildContext currentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Account'),
        content: Text(
          'Are you absolutely sure you want to delete your account? '
          'This action is permanent and cannot be undone. '
          'All your data will be permanently erased.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(), // Cancel
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              // Close the dialog
              Navigator.of(dialogContext).pop();
              
              // Show loading indicator
              setState(() {
                _isDeleting = true;
              });
              
              // Capture navigation action before async operation
              void navigateToLogin() {
                // Use the stored context to avoid issues with deactivated widgets
                if (mounted) {
                  Navigator.of(currentContext).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (route) => false, // Remove all previous routes
                  );
                }
              }
              
              // Attempt to delete account
              try {
                AuthService.deleteUserAccount(
                  onAccountDeleted: navigateToLogin,
                );
              } catch (e) {
                // Handle any errors during account deletion
                if (mounted) {
                  setState(() {
                    _isDeleting = false;
                  });
                  
                  // Show error dialog
                  showDialog(
                    context: currentContext,
                    builder: (errorContext) => AlertDialog(
                      title: Text('Account Deletion Failed'),
                      content: Text(
                        e.toString(),
                        style: TextStyle(height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(errorContext).pop(),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = provider_pkg.Provider.of<ThemeProvider>(context);
    final isDarkMode = provider_pkg.Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Stack(
      children: [
        // Background with pattern
        Positioned.fill(
          child: isDarkMode 
              ? BackgroundPatterns.darkThemeBackground()
              : BackgroundPatterns.lightThemeBackground(),
        ),
        
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: isDarkMode 
              ? Color(0xFF282A40).withOpacity(0.7) 
              : Colors.white.withOpacity(0.7),
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Card
                  _buildSettingsCard(
                    title: 'Display',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              color: Color(0xFF6C5CE7),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: isDarkMode,
                          activeColor: Color(0xFF6C5CE7),
                          onChanged: (value) {
                            themeProvider.toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Notifications Card
                  _buildSettingsCard(
                    title: 'Notifications',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Permission Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.notifications_active,
                                  color: Color(0xFF6C5CE7),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Notification Permission',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Granted',
                              style: TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Test Notification Button
                        ElevatedButton.icon(
                          onPressed: _isCountingDown ? null : _startNotificationTest,
                          icon: Icon(
                            _isCountingDown ? Icons.timer : Icons.notifications,
                            size: 18,
                          ),
                          label: Text(
                            _isCountingDown 
                                ? 'Sending in $_countdownSeconds...' 
                                : 'Test Notification',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6C5CE7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Notification Info Text
                        Text(
                          'Test notifications to ensure they work properly. Notifications will play a sound when they appear.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Delete Account Section
                  _buildSettingsCard(
                    title: 'Account',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.delete_forever,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            _isDeleting 
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                )
                              : ElevatedButton(
                                  onPressed: _showDeleteAccountDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('Delete'),
                                ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Permanently delete your account and all associated data. This action cannot be undone.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Signout Section
                  _buildSettingsCard(
                    title: 'Account',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await AuthService.signOut();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => LoginScreen()),
                                  (route) => false, // Remove all previous routes
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Sign Out'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign out of your account.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // About Card
                  _buildSettingsCard(
                    title: 'About',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF6C5CE7),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Snap2Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Version 1.0.0',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Developer Information
                        Row(
                          children: [
                            Icon(
                              Icons.code,
                              color: Color(0xFF6C5CE7),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Developer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Hakan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Helper method to build consistent settings cards
  Widget _buildSettingsCard({required String title, required Widget child}) {
    final isDarkMode = provider_pkg.Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode 
          ? Color(0xFF282A40).withOpacity(0.7) 
          : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black26 
              : Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}