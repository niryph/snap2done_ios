import 'package:flutter/material.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  final Function? onResume;
  final Function? onPause;
  
  AppLifecycleObserver({this.onResume, this.onPause});
  
  void register() {
    WidgetsBinding.instance.addObserver(this);
  }
  
  void unregister() {
    WidgetsBinding.instance.removeObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && onResume != null) {
      onResume!();
    } else if (state == AppLifecycleState.paused && onPause != null) {
      onPause!();
    }
  }
} 