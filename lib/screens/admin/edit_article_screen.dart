import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/article.dart';
import '../../utils/constants.dart';

class EditArticleScreen extends StatefulWidget {
  final Article article;
  
  const EditArticleScreen({Key? key, required this.article}) : super(key: key);

  @override
  State<EditArticleScreen> createState() => _EditArticleScreenState();
}

class _EditArticleScreenState extends State<EditArticleScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _slugController;
  late TextEditingController _titleEnController;
  late TextEditingController _titleBnController;
  late TextEditingController _bodyEnController;
  late TextEditingController _bodyBnController;
  late TextEditingController _readingTimeController;
  
  late String selectedCategory;
  late bool isPublished;
  late bool isFeatured;
  bool isLoading = false;
  String? currentImageUrl;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current article data
    _slugController = TextEditingController(text: widget.article.slug);
    _titleEnController = TextEditingController(text: widget.article.title);
    _titleBnController = TextEditingController();
    _bodyEnController = TextEditingController(text: widget.article.body);
    _bodyBnController = TextEditingController();
    _readingTimeController = TextEditingController(text: widget.article.readingTimeMinutes.toString());
    
    selectedCategory = widget.article.category;
    isPublished = true; // You might want to get this from article data
    isFeatured = false; // You might want to get this from article data
    currentImageUrl = widget.article.coverImage;
    
    _loadBengaliTranslation();
  }

  Future<void> _loadBengaliTranslation() async {
    try {
      final response = await supabase
          .from('article_translations')
          .select('title, body')
          .eq('article_id', widget.article.id)
          .eq('lang', 'bn')
          .maybeSingle();

      if (response != null) {
        setState(() {
          _titleBnController.text = response['title'] ?? '';
          _bodyBnController.text = response['body'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading Bengali translation: $e');
    }
  }

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

  Future<void> _updateArticle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // Update article
      await supabase
          .from('articles')
          .update({
            'slug': _slugController.text.trim(),
            'category': selectedCategory,
            'published': isPublished,
            'is_featured': isFeatured,
            'reading_time_minutes': int.parse(_readingTimeController.text),
          })
          .eq('id', widget.article.id);
      
      // Update English translation
      await supabase
          .from('article_translations')
          .update({
            'title': _titleEnController.text.trim(),
            'body': _bodyEnController.text.trim(),
          })
          .eq('article_id', widget.article.id)
          .eq('lang', 'en');
      
      // Update or insert Bengali translation
      if (_titleBnController.text.isNotEmpty) {
        await supabase
            .from('article_translations')
            .upsert({
              'article_id': widget.article.id,
              'lang': 'bn',
              'title': _titleBnController.text.trim(),
              'body': _bodyBnController.text.trim(),
              'disclaimer': 'এই তথ্য শুধুমাত্র শিক্ষাগত উদ্দেশ্যে প্রদান করা হয়েছে এবং এটি পেশাদার চিকিৎসা পরামর্শের বিকল্প নয়।',
            });
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article updated successfully!')),
      );
      
      Navigator.pop(context);
    } catch (e) {
      print('Error updating article: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() => isLoading = true);
        
        // Generate unique filename
        final fileExtension = pickedFile.path.split('.').last;
        final fileName = '${_slugController.text}-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

        // Upload to Supabase Storage
        await supabase.storage
            .from('article-images')
            .upload(fileName, File(pickedFile.path));

        // Get public URL
        final imageUrl = supabase.storage
            .from('article-images')
            .getPublicUrl(fileName);

        // Update article in database
        await supabase
            .from('articles')
            .update({'cover_image': imageUrl})
            .eq('id', widget.article.id);

        setState(() {
          currentImageUrl = imageUrl;
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Article'),
        backgroundColor: const Color(0xFF00A896),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Current Image Preview
            if (currentImageUrl != null) ...[
              Text(
                'Current Cover Image:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  currentImageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Upload Image Button
            ElevatedButton.icon(
              onPressed: _pickAndUploadImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(currentImageUrl != null ? 'Change Image' : 'Add Cover Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
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
              decoration: const InputDecoration(
                labelText: 'Slug (URL-friendly)',
                prefixIcon: Icon(Icons.link),
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
            
            // Update Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _updateArticle,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Update Article'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}