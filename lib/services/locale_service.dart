import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that manages the user's language preference.
/// 
/// On [init], it loads the persisted locale from SharedPreferences.
/// If none is saved, it falls back to the device's system locale,
/// defaulting to English if the device language is not supported.
class LocaleService extends ChangeNotifier {
  static final LocaleService _instance = LocaleService._();
  factory LocaleService() => _instance;
  LocaleService._();

  static const String _prefKey = 'app_locale';
  static const List<String> supportedCodes = ['en', 'es'];

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  /// Initialize the service: load persisted preference or detect device locale.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);

    if (saved != null && supportedCodes.contains(saved)) {
      _locale = Locale(saved);
    } else {
      // Auto-detect from device
      final deviceLang = Platform.localeName.split('_').first.toLowerCase();
      if (supportedCodes.contains(deviceLang)) {
        _locale = Locale(deviceLang);
      } else {
        _locale = const Locale('en');
      }
    }
  }

  /// Change the app's locale. Persists to prefs and notifies listeners.
  Future<void> setLocale(Locale newLocale) async {
    if (!supportedCodes.contains(newLocale.languageCode)) return;
    if (_locale == newLocale) return;

    _locale = newLocale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newLocale.languageCode);
  }
}
