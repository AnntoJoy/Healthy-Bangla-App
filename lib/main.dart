import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/language_provider.dart';

// Tab container
import 'screens/main_screen.dart';

// Auth
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

// Categories & articles
import 'screens/categories/category_articles_screen.dart';
import 'screens/article/article_detail_screen.dart';

// Profile area
import 'screens/profile/profile_screen.dart';
import 'screens/profile/reading_history_screen.dart';
import 'screens/profile/saved_articles_screen.dart';
import 'screens/profile/settings_screen.dart';

// Search screen (used as a named route too if needed)
import 'screens/search/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pnohqvwtonasafjipcwx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBub2hxdnd0b25hc2FmamlwY3d4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MjMwMTQsImV4cCI6MjA3ODA5OTAxNH0._J0k34A6bSFDlvYaOfLFIH0cDIfFBY8MLVYdwy9_9gQ',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        title: 'Healthy Bangla',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.teal,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00A896),
          ),
          useMaterial3: true,
        ),

        // ---------- ROUTES ----------
        // The app shell with bottom nav:
        initialRoute: '/main',
        routes: {
          // Main tabs container (Home, Categories, Search, Profile)
          '/main': (context) => const MainScreen(),

          // Auth
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),

          // Search as a standalone route (e.g. from a button)
          '/search': (context) => const SearchScreen(),

          // Articles under a specific category
          '/category-articles': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;

            return CategoryArticlesScreen(
              category: args['category'] as String,
              categoryName: args['categoryName'] as String,
              language: args['language'] as String,
            );
          },

          // Article detail – slug + language are passed from HomeScreen
          '/article-detail': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;

            return ArticleDetailScreen(
              slug: args['slug'] as String,
              language: args['language'] as String,
            );
          },

          // Profile area extra screens
          '/profile': (context) => const ProfileScreen(),
          '/reading-history': (context) => const ReadingHistoryScreen(),
          '/saved-articles': (context) => const SavedArticlesScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}
