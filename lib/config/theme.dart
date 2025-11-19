import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors from your UI
  static const Color primaryGreen = Color(0xFF00A896);
  static const Color darkGreen = Color(0xFF028574);
  static const Color lightGreen = Color(0xFFE8F5F3);
  
  // Category Colors
  static const Color heartHealthColor = Color(0xFFE74C3C);
  static const Color nutritionColor = Color(0xFF27AE60);
  static const Color mentalHealthColor = Color(0xFF9B59B6);
  static const Color maternalHealthColor = Color(0xFFE91E63);
  static const Color childHealthColor = Color(0xFF3498DB);
  static const Color generalMedicineColor = Color(0xFF16A085);
  
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: darkGreen,
        surface: Colors.white,
      ),
      
      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Text Theme
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          color: Colors.black87,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          color: Colors.black54,
        ),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
        unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
        type: BottomNavigationBarType.fixed,
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      
      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  // Get category color
  static Color getCategoryColor(String category) {
    switch (category) {
      case 'heart_health':
        return heartHealthColor;
      case 'nutrition':
        return nutritionColor;
      case 'mental_health':
        return mentalHealthColor;
      case 'maternal_health':
        return maternalHealthColor;
      case 'child_health':
        return childHealthColor;
      case 'general_medicine':
        return generalMedicineColor;
      default:
        return primaryGreen;
    }
  }
  
  // Get category icon
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'heart_health':
        return Icons.favorite;
      case 'nutrition':
        return Icons.restaurant;
      case 'mental_health':
        return Icons.psychology;
      case 'maternal_health':
        return Icons.pregnant_woman;
      case 'child_health':
        return Icons.child_care;
      case 'general_medicine':
        return Icons.medical_services;
      default:
        return Icons.health_and_safety;
    }
  }
}