import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../models/comment.dart';
import '../../providers/language_provider.dart';
import '../../screens/profile/reading_history_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final String slug;
  final String language;

  const ArticleDetailScreen({
    Key? key,
    required this.slug,
    required this.language,
  }) : super(key: key);

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final supabase = Supabase.instance.client;
  final _commentController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  
  Article? article;
  List<Comment> comments = [];
  bool isLoading = true;
  bool isBookmarked = false;
  bool isLiked = false;
  bool isCommenting = false;
  bool isReading = false;
  String? replyingToCommentId;
  String? replyingToUsername;


  Future<void> _recordReadingHistory() async {
    final session = supabase.auth.currentSession;
    if (session == null || article == null) return;

    try {
      await supabase.from('reading_history').insert({
        'user_id': session.user.id,
        'article_id': article!.id,
        // 'read_at': DateTime.now().toIso8601String(), // optional; DB default
      });
    } catch (e) {
      print('Error inserting into reading_history: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadArticle();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage(widget.language == 'en' ? 'en-US' : 'bn-IN');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => isReading = false);
        }
      });
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  Future<void> _toggleReadAloud() async {
    if (isReading) {
      await _flutterTts.stop();
      setState(() => isReading = false);
    } else {
      if (article != null) {
        setState(() => isReading = true);
        
        try {
          // Read title first
          await _flutterTts.speak(article!.title);
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Then read body
          await _flutterTts.speak(article!.body);
        } catch (e) {
          print('TTS error: $e');
          setState(() => isReading = false);
        }
      }
    }
  }

   Future<void> _loadArticle() async {
    setState(() => isLoading = true);
    
    try {
      // Load article details using your RPC function
      final articleResponse = await supabase.rpc('get_article_detail', params: {
        'article_slug': widget.slug,
        'user_lang': widget.language,
      });
      
      if ((articleResponse as List).isNotEmpty) {
        article = Article.fromJson(articleResponse[0]);
        isBookmarked = article!.isBookmarked ?? false;
        isLiked = article!.isLiked ?? false;
        
        // ✅ record reading history row
        await _recordReadingHistory();

        // (optional) still call mark_as_read for view_count
        try {
          await supabase.rpc('mark_as_read', params: {
            'article_id': article!.id,
          });
        } catch (e) {
          print('mark_as_read RPC failed (non-fatal): $e');
        }
        
        // Load comments
        await _loadComments();
      }
      
      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading article: $e');
      setState(() => isLoading = false);
    }
  }


  Future<void> _loadComments() async {
  try {
    // FIX 1: Included 'user_name' in the select query to fetch the name saved directly
    // when a comment is posted, resolving the 'Anonymous' issue.
    final response = await supabase
        .from('comments')
        .select('*, users(full_name), user_name') 
        .eq('article_id', article!.id)
        .order('created_at', ascending: false);

    // Print clearly readable JSON to console
    print('=== RAW COMMENTS RESPONSE ===');
    print(jsonEncode(response)); 

    // Try to parse only if response is a List
    if (response is List) {
      setState(() {
        comments = response.map((e) {
          final map = e as Map<String, dynamic>;
          return Comment.fromJson(map);
        }).toList();
      });
    } else {
      print('Comments response is not a List: ${response.runtimeType}');
    }
  } catch (e, st) {
    print('Error loading comments: $e\n$st');
  }
}




  Future<void> _toggleBookmark() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showLoginPrompt();
      return;
    }

    try {
      final result = await supabase.rpc('toggle_bookmark', params: {
        'article_id': article!.id,
      });
      
      setState(() {
        isBookmarked = result as bool;
      });
      
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBookmarked 
                ? languageProvider.getText('Saved!', 'সংরক্ষিত!')
                : languageProvider.getText('Removed from saved', 'সংরক্ষিত থেকে সরানো হয়েছে')
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error toggling bookmark: $e');
    }
  }

  Future<void> _toggleLike() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      _showLoginPrompt();
      return;
    }

    try {
      final result = await supabase.rpc('toggle_like', params: {
        'article_id': article!.id,
      });
      
      setState(() {
        isLiked = result as bool;
      });
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> _postComment() async {
  final session = supabase.auth.currentSession;
  if (session == null) { 
    _showLoginPrompt(); 
    return; 
  }

  final content = _commentController.text.trim();
  if (content.isEmpty) return;

  setState(() => isCommenting = true);

  try {
    final user = session.user;

    // FIX: no more profiles table!
    final fullName =
        user.userMetadata?['full_name']?.toString() ??
        user.email ??
        'Anonymous';

    final insertResp = await supabase.from('comments').insert({
      'article_id': article!.id,
      'user_id': user.id,
      'content': content,
      'parent_comment_id': replyingToCommentId,
      'user_name': fullName,
    });

    print("Insert Response: $insertResp");

    _commentController.clear();
    replyingToCommentId = null;
    replyingToUsername = null;

    await _loadComments();

    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(languageProvider.getText(
            'Comment posted!', 'মন্তব্য পোস্ট করা হয়েছে!')),
      ),
    );
  } catch (e, st) {
    print('Error posting comment: $e');
  } finally {
    setState(() => isCommenting = false);
  }
}


  void _setReplyTo(String commentId, String username) {
    setState(() {
      replyingToCommentId = commentId;
      replyingToUsername = username;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      replyingToCommentId = null;
      replyingToUsername = null;
    });
  }

  void _showLoginPrompt() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(languageProvider.getText('Please login to continue', 'চালিয়ে যেতে লগইন করুন')),
        action: SnackBarAction(
          label: languageProvider.getText('Login', 'লগইন'),
          onPressed: () {
            // Navigate to login
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : article == null
                  ? Center(
                      child: Text(
                        languageProvider.getText('Article not found', 'নিবন্ধ পাওয়া যায়নি'),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // App Bar with Image
                        SliverAppBar(
                          expandedHeight: 250,
                          pinned: true,
                          backgroundColor: const Color(0xFF00A896),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          actions: [
                            // Text-to-Speech Button
                            IconButton(
                              icon: Icon(
                                isReading ? Icons.stop : Icons.volume_up,
                                color: Colors.white,
                              ),
                              tooltip: languageProvider.getText('Read Aloud', 'উচ্চস্বরে পড়ুন'),
                              onPressed: _toggleReadAloud,
                            ),
                            // Bookmark Button
                            IconButton(
                              icon: Icon(
                                isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                color: Colors.white,
                              ),
                              onPressed: _toggleBookmark,
                            ),
                            // Share Button
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              onPressed: () {
                                if (article != null) {
                                  Share.share(
                                    languageProvider.getText(
                                      'Check out this article: ${article!.title}',
                                      'এই নিবন্ধটি দেখুন: ${article!.title}'
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            background: article!.coverImage != null
                                ? Image.network(
                                    article!.coverImage!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF00A896),
                                      child: const Icon(
                                        Icons.health_and_safety,
                                        size: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF00A896),
                                    child: const Icon(
                                      Icons.health_and_safety,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        // Article Content
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  article!.title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Meta Info
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${article!.readingTimeMinutes} ${languageProvider.getText('min read', 'মিনিট পড়া')}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      _formatDate(article!.createdAt, languageProvider),
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Important Info Banner (if maternal health)
                                if (article!.category == 'maternal_health')
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      border: Border.all(color: Colors.blue.shade200),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            languageProvider.getText(
                                              'Important information for expectant mothers.',
                                              'গর্ভবতী মায়েদের জন্য গুরুত্বপূর্ণ তথ্য।'
                                            ),
                                            style: TextStyle(
                                              color: Colors.blue.shade900,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Excerpt (first sentence highlighted)
                                if (article!.body.contains('.'))
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00A896).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      article!.body.split('.').first + '.',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                
                                // Body
                                Text(
                                  article!.body,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.black87,
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Disclaimer
                                if (article!.disclaimer != null)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            article!.disclaimer!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                const SizedBox(height: 32),
                                
                                // Like Section
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? Colors.red : Colors.grey,
                                      ),
                                      onPressed: _toggleLike,
                                    ),
                                    Text('${article!.likeCount ?? 0}'),
                                  ],
                                ),
                                
                                const Divider(height: 32),
                                
                                // Comments Section
                                Text(
                                  '${languageProvider.getText('Comments', 'মন্তব্য')} (${comments.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Reply indicator
                                if (replyingToUsername != null)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            languageProvider.getText(
                                              'Replying to $replyingToUsername',
                                              '$replyingToUsername কে উত্তর দিচ্ছেন'
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                                          onPressed: _cancelReply,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // Comment Input
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _commentController,
                                        decoration: InputDecoration(
                                          hintText: languageProvider.getText(
                                            'Write your comment...',
                                            'আপনার মন্তব্য লিখুন...'
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(24),
                                            borderSide: const BorderSide(color: Color(0xFF00A896)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(24),
                                            borderSide: const BorderSide(color: Color(0xFF00A896), width: 2),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: isCommenting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.send),
                                      onPressed: isCommenting ? null : _postComment,
                                      color: const Color(0xFF00A896),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Comments List
                                ...comments
                                    .where((c) => c.parentCommentId == null)
                                    .map((comment) {
                                  final replies = comments
                                      .where((c) => c.parentCommentId == comment.id)
                                      .toList();
                                  
                                  return Column(
                                    children: [
                                      _buildCommentCard(comment, languageProvider),
                                      if (replies.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 40),
                                          child: Column(
                                            children: replies
                                                .map((reply) => _buildCommentCard(
                                                      reply,
                                                      languageProvider,
                                                      isReply: true,
                                                    ))
                                                .toList(),
                                          ),
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildCommentCard(Comment comment, LanguageProvider languageProvider, {bool isReply = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF00A896),
                  child: Text(
                    // FIX 2: Ensures the value is non-nullable before calling .toUpperCase()
                    (comment.userName?.substring(0, 1) ?? 'A').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName ?? languageProvider.getText('Anonymous', 'বেনামী'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(comment.createdAt, languageProvider),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment.content,
              style: const TextStyle(fontSize: 14),
            ),
            if (!isReply)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _setReplyTo(
                    comment.id,
                    comment.userName ?? languageProvider.getText('Anonymous', 'বেনামী'),
                  ),
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text(languageProvider.getText('Reply', 'উত্তর দিন')),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00A896),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, LanguageProvider languageProvider) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return languageProvider.getText('${difference.inDays}d ago', '${difference.inDays} দিন আগে');
    } else if (difference.inHours > 0) {
      return languageProvider.getText('${difference.inHours}h ago', '${difference.inHours} ঘন্টা আগে');
    } else {
      return languageProvider.getText('Just now', 'এখনই');
    }
  }
}