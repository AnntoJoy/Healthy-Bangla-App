import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../providers/language_provider.dart';
import '../article/article_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<Article> searchResults = [];
  bool isSearching = false;
  bool hasSearched = false;

  final Map<String, List<String>> bengaliKeywords = {
    'হার্ট': ['heart', 'cardiac'],
    'হৃদরোগ': ['heart', 'cardiac', 'cardiovascular'],
    'রক্তচাপ': ['blood pressure', 'hypertension', 'pressure'],
    'পুষ্টি': ['nutrition', 'diet', 'nutritional'],
    'খাদ্য': ['food', 'diet', 'nutrition'],
    'মানসিক': ['mental', 'mind', 'psychological'],
    'চাপ': ['stress', 'pressure', 'tension'],
    'গর্ভাবস্থা': ['pregnancy', 'pregnant', 'prenatal'],
    'শিশু': ['child', 'children', 'baby', 'pediatric'],
    'স্বাস্থ্য': ['health', 'medical', 'wellness'],
    'চিকিৎসা': ['medicine', 'treatment', 'medical', 'therapy'],
    'ডাক্তার': ['doctor', 'physician'],
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _expandSearchTerms(String query) {
    final terms = <String>{query.toLowerCase().trim()};

    for (final bengaliWord in bengaliKeywords.keys) {
      if (query.contains(bengaliWord)) {
        terms.addAll(bengaliKeywords[bengaliWord]!);
      }
    }
    return terms.toList();
  }

  bool _matchesSearchTerms(Map<String, dynamic> item, List<String> searchTerms) {
    final translation = item['article_translations'][0];
    final title = translation['title'].toString().toLowerCase();
    final body = translation['body'].toString().toLowerCase();
    final category = item['category'].toString().toLowerCase();

    for (final term in searchTerms) {
      if (title.contains(term) ||
          body.contains(term) ||
          category.contains(term)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;

    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    setState(() {
      isSearching = true;
      hasSearched = true;
    });

    try {
      final response = await supabase
          .from('articles')
          .select(
            'id, slug, category, cover_image, reading_time_minutes, created_at, '
            'article_translations!inner(title, body)',
          )
          .eq('article_translations.lang', languageProvider.currentLanguage)
          .eq('published', true);

      final searchTerms = _expandSearchTerms(query);

      final filteredResults = (response as List).where((item) {
        return _matchesSearchTerms(item, searchTerms);
      }).toList();

      setState(() {
        searchResults = filteredResults.map((json) {
          final translation = json['article_translations'][0];
          return Article.fromJson({
            'article_id': json['id'],
            'id': json['id'],
            'slug': json['slug'],
            'category': json['category'],
            'cover_image': json['cover_image'],
            'title': translation['title'],
            'body': translation['body'].length > 200
                ? '${translation['body'].substring(0, 200)}...'
                : translation['body'],
            'reading_time_minutes': json['reading_time_minutes'],
            'created_at': json['created_at'],
            'comment_count': 0,
          });
        }).toList();
        isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => isSearching = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
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
                // ---------------- HEADER ----------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT SIDE — TITLE + SUBTITLE
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            languageProvider.getText(
                              'Healthy Bangla',
                              'হেলদি বাংলা',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            languageProvider.getText(
                              'Your Health Companion',
                              'আপনার স্বাস্থ্য সহায়ক',
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // RIGHT SIDE — LANG + ICON
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
                          IconButton(
                            icon: const Icon(Icons.language, color: Colors.white),
                            onPressed: () {
                              languageProvider.toggleLanguage();
                              setState(() {
                                hasSearched = false;
                                searchResults.clear();
                                _searchController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ---------------- BODY CONTAINER ----------------
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: languageProvider.getText(
                                'Search health information...',
                                'স্বাস্থ্য তথ্য অনুসন্ধান করুন...',
                              ),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          hasSearched = false;
                                          searchResults.clear();
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            onSubmitted: _search,
                            onChanged: (value) => setState(() {}),
                          ),
                        ),

                        Expanded(
                          child: isSearching
                              ? const Center(child: CircularProgressIndicator())
                              : hasSearched
                                  ? _buildSearchResults(languageProvider)
                                  : _buildDefaultContent(languageProvider),
                        ),
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

  Widget _buildDefaultContent(LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            languageProvider.getText(
              'Search for health information',
              'স্বাস্থ্য তথ্য খুঁজুন',
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            languageProvider.getText(
              'Try: "heart", "nutrition", "mental health"',
              'চেষ্টা করুন: "হার্ট", "পুষ্টি", "মানসিক স্বাস্থ্য"',
            ),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(LanguageProvider languageProvider) {
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              languageProvider.getText(
                'No results found',
                'কোন ফলাফল পাওয়া যায়নি',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            languageProvider.getText(
              'Found ${searchResults.length} results',
              '${searchResults.length}টি ফলাফল পাওয়া গেছে',
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: searchResults.length,
            itemBuilder: (context, index) {
              final article = searchResults[index];
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
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image),
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
                                  Icon(Icons.access_time,
                                      size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${article.readingTimeMinutes} min',
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
        ),
      ],
    );
  }
}
