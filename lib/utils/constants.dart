class AppConstants {
  // App Info
  static const String appName = 'Healthy Bangla';
  static const String appTagline = 'Your Health Companion';
  
  // Categories
  static const Map<String, Map<String, String>> categories = {
    'heart_health': {
      'en': 'Heart Health',
      'bn': 'হৃদরোগ',
    },
    'nutrition': {
      'en': 'Nutrition',
      'bn': 'পুষ্টি',
    },
    'mental_health': {
      'en': 'Mental Health',
      'bn': 'মানসিক স্বাস্থ্য',
    },
    'maternal_health': {
      'en': 'Maternal Health',
      'bn': 'মাতৃ স্বাস্থ্য',
    },
    'child_health': {
      'en': 'Child Health',
      'bn': 'শিশু স্বাস্থ্য',
    },
    'general_medicine': {
      'en': 'General Medicine',
      'bn': 'সাধারণ চিকিৎসা',
    },
  };
  
  // Get category name
  static String getCategoryName(String category, String lang) {
    return categories[category]?[lang] ?? category;
  }
  
  // Event Types
  static const Map<String, Map<String, String>> eventTypes = {
    'blood_donation': {
      'en': 'Blood Donation',
      'bn': 'রক্তদান',
    },
    'medical_camp': {
      'en': 'Medical Camp',
      'bn': 'চিকিৎসা শিবির',
    },
    'health_checkup': {
      'en': 'Health Checkup',
      'bn': 'স্বাস্থ্য পরীক্ষা',
    },
    'vaccination': {
      'en': 'Vaccination',
      'bn': 'টিকাকরণ',
    },
  };
  
  // Navigation Labels
  static const Map<String, String> navLabels = {
    'home_en': 'Home',
    'home_bn': 'হোম',
    'categories_en': 'Categories',
    'categories_bn': 'বিভাগ',
    'search_en': 'Search',
    'search_bn': 'অনুসন্ধান',
    'profile_en': 'Profile',
    'profile_bn': 'প্রোফাইল',
  };
}