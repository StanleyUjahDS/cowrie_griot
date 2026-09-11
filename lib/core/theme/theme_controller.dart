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
  // SKY
  // Messaging-style blue
  // ============================================================

  sky,

  // ============================================================
  // FOREST
  // Natural-style green
  // ============================================================

  forest,

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
  // Elegant pink / rose
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

  // ============================================================
  // AZURE
  // Sky-style blue
  // ============================================================

  azure,

  // ============================================================
  // INDIGO
  // Deep-style blue
  // ============================================================

  indigo,

  // ============================================================
  // AURORA
  // Modern-style blurple
  // ============================================================

  aurora,

  // ============================================================
  // TEAL
  // Clean modern teal
  // ============================================================

  teal,

  // ============================================================
  // ORANGE
  // Warm modern orange
  // ============================================================

  orange,

  // ============================================================
  // RED
  // Strong modern red
  // ============================================================

  red,

  // ============================================================
  // NEW PREMIUM THEMES
  // ============================================================

  cyber,
  onyx,
  cappuccino,
  mint,

  // ============================================================
  // MONOCHROME THEMES
  // ============================================================

  mono,
  noir,
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

      case 'sky':
        _themeStyle = AppThemeStyle.sky;
        break;

      case 'forest':
        _themeStyle = AppThemeStyle.forest;
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

      case 'azure':
        _themeStyle = AppThemeStyle.azure;
        break;

      case 'indigo':
        _themeStyle = AppThemeStyle.indigo;
        break;

      case 'aurora':
        _themeStyle = AppThemeStyle.aurora;
        break;

      case 'teal':
        _themeStyle = AppThemeStyle.teal;
        break;

      case 'orange':
        _themeStyle = AppThemeStyle.orange;
        break;

      case 'red':
        _themeStyle = AppThemeStyle.red;
        break;

      case 'cyber':
        _themeStyle = AppThemeStyle.cyber;
        break;

      case 'onyx':
        _themeStyle = AppThemeStyle.onyx;
        break;

      case 'cappuccino':
        _themeStyle = AppThemeStyle.cappuccino;
        break;

      case 'mint':
        _themeStyle = AppThemeStyle.mint;
        break;

      case 'mono':
        _themeStyle = AppThemeStyle.mono;
        break;

      case 'noir':
        _themeStyle = AppThemeStyle.noir;
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
      AppThemeStyle.sky => 'sky',
      AppThemeStyle.forest => 'forest',
      AppThemeStyle.violet => 'violet',
      AppThemeStyle.lavender => 'lavender',
      AppThemeStyle.rose => 'rose',
      AppThemeStyle.gold => 'gold',
      AppThemeStyle.midnight => 'midnight',
      AppThemeStyle.slate => 'slate',
      AppThemeStyle.azure => 'azure',
      AppThemeStyle.indigo => 'indigo',
      AppThemeStyle.aurora => 'aurora',
      AppThemeStyle.teal => 'teal',
      AppThemeStyle.orange => 'orange',
      AppThemeStyle.red => 'red',
      AppThemeStyle.cyber => 'cyber',
      AppThemeStyle.onyx => 'onyx',
      AppThemeStyle.cappuccino => 'cappuccino',
      AppThemeStyle.mint => 'mint',
      AppThemeStyle.mono => 'mono',
      AppThemeStyle.noir => 'noir',
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