import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../utils/constants.dart';
import '../../providers/language_provider.dart';
import '../article/article_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final supabase = Supabase.instance.client;
  String? selectedCategory;
  List<Article> categoryArticles = [];
  Map<String, int> categoryStats = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadCategoryStats();
      }
    });
  }

  Future<void> _loadCategoryStats() async {
    if (!mounted) return;
    
    // FIXED: Use context.read instead of Provider.of
    final languageProvider = context.read<LanguageProvider>();
    
    if (mounted) {
      setState(() => isLoading = true);
    }
    
    try {
      final stats = <String, int>{};
      
      // Load stats for each category
      for (final category in AppConstants.categories.keys) {
        try {
          final response = await supabase
              .from('articles')
              .select('id')
              .eq('category', category)
              .eq('published', true);
          stats[category] = (response as List).length;
        } catch (e) {
          stats[category] = 0;
        }
      }
      
      if (mounted) {
        setState(() {
          categoryStats = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading category stats: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadCategoryArticles(String category) async {
    if (!mounted) return;
    
    // FIXED: Use context.read instead of Provider.of
    final languageProvider = context.read<LanguageProvider>();
    
    if (mounted) {
      setState(() {
        selectedCategory = category;
        isLoading = true;
      });
    }

    try {
      final response = await supabase
          .from('articles')
          .select('id, slug, category, cover_image, reading_time_minutes, created_at, article_translations!inner(title, body)')
          .eq('article_translations.lang', languageProvider.currentLanguage)
          .eq('category', category)
          .eq('published', true)
          .order('created_at', ascending: false);

      final articles = (response as List).map((item) {
        final translations = item['article_translations'] as List;
        final translation = translations.isNotEmpty ? translations[0] : {'title': '', 'body': ''};
        return Article.fromJson({
          'article_id': item['id'],
          'id': item['id'],
          'slug': item['slug'],
          'category': item['category'],
          'cover_image': item['cover_image'],
          'title': translation['title'],
          'body': translation['body'].length > 200 
              ? '${translation['body'].substring(0, 200)}...'
              : translation['body'],
          'reading_time_minutes': item['reading_time_minutes'],
          'created_at': item['created_at'],
          'comment_count': 0,
        });
      }).toList();

      if (mounted) {
        setState(() {
          categoryArticles = articles;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading articles: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading articles: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF00A896),
          body: SafeArea(
            child: Column(
              children: [
                // Green Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getText('Healthy Bangla', 'হেলদি বাংলা '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              languageProvider.getText(
                                'Health Categories',
                                'স্বাস্থ্য বিভাগসমূহ'
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              languageProvider.currentLanguage.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.language, color: Colors.white),
                            onPressed: () {
                              languageProvider.toggleLanguage();
                              _loadCategoryStats();
                              if (selectedCategory != null) {
                                _loadCategoryArticles(selectedCategory!);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // White Content Area
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (selectedCategory == null) ...[
                          // Categories Grid View
                          Expanded(
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildCategoriesGrid(languageProvider),
                          ),
                        ] else ...[
                          // Category Articles List
                          _buildCategoryHeader(languageProvider),
                          Expanded(
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildArticlesList(languageProvider),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesGrid(LanguageProvider languageProvider) {
    final categories = AppConstants.categories.keys.toList();
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final name = AppConstants.getCategoryName(category, languageProvider.currentLanguage);
        final count = categoryStats[category] ?? 0;
        
        return _buildCategoryCard(category, name, count, languageProvider);
      },
    );
  }

  Widget _buildCategoryCard(String category, String name, int count, LanguageProvider languageProvider) {
    final colors = {
      'heart_health': const Color(0xFFE74C3C),
      'nutrition': const Color(0xFF27AE60),
      'mental_health': const Color(0xFF9B59B6),
      'maternal_health': const Color(0xFFE91E63),
      'child_health': const Color(0xFF3498DB),
      'general_medicine': const Color(0xFF16A085),
    };
    
    final icons = {
      'heart_health': Icons.favorite,
      'nutrition': Icons.restaurant,
      'mental_health': Icons.psychology,
      'maternal_health': Icons.pregnant_woman,
      'child_health': Icons.child_care,
      'general_medicine': Icons.medical_services,
    };
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _loadCategoryArticles(category),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[category] ?? const Color(0xFF00A896),
                (colors[category] ?? const Color(0xFF00A896)).withOpacity(0.7),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icons[category] ?? Icons.article,
                  color: Colors.white,
                  size: 32,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        languageProvider.getText(
                          '$count articles',
                          '$count টি নিবন্ধ'
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(LanguageProvider languageProvider) {
    final categoryName = AppConstants.getCategoryName(selectedCategory!, languageProvider.currentLanguage);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                selectedCategory = null;
                categoryArticles.clear();
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  languageProvider.getText(
                    '${categoryArticles.length} articles',
                    '${categoryArticles.length} টি নিবন্ধ'
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesList(LanguageProvider languageProvider) {
    if (categoryArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              languageProvider.getText(
                'No articles in this category yet',
                'এই বিভাগে এখনো কোন নিবন্ধ নেই'
              ),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCategoryArticles(selectedCategory!),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: categoryArticles.length,
        itemBuilder: (context, index) {
          final article = categoryArticles[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailScreen(
                      slug: article.slug,
                      language: languageProvider.currentLanguage,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: article.coverImage != null
                            ? Image.network(
                                article.coverImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image),
                              )
                            : const Icon(Icons.health_and_safety, size: 40),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.body,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${article.readingTimeMinutes} ${languageProvider.getText('min', 'মিনিট')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
        },
      ),
    );
  }
}