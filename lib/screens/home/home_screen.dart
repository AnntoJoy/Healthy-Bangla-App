import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

import '../../models/article.dart';
import '../../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Article> _featuredArticles = [];
  Map<String, int> _categoryCounts = {};
  String? _dailyTip;
  bool _isLoading = true;
  String _currentLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadUserLanguage();
  }

  // Load user's preferred language from database
  Future<void> _loadUserLanguage() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response = await _supabase
            .from('users')
            .select('preferred_language')
            .eq('id', userId)
            .single();

        setState(() {
          _currentLanguage = response['preferred_language'] ?? 'en';
        });
      }
    } catch (e) {
      print('Error loading user language: $e');
    }

    // Load data after getting language
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      print('Loading data with language: $_currentLanguage');

      // Fetch featured articles with translations
      final articlesData = await _supabase
          .from('articles')
          .select('*, article_translations(*)')
          .eq('published', true)
          .order('created_at', ascending: false)
          .limit(4);

      print('Articles data: $articlesData');

      if (articlesData != null && articlesData is List) {
        _featuredArticles = articlesData.map((json) {
          // Find translation for current language
          final translations = json['article_translations'] as List?;
          print('Translations found: ${translations?.length}');

          final translation = translations?.firstWhere(
                (t) => t['lang'] == _currentLanguage,
                orElse: () => translations?.isNotEmpty == true
                    ? translations!.first
                    : {},
              ) ??
              {};

          return Article.fromJson({
            ...json,
            'title': translation['title'] ?? 'No title',
            'body': translation['body'] ?? 'No content',
            'disclaimer': translation['disclaimer'],
          });
        }).toList();

        print('Loaded ${_featuredArticles.length} articles');
      }

      // Fetch category counts
      for (var category in AppConstants.categories.keys) {
        try {
          final countData = await _supabase
              .from('articles')
              .select('id')
              .eq('category', category)
              .eq('published', true);

          _categoryCounts[category] =
              countData != null && countData is List ? countData.length : 0;
        } catch (e) {
          print('Error fetching count for $category: $e');
          _categoryCounts[category] = 0;
        }
      }

      print('Category counts: $_categoryCounts');

      // Fetch daily health tip
      try {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final tipData = await _supabase
            .from('health_tips')
            .select('*, health_tip_translations(*)')
            .eq('tip_date', today)
            .limit(1);

        if (tipData != null && tipData is List && tipData.isNotEmpty) {
          final tip = tipData.first;
          final tipTranslations = tip['health_tip_translations'] as List?;
          final tipTranslation = tipTranslations?.firstWhere(
                (t) => t['lang'] == _currentLanguage,
                orElse: () => tipTranslations?.isNotEmpty == true
                    ? tipTranslations!.first
                    : {},
              ) ??
              {};

          _dailyTip = tipTranslation['tip_text'];
          print('Daily tip: $_dailyTip');
        }
      } catch (e) {
        print('Error fetching daily tip: $e');
        _dailyTip = null;
      }
    } catch (e) {
      print('ERROR loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLanguage() async {
  try {
    // Use the same provider that other screens use
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    // First toggle the global language (this is what Search/Category use)
    languageProvider.toggleLanguage();

    // Get the new language from the provider
    final newLanguage = languageProvider.currentLanguage;

    // Update DB so the preference is saved for next time
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _supabase
          .from('users')
          .update({'preferred_language': newLanguage})
          .eq('id', userId);
    }

    // Keep Home's local state in sync
    setState(() {
      _currentLanguage = newLanguage;
    });

    // Reload articles / tips in the new language
    _loadData();
  } catch (e) {
    print('Error updating language: $e');
  }
}


  Future<void> _handleLogout() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00A896),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Healthy Bangla',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Your Health Companion',
              style: TextStyle(
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _toggleLanguage,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // -------- FEATURED ARTICLES --------
                    if (_featuredArticles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No articles available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check console for errors',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._featuredArticles
                          .map((article) => _buildArticleCard(article))
                          .toList(),

                    // -------- HEALTH CATEGORIES --------
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                      child: Text(
                        'Health Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildCategoriesGrid(),
                    ),

                    // -------- DAILY HEALTH TIP --------
                    if (_dailyTip != null)
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: _buildDailyTip(),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/article-detail',
            arguments: {
              'slug': article.slug,
              'language': _currentLanguage,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: article.coverImage != null
                    ? Image.network(
                        article.coverImage!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.article,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.article,
                          color: Colors.grey,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${article.readingTimeMinutes} min',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = AppConstants.categories.keys.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final name =
            AppConstants.getCategoryName(category, _currentLanguage);
        final count = _categoryCounts[category] ?? 0;

        return _buildCategoryCard(category, name, count);
      },
    );
  }

  Widget _buildCategoryCard(String category, String name, int count) {
    final colors = {
      'heart_health': [
        const Color(0xFFE63946),
        const Color(0xFFF48C8C)
      ],
      'nutrition': [
        const Color(0xFF06D6A0),
        const Color(0xFF5FE3B8)
      ],
      'mental_health': [
        const Color(0xFF8338EC),
        const Color(0xFFA76BF4)
      ],
      'maternal_health': [
        const Color(0xFFE91E63),
        const Color(0xFFF06292)
      ],
      'child_health': [
        const Color(0xFF1E88E5),
        const Color(0xFF64B5F6)
      ],
      'general_medicine': [
        const Color(0xFF00A896),
        const Color(0xFF4CC9BE)
      ],
    };

    final icons = {
      'heart_health': Icons.favorite,
      'nutrition': Icons.restaurant,
      'mental_health': Icons.psychology,
      'maternal_health': Icons.pregnant_woman,
      'child_health': Icons.child_care,
      'general_medicine': Icons.medical_services,
    };

    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/category-articles',
          arguments: {
            'category': category,
            'categoryName': name,
            'language': _currentLanguage,
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors[category]!,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icons[category],
              color: Colors.white,
              size: 28,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count articles',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTip() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF00A896),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Health Tips',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _dailyTip!,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/health-tips');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00A896),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              elevation: 0,
            ),
            child: const Text(
              'Learn More',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
