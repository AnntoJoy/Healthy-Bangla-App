import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'create_article_screen.dart';
import 'edit_article_screen.dart';
import '../../models/article.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;
  List<Article> articles = [];
  bool isLoading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoadArticles();
  }

  Future<void> _checkAdminAndLoadArticles() async {
    setState(() => isLoading = true);
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final userResponse = await supabase
            .from('users')
            .select('role')
            .eq('id', userId)
            .single();
        
        if (userResponse['role'] == 'admin') {
          setState(() => isAdmin = true);
          await _loadArticles();
        } else {
          setState(() {
            isAdmin = false;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error checking admin: $e');
      setState(() {
        isAdmin = false;
        isLoading = false;
      });
    }
  }

  Future<void> _loadArticles() async {
  try {
    // Use a simpler query that works with our manually inserted articles
    final response = await supabase
        .from('articles')
        .select('''
          id,
          slug,
          category,
          published,
          reading_time_minutes,
          created_at,
          article_translations!inner(title, lang)
        ''')
        .eq('article_translations.lang', 'en')
        .eq('published', true)
        .order('created_at', ascending: false);
    
    setState(() {
      articles = (response as List).map((json) {
        // Transform the data to match Article model
        final transformedJson = {
          'article_id': json['id'],
          'id': json['id'],
          'slug': json['slug'],
          'category': json['category'],
          'title': json['article_translations'][0]['title'],
          'body': '', // We don't need full body for the list
          'reading_time_minutes': json['reading_time_minutes'],
          'created_at': json['created_at'],
          'comment_count': 0,
        };
        return Article.fromJson(transformedJson);
      }).toList();
      isLoading = false;
    });
  } catch (e) {
    print('Error loading articles: $e');
    setState(() => isLoading = false);
  }
}
  Future<void> _showImageUploadDialog(Article article) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Cover Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Upload a cover image for:\n"${article.title}"'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(article, ImageSource.camera);
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(article, ImageSource.gallery);
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(Article article, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        await _uploadImageToSupabase(article, File(pickedFile.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _uploadImageToSupabase(Article article, File imageFile) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading image...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Generate unique filename
      final fileExtension = imageFile.path.split('.').last;
      final fileName = '${article.slug}-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // Upload to Supabase Storage
      await supabase.storage
          .from('article-images')
          .upload(fileName, imageFile);

      // Get public URL
      final imageUrl = supabase.storage
          .from('article-images')
          .getPublicUrl(fileName);

      // Update article in database
      await supabase
          .from('articles')
          .update({'cover_image': imageUrl})
          .eq('id', article.id);

      if (!mounted) return;

      // Hide loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh articles list
      _loadArticles();

    } catch (e) {
      print('Error uploading image: $e');
      
      if (!mounted) return;
      
      // Hide loading dialog
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteArticle(String articleId) async {
    try {
      await supabase.from('articles').delete().eq('id', articleId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article deleted')),
      );
      
      _loadArticles();
    } catch (e) {
      print('Error deleting article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF00A896),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : !isAdmin
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin Access Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You need admin privileges to access this page',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Articles',
                              articles.length.toString(),
                              Icons.article,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Published',
                              articles.length.toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Articles List
                    Expanded(
                      child: articles.isEmpty
                          ? const Center(
                              child: Text('No articles yet'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: articles.length,
                              itemBuilder: (context, index) {
                                final article = articles[index];
                                return _buildArticleCard(article);
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateArticleScreen(),
                  ),
                ).then((_) => _loadArticles());
              },
              icon: const Icon(Icons.add),
              label: const Text('New Article'),
              backgroundColor: const Color(0xFF00A896),
            )
          : null,
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          article.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${article.category} • ${article.readingTimeMinutes} min',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'upload_image',
              child: Row(
                children: [
                  Icon(Icons.add_photo_alternate, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Upload Image'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditArticleScreen(article: article),
                ),
              ).then((_) => _loadArticles());
            } else if (value == 'upload_image') {
              _showImageUploadDialog(article);
            } else if (value == 'delete') {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Article?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteArticle(article.id);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}