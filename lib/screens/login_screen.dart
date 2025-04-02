import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';  // Add this import for PlatformException
import '../services/auth_service.dart';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:async';  // Add this import for scheduleMicrotask
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../app/navigation_state.dart';
import '../main.dart' show navigatorKey;
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage = '';
  bool _isSignUpMode = false; // Track current mode
  bool _showPassword = false;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for email/password login
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Password validation state
  String? _passwordError;
  
  @override
  void initState() {
    super.initState();
    
    // Add listeners for real-time validation
    _passwordController.addListener(_validatePasswordOnChange);
    _confirmPasswordController.addListener(_validatePasswordOnChange);
  }
  
  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    _passwordController.removeListener(_validatePasswordOnChange);
    _confirmPasswordController.removeListener(_validatePasswordOnChange);
    
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // Real-time password validation
  void _validatePasswordOnChange() {
    if (_isSignUpMode) {
      setState(() {
        _passwordError = _validatePassword(
          _passwordController.text, 
          requireConfirmation: _confirmPasswordController.text.isNotEmpty
        );
      });
    }
  }
  
  // Password validation method
  String? _validatePassword(String password, {bool requireConfirmation = false}) {
    // Check if password is empty
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    
    // Minimum length check
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    // Complexity checks
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    if (!hasUppercase) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!hasLowercase) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!hasDigits) {
      return 'Password must contain at least one number';
    }
    
    if (!hasSpecialChar) {
      return 'Password must contain at least one special character';
    }
    
    // Confirmation password check (only for sign up)
    if (requireConfirmation) {
      if (_passwordController.text != _confirmPasswordController.text) {
        return 'Passwords do not match';
      }
    }
    
    return null;
  }
  
  // Toggle between sign in and sign up modes
  void _toggleAuthMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _errorMessage = ''; // Clear any previous error messages
      _passwordError = null; // Clear password validation errors when switching modes
    });
  }
  
  Future<void> _handleSignIn(Future<bool> Function() signInMethod) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      NavigationState? navigationState;
      try {
        navigationState = provider_pkg.Provider.of<NavigationState>(context, listen: false);
      } catch (e) {
        // Handle navigation state error
      }
      
      final result = await signInMethod();
      
      if (result && mounted) {
        // Add delay for auth state stabilization
        await Future.delayed(Duration(milliseconds: 800));
        
        if (!mounted) return;
        
        final navState = provider_pkg.Provider.of<NavigationState>(context, listen: false);
        
        // Schedule navigation in a microtask to ensure all state updates are processed
        scheduleMicrotask(() {
          if (!mounted) return;
          
          final navState = provider_pkg.Provider.of<NavigationState>(context, listen: false);
          navState.navigateToMain();
          
          // Additional microtask to ensure navigation is complete
          scheduleMicrotask(() {
            if (!mounted) return;
            
            final currentScreen = provider_pkg.Provider.of<NavigationState>(context, listen: false).currentScreen;
          });
        });
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      if (e is PlatformException && e.message?.contains('Error while launching') == true) {
        errorMessage = 'Unable to open sign-in page. Please check your internet connection.';
      } else {
        errorMessage = 'An error occurred during sign-in. Please try again.';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    }
  }
  
  // Email/password sign in
  Future<void> _signInWithEmail() async {
    // Input validation
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate email
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await AuthService.signInWithEmail(email, password);
    } catch (e) {
      setState(() {
        // Transform the error into a user-friendly message
        _errorMessage = _getReadableErrorMessage(e.toString());
        
        // Special handling for email not confirmed
        if (e.toString().contains('Email not confirmed')) {
          // Show a dialog to guide the user
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Email Verification Required'),
              content: Text(
                'Your email is not yet verified. Please check your inbox for the verification link. '
                'If you did not receive an email, you can request a new verification email.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Optionally, you could add a method to resend verification email
                  },
                  child: Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: Implement method to resend verification email
                    // _resendVerificationEmail(email);
                  },
                  child: Text('Resend Verification Email'),
                ),
              ],
            ),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Email/password sign up
  Future<void> _signUpWithEmail() async {
    // Input validation
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate email
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    // Validate password
    final passwordError = _validatePassword(password, requireConfirmation: true);
    if (passwordError != null) {
      setState(() {
        _errorMessage = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final response = await AuthService.signUpWithEmail(
        email,
        password,
        username: email.split('@').first, // Optional: generate username from email
      );
      
      // Show confirmation dialog if signup was successful
      if (mounted && response.user != null) {
        showDialog(
          context: context,
          barrierDismissible: false, // User must tap a button
          builder: (context) => AlertDialog(
            title: Text('Verify Your Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'ve sent a verification email to:\n'
                  '$email\n\n'
                  'Please check your email and click the verification link to activate your account.',
                  style: TextStyle(height: 1.5),
                ),
                SizedBox(height: 16),
                Text(
                  'Next steps:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '1. Open your email\n'
                  '2. Click the verification link\n'
                  '3. Return here to sign in',
                  style: TextStyle(height: 1.5),
                ),
                SizedBox(height: 16),
                Text(
                  'Can\'t find the email?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '• Check your spam folder\n'
                  '• Make sure you entered the correct email\n'
                  '• Wait a few minutes and try resending',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
            actions: [
              if (Platform.isIOS || Platform.isMacOS)
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse('message://');
                    try {
                      await launchUrl(url);
                    } catch (e) {
                      debugPrint('Could not launch email app: $e');
                    }
                  },
                  child: Text('Open Mail App'),
                ),
              TextButton(
                onPressed: () async {
                  try {
                    // Use signUp again to resend the verification email
                    await AuthService.signUpWithEmail(
                      email,
                      password,
                      username: email.split('@').first,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Verification email resent to $email'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      String message = 'Failed to resend verification email';
                      if (e.toString().contains('User already exists')) {
                        message = 'Email already verified. Please try signing in.';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: Text('Resend Email'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Switch back to sign-in mode
                  setState(() {
                    _isSignUpMode = false;
                    _emailController.text = email; // Pre-fill email for convenience
                  });
                },
                child: Text('Back to Sign In'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        // Use the error message from the AuthService
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Widget _buildMagicLinkButton() {
    return TextButton(
      onPressed: _isLoading ? null : _handleMagicLinkSignIn,
      child: Text(
        'Sign in with Magic Link',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _handleMagicLinkSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.signInWithMagicLink(_emailController.text);
      
      if (!mounted) return;
      
      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Check Your Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We\'ve sent a magic link to ${_emailController.text}'),
              const SizedBox(height: 16),
              const Text('Click the link in the email to sign in.'),
              const SizedBox(height: 16),
              const Text('Didn\'t receive the email?'),
              const Text('• Check your spam folder'),
              const Text('• Make sure the email address is correct'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _emailController.clear();
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  Navigator.pop(context);
                  await _handleMagicLinkSignIn();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error resending magic link: $e')),
                  );
                }
              },
              child: const Text('Resend'),
            ),
            if (Platform.isIOS || Platform.isMacOS)
              TextButton(
                onPressed: () async {
                  final url = Uri.parse('message://');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: const Text('Open Mail App'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending magic link: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  
                  // Welcome Text
                  const Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Password Input (only show in sign in mode)
                  if (!_isSignUpMode)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                  
                  // Confirm Password Input (only show in sign up mode)
                  if (_isSignUpMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) => _validatePassword(value ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Sign In/Sign Up Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      if (_isSignUpMode) {
                        _signUpWithEmail();
                      } else if (_passwordController.text.isEmpty) {
                        _handleMagicLinkSignIn();
                      } else {
                        _signInWithEmail();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6B7AFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isSignUpMode 
                        ? 'Sign Up' 
                        : (_passwordController.text.isEmpty ? 'Continue with Magic Link' : 'Sign In with Password'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // Toggle Sign In/Sign Up
                  TextButton(
                    onPressed: _isLoading ? null : _toggleAuthMode,
                    child: Text(
                      _isSignUpMode
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  if (_errorMessage?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // OR CONTINUE WITH divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Social Login Buttons
                  Column(
                    children: [
                      // Google Sign In Button
                      OutlinedButton(
                        onPressed: () => AuthService.signInWithGoogle(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Apple Sign In Button
                      OutlinedButton(
                        onPressed: () => _handleSignIn(() => AuthService.signInWithApple()),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/apple_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Continue with Apple',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Forgot password method
  Future<void> _forgotPassword() async {
    // Get the email from the email field
    final email = _emailController.text.trim();
    
    // Validate email
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address first';
      });
      return;
    }
    
    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Call the AuthService to send password reset email
      await AuthService.resetPassword(email);
      
      // Show confirmation dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Reset Email Sent'),
            content: Text(
              'A password reset link has been sent to $email. '
              'Please check your inbox and follow the instructions to reset your password. '
              'Check your spam folder if you don\'t see the email.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        // Transform the error into a user-friendly message
        _errorMessage = _getReadableErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Helper method to transform error messages into user-friendly format
  String _getReadableErrorMessage(String error) {
    // Normalize error to lowercase for more robust matching
    final normalizedError = error.toLowerCase();

    // Specific error patterns
    final errorMappings = {
      // Authentication errors
      'invalid login credentials': 'Invalid email or password. Please check your credentials and try again.',
      'user not found': 'No account found with this email. Please sign up first.',
      'email not confirmed': 'Please confirm your email before logging in.',
      
      // Network and connection errors
      'network': 'Network error. Please check your internet connection and try again.',
      'timeout': 'Connection timed out. Please check your internet and try again.',
      'connection': 'Unable to connect to the server. Please try again later.',
      
      // OAuth and external service errors
      'error while launching': 'Unable to complete sign-in process. Please try another method.',
      'supabase.co/auth': 'Sign-in service is currently unavailable. Please try again later.',
      
      // Rate limiting and security
      'too many attempts': 'Too many login attempts. Please wait and try again later.',
      'account locked': 'Your account is temporarily locked. Please reset your password or contact support.',
      
      // Generic fallback errors
      'permission denied': 'You do not have permission to access this account.',
      'unauthorized': 'Authentication failed. Please log in again.',
    };

    // Check for specific error patterns
    for (var entry in errorMappings.entries) {
      if (normalizedError.contains(entry.key)) {
        return entry.value;
      }
    }

    // If no specific pattern matches, return a generic error message
    return 'An unexpected error occurred during sign-in. Please try again later.';
  }
} 