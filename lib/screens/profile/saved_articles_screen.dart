import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../providers/language_provider.dart';
import '../article/article_detail_screen.dart';

class SavedArticlesScreen extends StatefulWidget {
  const SavedArticlesScreen({Key? key}) : super(key: key);

  @override
  State<SavedArticlesScreen> createState() => _SavedArticlesScreenState();
}

class _SavedArticlesScreenState extends State<SavedArticlesScreen> {
  final supabase = Supabase.instance.client;
  List<Article> savedArticles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedArticles();
    });
  }

  Future<void> _loadSavedArticles() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    setState(() => isLoading = true);
    
    try {
      // Try RPC function first
      List<dynamic> response;
      try {
        response = await supabase.rpc('get_bookmarked_articles', params: {
          'user_lang': languageProvider.currentLanguage,
        });
      } catch (e) {
        // Fallback: Get bookmarked articles directly
        print('RPC failed, using fallback: $e');
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final bookmarksResponse = await supabase
              .from('user_bookmarks')
              .select('article_id')
              .eq('user_id', userId)
              .eq('is_bookmarked', true);
          
          // Get article details for each bookmark
          final articleIds = (bookmarksResponse as List).map((item) => item['article_id']).toList();
          
          if (articleIds.isNotEmpty) {
            // Get all articles and filter by IDs
            final articlesResponse = await supabase
                .from('articles')
                .select('id, slug, category, cover_image, reading_time_minutes, created_at, article_translations!inner(title, body)')
                .eq('article_translations.lang', languageProvider.currentLanguage)
                .eq('published', true);
            
            // Filter results to only include bookmarked articles
            final filteredArticles = (articlesResponse as List).where((item) => 
                articleIds.contains(item['id'])
            ).toList();
            
            // Transform to match expected format
            response = filteredArticles.map((item) {
              final translation = item['article_translations'][0];
              return {
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
              };
            }).toList();
          } else {
            response = [];
          }
        } else {
          response = [];
        }
      }
      
      setState(() {
        savedArticles = (response as List)
            .map((json) => Article.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading saved articles: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeBookmark(String articleId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase
            .from('user_bookmarks')
            .update({'is_bookmarked': false})
            .eq('user_id', userId)
            .eq('article_id', articleId);
        
        // Remove from local list
        setState(() {
          savedArticles.removeWhere((article) => article.id == articleId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<LanguageProvider>(context, listen: false).getText(
                'Article removed from bookmarks',
                'বুকমার্ক থেকে নিবন্ধ সরানো হয়েছে'
              )
            ),
          ),
        );
      }
    } catch (e) {
      print('Error removing bookmark: $e');
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
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getText('Saved Articles', 'সংরক্ষিত নিবন্ধ'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              languageProvider.getText(
                                'Your bookmarked articles',
                                'আপনার বুকমার্ক করা নিবন্ধসমূহ'
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : savedArticles.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      languageProvider.getText(
                                        'No saved articles yet',
                                        'এখনও কোন সংরক্ষিত নিবন্ধ নেই'
                                      ),
                                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      languageProvider.getText(
                                        'Bookmark articles to save them for later reading',
                                        'পরে পড়ার জন্য নিবন্ধগুলি বুকমার্ক করুন'
                                      ),
                                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadSavedArticles,
                                child: Column(
                                  children: [
                                    // Article count header
                                    if (savedArticles.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              languageProvider.getText(
                                                '${savedArticles.length} saved articles',
                                                '${savedArticles.length} টি সংরক্ষিত নিবন্ধ'
                                              ),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                // Clear all bookmarks
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: Text(languageProvider.getText('Clear All Bookmarks?', 'সব বুকমার্ক মুছবেন?')),
                                                    content: Text(
                                                      languageProvider.getText(
                                                        'This action cannot be undone.',
                                                        'এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।'
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: Text(languageProvider.getText('Cancel', 'বাতিল')),
                                                      ),
                                                      TextButton(
                                                        onPressed: () async {
                                                          Navigator.pop(context);
                                                          // Clear all bookmarks logic here
                                                        },
                                                        child: Text(
                                                          languageProvider.getText('Clear All', 'সব মুছুন'),
                                                          style: const TextStyle(color: Colors.red),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Text(languageProvider.getText('Clear All', 'সব মুছুন')),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Articles list
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        itemCount: savedArticles.length,
                                        itemBuilder: (context, index) {
                                          final article = savedArticles[index];
                                          return _buildArticleCard(article, languageProvider);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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

  Widget _buildArticleCard(Article article, LanguageProvider languageProvider) {
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Icon(Icons.bookmark, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          languageProvider.getText('Saved', 'সংরক্ষিত'),
                          style: const TextStyle(fontSize: 12, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_remove, color: Colors.red),
                onPressed: () => _removeBookmark(article.id),
                tooltip: languageProvider.getText('Remove bookmark', 'বুকমার্ক সরান'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}