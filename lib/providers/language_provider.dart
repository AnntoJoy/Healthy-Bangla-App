import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LanguageProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  String _currentLanguage = 'en';
  bool _isInitialized = false;
  
  String get currentLanguage => _currentLanguage;
  bool get isInitialized => _isInitialized;
  
  LanguageProvider() {
    _loadLanguageFromDatabase();
  }
  
  // Load saved language from database
  Future<void> _loadLanguageFromDatabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await _supabase
            .from('users')
            .select('preferred_language')
            .eq('id', userId)
            .single();
        
        _currentLanguage = response['preferred_language'] ?? 'en';
      }
    } catch (e) {
      print('Error loading language from database: $e');
      _currentLanguage = 'en';
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }
  
  // Save language to database
  Future<void> _saveLanguageToDatabase(String language) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('users')
            .update({'preferred_language': language})
            .eq('id', userId);
      }
    } catch (e) {
      print('Error saving language preference: $e');
    }
  }
  
  // Set new language
  Future<void> setLanguage(String language) async {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      await _saveLanguageToDatabase(language);
      notifyListeners();
    }
  }
  
  // Toggle between languages
  Future<void> toggleLanguage() async {
    final newLanguage = _currentLanguage == 'en' ? 'bn' : 'en';
    await setLanguage(newLanguage);
  }
  
  // Get localized text
  String getText(String englishText, String banglaText) {
    return _currentLanguage == 'en' ? englishText : banglaText;
  }
  
  // Check if current language is Bengali
  bool get isBengali => _currentLanguage == 'bn';
  
  // Check if current language is English
  bool get isEnglish => _currentLanguage == 'en';
  
  // Reload language from database (useful after login)
  Future<void> reloadLanguage() async {
    await _loadLanguageFromDatabase();
  }
}