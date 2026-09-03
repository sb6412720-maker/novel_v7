import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide light / dark / system theme controller (persisted).
/// Default is dark so the reading experience is high contrast by default.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        _mode = ThemeMode.dark;
      } else {
        _mode = switch (raw) {
          'dark' => ThemeMode.dark,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        };
      }
    } catch (_) {
      _mode = ThemeMode.dark;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefsKey, raw);
    } catch (_) {}
  }

  String get label => switch (_mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}
