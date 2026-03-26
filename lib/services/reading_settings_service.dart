import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reading_settings.dart';

class ReadingSettingsService extends ChangeNotifier {
  ReadingSettings _settings = const ReadingSettings();
  bool _initialized = false;

  ReadingSettings get settings => _settings;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('readingSettings');
    if (json != null) {
      try {
        _settings = ReadingSettings.fromJson(
            jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error loading reading settings: $e');
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> update(ReadingSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('readingSettings', jsonEncode(newSettings.toJson()));
  }
}
