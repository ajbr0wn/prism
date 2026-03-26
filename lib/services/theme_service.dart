import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_theme.dart';

class ThemeService extends ChangeNotifier {
  List<ReadingTheme> _customThemes = [];
  String _defaultThemeId = ReadingTheme.midnightPrism.id;
  String? _storagePath;
  bool _initialized = false;

  List<ReadingTheme> get allThemes => [
        ...ReadingTheme.builtInThemes,
        ..._customThemes,
      ];

  String get defaultThemeId => _defaultThemeId;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _storagePath = '${dir.path}/prism';
    await Directory(_storagePath!).create(recursive: true);

    await _loadCustomThemes();
    await _loadDefaultThemeId();
    _initialized = true;
    notifyListeners();
  }

  /// Get the effective theme for a book.
  /// Falls back to the default theme if no per-book theme is set.
  ReadingTheme getThemeForBook(String? bookThemeId) {
    final id = bookThemeId ?? _defaultThemeId;
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => ReadingTheme.midnightPrism,
    );
  }

  /// Get a theme by ID.
  ReadingTheme? getThemeById(String id) {
    try {
      return allThemes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Set the default theme.
  Future<void> setDefaultTheme(String themeId) async {
    _defaultThemeId = themeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultThemeId', themeId);
    notifyListeners();
  }

  /// Save a custom theme.
  Future<void> saveCustomTheme(ReadingTheme theme) async {
    final index = _customThemes.indexWhere((t) => t.id == theme.id);
    if (index >= 0) {
      _customThemes[index] = theme;
    } else {
      _customThemes.add(theme);
    }
    await _saveCustomThemes();
    notifyListeners();
  }

  /// Delete a custom theme.
  Future<void> deleteCustomTheme(String themeId) async {
    _customThemes.removeWhere((t) => t.id == themeId);
    if (_defaultThemeId == themeId) {
      _defaultThemeId = ReadingTheme.midnightPrism.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('defaultThemeId', _defaultThemeId);
    }
    await _saveCustomThemes();
    notifyListeners();
  }

  // ── Persistence ──

  Future<void> _loadCustomThemes() async {
    final file = File('$_storagePath/custom_themes.json');
    if (!await file.exists()) return;

    try {
      final json = jsonDecode(await file.readAsString()) as List<dynamic>;
      _customThemes = json
          .map((item) => ReadingTheme.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading custom themes: $e');
      _customThemes = [];
    }
  }

  Future<void> _saveCustomThemes() async {
    final file = File('$_storagePath/custom_themes.json');
    final json = _customThemes.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(json));
  }

  Future<void> _loadDefaultThemeId() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultThemeId =
        prefs.getString('defaultThemeId') ?? ReadingTheme.midnightPrism.id;
  }
}
