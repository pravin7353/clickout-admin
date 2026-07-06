import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart'; // 🚀 Tere system me ye perfectly kaam karta hai
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode currentTheme = ThemeMode.dark; // By default dark theme

  ThemeNotifier() {
    _loadTheme();
  }

  // 📥 SAVED THEME LOAD KAREGA
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme');

    if (savedTheme == 'dark') {
      currentTheme = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      currentTheme = ThemeMode.light;
    } else {
      currentTheme = ThemeMode.dark;
    }
    notifyListeners(); // UI ko update karega
  }

  // 💾 NAYI THEME SAVE KAREGA
  Future<void> setTheme(ThemeMode mode) async {
    currentTheme = mode;
    notifyListeners(); // UI turant update hoga

    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.dark) {
      await prefs.setString('app_theme', 'dark');
    } else if (mode == ThemeMode.light) {
      await prefs.setString('app_theme', 'light');
    } else {
      await prefs.setString('app_theme', 'dark');
    }
  }

  // 🔄 UI BUTTON KE LIYE DIRECT TOGGLE
  void toggleTheme() {
    if (currentTheme == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}

// 🚀 Provider Definition
final themeProvider = ChangeNotifierProvider<ThemeNotifier>((ref) {
  return ThemeNotifier();
});
