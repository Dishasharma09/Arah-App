import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the app-wide theme (Light / Dark) and persists the user's choice
/// to SharedPreferences so it survives an app restart.
///
/// Every screen must read colors from `Theme.of(context)` (never hardcode
/// `AppTheme.pureWhite` / `Colors.white` / etc. directly) for the toggle in
/// this provider to actually change what's on screen.
class ThemeProvider extends ChangeNotifier {
  static const _darkModeKey = 'is_dark_mode';

  bool _isDarkMode = false;
  bool _isLoaded = false;

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;


  ThemeProvider() {
    _loadTheme();
  }

  /// Reads the persisted preference. Called once on app start; until this
  /// completes the app renders with the light theme as a safe default.
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    } catch (e) {
      debugPrint('ThemeProvider: failed to load saved theme: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, value);
    } catch (e) {
      debugPrint('ThemeProvider: failed to save theme: $e');
    }
  }
}
