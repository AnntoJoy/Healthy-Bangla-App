import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../providers/language_provider.dart';
import '../article/article_detail_screen.dart';

class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  final supabase = Supabase.instance.client;
  List<Article> readingHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReadingHistory();
    });
  }

  Future<void> _loadReadingHistory() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    setState(() => isLoading = true);
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          readingHistory = [];
          isLoading = false;
        });
        return;
      }

      // Try RPC function first
      List<dynamic> response;
      try {
        response = await supabase.rpc('get_reading_history', params: {
          'user_lang': languageProvider.currentLanguage,
          'limit_count': 50,
        });
      } catch (e) {
        // Fallback: Get reading history directly from user_reading_history table
        print('RPC failed, using fallback: $e');
        
        final historyResponse = await supabase
            .from('user_reading_history')
            .select('article_id, read_at')
            .eq('user_id', userId)
            .order('read_at', ascending: false)
            .limit(50);
        
        // Get article details for each history item
        final articleIds = (historyResponse as List).map((item) => item['article_id']).toList();
        
        if (articleIds.isNotEmpty) {
          // Get all articles and filter by IDs
          final articlesResponse = await supabase
              .from('articles')
              .select('id, slug, category, cover_image, reading_time_minutes, created_at, article_translations!inner(title, body)')
              .eq('article_translations.lang', languageProvider.currentLanguage)
              .eq('published', true);
          
          // Filter results to only include articles in our history
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
      }
      
      setState(() {
        readingHistory = (response as List)
            .map((json) => Article.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading reading history: $e');
      setState(() => isLoading = false);
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
                              languageProvider.getText('Reading History', 'পড়ার ইতিহাস'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              languageProvider.getText(
                                'Articles you\'ve read recently',
                                'আপনি সম্প্রতি যে নিবন্ধগুলি পড়েছেন'
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
                        : readingHistory.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      languageProvider.getText(
                                        'No reading history yet',
                                        'এখনও কোন পড়ার ইতিহাস নেই'
                                      ),
                                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      languageProvider.getText(
                                        'Start reading articles to see your history here',
                                        'আপনার ইতিহাস দেখতে নিবন্ধ পড়া শুরু করুন'
                                      ),
                                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadReadingHistory,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: readingHistory.length,
                                  itemBuilder: (context, index) {
                                    final article = readingHistory[index];
                                    return _buildArticleCard(article, languageProvider);
                                  },
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
                        Icon(Icons.history, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          languageProvider.getText('Read', 'পড়া হয়েছে'),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
}