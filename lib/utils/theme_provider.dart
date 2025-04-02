import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.light;
  
  ThemeProvider() {
    _loadThemeFromPrefs();
  }
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Load theme preference from SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  // Toggle between light and dark themes
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  // Set a specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _themeMode == ThemeMode.dark);
    notifyListeners();
  }
}

// Light Theme Colors
class LightThemeColors {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color backgroundColor = Color(0xFFF9F9FB);
  static const Color backgroundEndColor = Color(0xFFE3E6EF);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF333333);
  static const Color secondaryTextColor = Color(0xFF555555);
  static const Color accentColor = Color(0xFF6C5CE7);
}

// Dark Theme Colors
class DarkThemeColors {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color backgroundColor = Color(0xFF1E1E2E);
  static const Color backgroundEndColor = Color(0xFF25273D);
  static const Color cardColor = Color(0xFF282A40);
  static const Color textColor = Colors.white;
  static const Color secondaryTextColor = Color(0xFFAAAAAA);
  static const Color accentColor = Color(0xFF6C5CE7);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: LightThemeColors.primaryColor,
    fontFamily: 'DelargoDTPro',
    colorScheme: const ColorScheme.light(
      primary: LightThemeColors.primaryColor,
      secondary: LightThemeColors.accentColor,
      background: LightThemeColors.backgroundColor,
    ),
    scaffoldBackgroundColor: LightThemeColors.backgroundColor,
    cardColor: LightThemeColors.cardColor,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: LightThemeColors.textColor),
      bodyMedium: TextStyle(color: LightThemeColors.textColor),
      bodySmall: TextStyle(color: LightThemeColors.secondaryTextColor),
    ),
    appBarTheme: const AppBarTheme(
      color: LightThemeColors.primaryColor,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomAppBarTheme: const BottomAppBarTheme(
      color: Colors.white,
    ),
    iconTheme: const IconThemeData(
      color: LightThemeColors.textColor,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: DarkThemeColors.primaryColor,
    fontFamily: 'DelargoDTPro',
    colorScheme: const ColorScheme.dark(
      primary: DarkThemeColors.primaryColor,
      secondary: DarkThemeColors.accentColor,
      background: DarkThemeColors.backgroundColor,
    ),
    scaffoldBackgroundColor: DarkThemeColors.backgroundColor,
    cardColor: DarkThemeColors.cardColor,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: DarkThemeColors.textColor),
      bodyMedium: TextStyle(color: DarkThemeColors.textColor),
      bodySmall: TextStyle(color: DarkThemeColors.secondaryTextColor),
    ),
    appBarTheme: const AppBarTheme(
      color: DarkThemeColors.primaryColor,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    bottomAppBarTheme: const BottomAppBarTheme(
      color: Color(0xFF282A40),
    ),
    iconTheme: const IconThemeData(
      color: DarkThemeColors.textColor,
    ),
  );
} 