import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeStyle {
  // ============================================================
  // GRIOT
  // Official Griot branding
  // Deep sea-green + gold
  // ============================================================

  griot,

  // ============================================================
  // OCEAN
  // Messaging-style blue
  // ============================================================

  ocean,

  // ============================================================
  // EMERALD
  // Messaging-style green
  // ============================================================

  emerald,

  // ============================================================
  // VIOLET
  // Modern purple
  // ============================================================

  violet,

  // ============================================================
  // LAVENDER
  // Soft purple
  // ============================================================

  lavender,

  // ============================================================
  // ROSE
  // Elegant feminine pink
  // ============================================================

  rose,

  // ============================================================
  // GOLD
  // Premium gold
  // Separate from Griot
  // ============================================================

  gold,

  // ============================================================
  // MIDNIGHT
  // Dark blue / indigo
  // ============================================================

  midnight,

  // ============================================================
  // SLATE
  // Neutral modern grey
  // ============================================================

  slate,
}

class ThemeController extends ChangeNotifier {
  // ============================================================
  // SINGLE SHARED INSTANCE
  // ============================================================

  static final ThemeController instance =
  ThemeController._internal();

  factory ThemeController() {
    return instance;
  }

  ThemeController._internal();

  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String _themeModeKey = 'theme_mode';
  static const String _themeStyleKey = 'theme_style';

  // ============================================================
  // CURRENT VALUES
  // ============================================================

  ThemeMode _themeMode = ThemeMode.system;

  AppThemeStyle _themeStyle = AppThemeStyle.griot;

  // ============================================================
  // GETTERS
  // ============================================================

  ThemeMode get themeMode => _themeMode;

  AppThemeStyle get themeStyle => _themeStyle;

  bool get isDark => _themeMode == ThemeMode.dark;

  bool get isLight => _themeMode == ThemeMode.light;

  bool get isSystem => _themeMode == ThemeMode.system;

  // ============================================================
  // LOAD SAVED SETTINGS
  // ============================================================

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // ==========================================================
    // THEME MODE
    // ==========================================================

    final savedMode = prefs.getString(_themeModeKey);

    switch (savedMode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;

      case 'dark':
        _themeMode = ThemeMode.dark;
        break;

      case 'system':
        _themeMode = ThemeMode.system;
        break;

      default:
        _themeMode = ThemeMode.system;
        break;
    }

    // ==========================================================
    // THEME STYLE
    // ==========================================================

    final savedStyle = prefs.getString(_themeStyleKey);

    switch (savedStyle) {
      case 'griot':
        _themeStyle = AppThemeStyle.griot;
        break;

      case 'ocean':
        _themeStyle = AppThemeStyle.ocean;
        break;

      case 'emerald':
        _themeStyle = AppThemeStyle.emerald;
        break;

      case 'violet':
        _themeStyle = AppThemeStyle.violet;
        break;

      case 'lavender':
        _themeStyle = AppThemeStyle.lavender;
        break;

      case 'rose':
        _themeStyle = AppThemeStyle.rose;
        break;

      case 'gold':
        _themeStyle = AppThemeStyle.gold;
        break;

      case 'midnight':
        _themeStyle = AppThemeStyle.midnight;
        break;

      case 'slate':
        _themeStyle = AppThemeStyle.slate;
        break;

      default:
        _themeStyle = AppThemeStyle.griot;
        break;
    }

    notifyListeners();
  }

  // ============================================================
  // SAVE THEME MODE
  // ============================================================

  Future<void> _saveThemeMode(
      ThemeMode mode,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    await prefs.setString(
      _themeModeKey,
      value,
    );
  }

  // ============================================================
  // SAVE THEME STYLE
  // ============================================================

  Future<void> _saveThemeStyle(
      AppThemeStyle style,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    final value = switch (style) {
      AppThemeStyle.griot => 'griot',
      AppThemeStyle.ocean => 'ocean',
      AppThemeStyle.emerald => 'emerald',
      AppThemeStyle.violet => 'violet',
      AppThemeStyle.lavender => 'lavender',
      AppThemeStyle.rose => 'rose',
      AppThemeStyle.gold => 'gold',
      AppThemeStyle.midnight => 'midnight',
      AppThemeStyle.slate => 'slate',
    };

    await prefs.setString(
      _themeStyleKey,
      value,
    );
  }

  // ============================================================
  // SET THEME MODE
  // ============================================================

  void setTheme(
      ThemeMode mode,
      ) {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;

    notifyListeners();

    _saveThemeMode(mode);
  }

  // ============================================================
  // SET THEME STYLE
  // ============================================================

  void setThemeStyle(
      AppThemeStyle style,
      ) {
    if (_themeStyle == style) {
      return;
    }

    _themeStyle = style;

    notifyListeners();

    _saveThemeStyle(style);
  }

  // ============================================================
  // TOGGLE LIGHT / DARK
  // ============================================================

  void toggleTheme() {
    setTheme(
      _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }
}