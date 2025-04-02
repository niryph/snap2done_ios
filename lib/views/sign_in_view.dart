import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import 'package:flutter/foundation.dart';

class SignInView extends StatelessWidget {
  const SignInView({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Remove any existing login screen from memory and force a complete rebuild
    // Use a timestamp in the key to ensure it's always unique
    return LoginScreen(key: ValueKey('login_${timestamp}_${identityHashCode(this)}'));
  }
}
