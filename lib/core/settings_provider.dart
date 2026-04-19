import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeModeKey = 'settings_theme_mode';
  static const String _zenAnimationKey = 'settings_zen_animation_enabled';
  static const String _globalAutoStartKey = 'settings_global_auto_start';
  static const String _accentColorKey = 'settings_accent_color';
  static const String _oledModeKey = 'settings_oled_mode';
  static const String _soundEnabledKey = 'settings_sound_enabled';
  static const String _hapticsEnabledKey = 'settings_haptics_enabled';
  static const String _selectedFontFamilyKey = 'settings_selected_font_family';
  static const String _showProgressRingKey = 'settings_show_progress_ring';

  static const List<Color> accentColors = [
    Color(0xFFB8CC52),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFFFFB6D9),
    Color(0xFFD4C5F9),
    Color(0xFFA3E7D8),
    Color(0xFFFFD4A3),
  ];

  ThemeMode _themeMode = ThemeMode.dark;
  bool _zenAnimationEnabled = true;
  bool _globalAutoStart = false;
  bool _isOledMode = false;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  Color _currentAccentColor = const Color(0xFFB8CC52);
  String _selectedFontFamily = 'Roboto';
  bool _showProgressRing = true;

  ThemeMode get themeMode => _themeMode;
  bool get zenAnimationEnabled => _zenAnimationEnabled;
  bool get globalAutoStart => _globalAutoStart;
  bool get isOledMode => _isOledMode;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  Color get currentAccentColor => _currentAccentColor;
  String get selectedFontFamily => _selectedFontFamily;
  bool get showProgressRing => _showProgressRing;

  SettingsProvider() {
    unawaited(loadSettings());
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
    await _saveThemeMode();
  }

  Future<void> toggleZenAnimation() async {
    _zenAnimationEnabled = !_zenAnimationEnabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_zenAnimationKey, _zenAnimationEnabled);
  }

  Future<void> toggleGlobalAutoStart() async {
    _globalAutoStart = !_globalAutoStart;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalAutoStartKey, _globalAutoStart);
  }

  Future<void> toggleOledMode() async {
    _isOledMode = !_isOledMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_oledModeKey, _isOledMode);
  }

  Future<void> toggleSoundEnabled() async {
    _soundEnabled = !_soundEnabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, _soundEnabled);
  }

  Future<void> toggleHapticsEnabled() async {
    _hapticsEnabled = !_hapticsEnabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsEnabledKey, _hapticsEnabled);
  }

  Future<void> changeAccentColor(Color color) async {
    if (_currentAccentColor.value == color.value) {
      return;
    }

    _currentAccentColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.value);
  }

  Future<void> changeFontFamily(String fontFamily) async {
    if (_selectedFontFamily == fontFamily) {
      return;
    }

    _selectedFontFamily = fontFamily;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedFontFamilyKey, fontFamily);
  }

  Future<void> toggleProgressRing() async {
    _showProgressRing = !_showProgressRing;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showProgressRingKey, _showProgressRing);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final rawValue = prefs.getString(_themeModeKey);

    if (rawValue == ThemeMode.light.name) {
      _themeMode = ThemeMode.light;
    } else if (rawValue == ThemeMode.dark.name) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.dark;
    }

    _zenAnimationEnabled = prefs.getBool(_zenAnimationKey) ?? true;
    _globalAutoStart = prefs.getBool(_globalAutoStartKey) ?? false;
    _isOledMode = prefs.getBool(_oledModeKey) ?? false;
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _hapticsEnabled = prefs.getBool(_hapticsEnabledKey) ?? true;

    final savedAccent = prefs.getInt(_accentColorKey);
    if (savedAccent != null) {
      _currentAccentColor = Color(savedAccent);
    } else {
      _currentAccentColor = const Color(0xFFB8CC52);
    }

    _selectedFontFamily = prefs.getString(_selectedFontFamilyKey) ?? 'Roboto';
    _showProgressRing = prefs.getBool(_showProgressRingKey) ?? true;

    notifyListeners();
  }

  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode.name);
  }
}
