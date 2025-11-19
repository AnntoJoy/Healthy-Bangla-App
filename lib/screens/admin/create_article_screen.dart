import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';

class CreateArticleScreen extends StatefulWidget {
  const CreateArticleScreen({Key? key}) : super(key: key);

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  final _slugController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _titleBnController = TextEditingController();
  final _bodyEnController = TextEditingController();
  final _bodyBnController = TextEditingController();
  final _readingTimeController = TextEditingController(text: '5');
  
  String selectedCategory = 'heart_health';
  bool isPublished = true;
  bool isFeatured = false;
  bool isLoading = false;

  @override
  void dispose() {
    _slugController.dispose();
    _titleEnController.dispose();
    _titleBnController.dispose();
    _bodyEnController.dispose();
    _bodyBnController.dispose();
    _readingTimeController.dispose();
    super.dispose();
  }

  Future<void> _createArticle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      
      // 1. Insert article
      final articleResponse = await supabase
          .from('articles')
          .insert({
            'slug': _slugController.text.trim(),
            'category': selectedCategory,
            'published': isPublished,
            'is_featured': isFeatured,
            'reading_time_minutes': int.parse(_readingTimeController.text),
            'created_by': userId,
          })
          .select()
          .single();
      
      final articleId = articleResponse['id'];
      
      // 2. Insert English translation
      await supabase.from('article_translations').insert({
        'article_id': articleId,
        'lang': 'en',
        'title': _titleEnController.text.trim(),
        'body': _bodyEnController.text.trim(),
        'disclaimer': 'This information is provided for educational purposes only and is not a substitute for professional medical advice. Always consult a qualified healthcare provider before making any medical decisions.',
      });
      
      // 3. Insert Bengali translation
      if (_titleBnController.text.isNotEmpty) {
        await supabase.from('article_translations').insert({
          'article_id': articleId,
          'lang': 'bn',
          'title': _titleBnController.text.trim(),
          'body': _bodyBnController.text.trim(),
          'disclaimer': 'এই তথ্য শুধুমাত্র শিক্ষাগত উদ্দেশ্যে প্রদান করা হয়েছে এবং এটি পেশাদার চিকিৎসা পরামর্শের বিকল্প নয়।',
        });
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article created successfully!')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      print('Error creating article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _generateSlug() {
    final title = _titleEnController.text.trim().toLowerCase();
    final slug = title
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    _slugController.text = slug;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Article'),
        backgroundColor: const Color(0xFF00A896),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: AppConstants.categories.keys.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(AppConstants.getCategoryName(category, 'en')),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Slug
            TextFormField(
              controller: _slugController,
              decoration: InputDecoration(
                labelText: 'Slug (URL-friendly)',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: _generateSlug,
                  tooltip: 'Generate from title',
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a slug';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // English Title
            TextFormField(
              controller: _titleEnController,
              decoration: const InputDecoration(
                labelText: 'Title (English)',
                prefixIcon: Icon(Icons.title),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter English title';
                }
                return null;
              },
              onChanged: (_) => _generateSlug(),
            ),
            const SizedBox(height: 16),
            
            // Bengali Title
            TextFormField(
              controller: _titleBnController,
              decoration: const InputDecoration(
                labelText: 'Title (Bengali) - Optional',
                prefixIcon: Icon(Icons.title),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // English Body
            TextFormField(
              controller: _bodyEnController,
              decoration: const InputDecoration(
                labelText: 'Content (English)',
                prefixIcon: Icon(Icons.article),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter English content';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Bengali Body
            TextFormField(
              controller: _bodyBnController,
              decoration: const InputDecoration(
                labelText: 'Content (Bengali) - Optional',
                prefixIcon: Icon(Icons.article),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 16),
            
            // Reading Time
            TextFormField(
              controller: _readingTimeController,
              decoration: const InputDecoration(
                labelText: 'Reading Time (minutes)',
                prefixIcon: Icon(Icons.timer),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter reading time';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Switches
            SwitchListTile(
              title: const Text('Published'),
              subtitle: const Text('Make article visible to users'),
              value: isPublished,
              onChanged: (value) => setState(() => isPublished = value),
              activeColor: const Color(0xFF00A896),
            ),
            
            SwitchListTile(
              title: const Text('Featured'),
              subtitle: const Text('Show on home screen'),
              value: isFeatured,
              onChanged: (value) => setState(() => isFeatured = value),
              activeColor: const Color(0xFF00A896),
            ),
            
            const SizedBox(height: 24),
            
            // Create Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createArticle,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Create Article'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}