import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../card_stack_reversed.dart';

class MainView extends StatelessWidget {
  const MainView({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Use a unique key for CardStackReversed to ensure a fresh instance each time
    return CardStackReversed(key: ValueKey('main_${timestamp}_${identityHashCode(this)}'));
  }
}
