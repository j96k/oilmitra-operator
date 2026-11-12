/// Language service for OilMitra-Supplier.
///
/// Stores the selected language in shared_preferences and notifies listeners
/// when it changes so the whole app can rebuild with the new translations.
///
/// Only used by the supplier app (main.dart). The operator and portal apps
/// (main_admin.dart / main_myoilmitra.dart) do not import this.
library language_service;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLang = 'oilmitra_lang';

/// Supported languages: code -> display name.
final Map<String, String> languageOptions = {
  'en': 'English',
  'hi': 'हिन्दी (Hindi)',
  'gu': 'ગુજરાતી (Gujarati)',
};

class LanguageService extends ChangeNotifier {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  String _locale = 'en';

  String get locale => _locale;
  String get displayName => languageOptions[_locale] ?? 'English';

  /// Load the saved language (default English). Call this before runApp.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLang);
    if (saved != null && languageOptions.containsKey(saved)) {
      _locale = saved;
    }
    notifyListeners();
  }

  /// Save and switch language. Rebuilds the app via notifyListeners.
  Future<void> set(String code) async {
    if (!languageOptions.containsKey(code)) return;
    if (_locale == code) return;
    _locale = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, code);
    notifyListeners();
  }
}
