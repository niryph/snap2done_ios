import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dart:math';

class ResetPasswordScreen extends StatefulWidget {
  final String? hash; // Password reset hash from deep link
  final String? code; // Password reset code from deep link
  
  const ResetPasswordScreen({Key? key, this.hash, this.code}) : super(key: key);

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _resetCode;
  
  @override
  void initState() {
    super.initState();
    
    // Check if we already have a code/hash from the constructor
    if (widget.code != null && widget.code!.isNotEmpty) {
      _resetCode = widget.code;
      debugPrint('Using code from direct constructor: ${_resetCode?.substring(0, min(5, _resetCode?.length ?? 0))}...');
    } else if (widget.hash != null && widget.hash!.isNotEmpty) {
      _resetCode = widget.hash;
      debugPrint('Using hash from direct constructor: ${_resetCode?.substring(0, min(5, _resetCode?.length ?? 0))}...');
    } else {
      // Process from arguments after widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processPasswordResetToken();
      });
    }
  }
  
  void _processPasswordResetToken() {
    final args = ModalRoute.of(context)?.settings.arguments;
    
    // Only process if we don't already have a reset code
    if (_resetCode == null || _resetCode!.isEmpty) {
      // Try to get code or hash from arguments
      if (args != null && args is Map<String, dynamic>) {
        if (args.containsKey('code')) {
          _resetCode = args['code'] as String?;
          if (_resetCode != null && _resetCode!.isNotEmpty) {
            debugPrint('Using code from arguments: ${_resetCode!.substring(0, min(5, _resetCode!.length))}...');
          }
        } else if (args.containsKey('hash')) {
          _resetCode = args['hash'] as String?;
          if (_resetCode != null && _resetCode!.isNotEmpty) {
            debugPrint('Using hash from arguments: ${_resetCode!.substring(0, min(5, _resetCode!.length))}...');
          }
        }
      }
      
      if (_resetCode == null || _resetCode!.isEmpty) {
        setState(() {
          _errorMessage = 'Invalid password reset link. Please request a new one.';
        });
      }
    }
  }
  
  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  // Password validation method (reused from login_screen.dart)
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
    
    // Confirmation password check
    if (requireConfirmation) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        return 'Passwords do not match';
      }
    }
    
    return null;
  }
  
  Future<void> _resetPassword() async {
    // First, validate the password
    final newPassword = _newPasswordController.text;
    final passwordError = _validatePassword(newPassword, requireConfirmation: true);
    
    if (passwordError != null) {
      setState(() {
        _errorMessage = passwordError;
      });
      return;
    }
    
    // Check if we have a valid reset code
    if (_resetCode == null || _resetCode!.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid password reset session. Please request a new reset link.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Call Supabase to update the password with the reset code
      await AuthService.updatePassword(newPassword, resetCode: _resetCode);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset successfully')),
        );
        
        // Navigate to login screen
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      setState(() {
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Create a new password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              if (_errorMessage != null)
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[900]),
                    softWrap: true,
                  ),
                ),
              
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  helperText: 'Min 8 chars with upper, lower, number, special char',
                  helperMaxLines: 2,
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text('Reset Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFC107), // Yellow color
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 