import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleKey = 'splitly_locale';

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale('en')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLocaleKey);
    if (saved != null) state = Locale(saved);
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, languageCode);
    state = Locale(languageCode);
  }
}

final localeControllerProvider =
StateNotifierProvider<LocaleController, Locale>((ref) => LocaleController());