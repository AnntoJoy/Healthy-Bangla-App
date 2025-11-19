class Article {
  final String id;
  final String slug;
  final String? coverImage;
  final String category;
  final String title;
  final String body;
  final int readingTimeMinutes;
  final DateTime createdAt;
  final int commentCount;
  final bool? isBookmarked;
  final bool? isLiked;
  final int? likeCount;
  final String? disclaimer;
  final String? authorName;
  
  Article({
    required this.id,
    required this.slug,
    this.coverImage,
    required this.category,
    required this.title,
    required this.body,
    required this.readingTimeMinutes,
    required this.createdAt,
    this.commentCount = 0,
    this.isBookmarked,
    this.isLiked,
    this.likeCount,
    this.disclaimer,
    this.authorName,
  });
  
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['article_id'] ?? json['id'] ?? '',
      slug: json['slug'] ?? '',
      coverImage: json['cover_image'],
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      readingTimeMinutes: json['reading_time_minutes'] ?? 5,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      commentCount: json['comment_count'] ?? 0,
      isBookmarked: json['is_bookmarked'],
      isLiked: json['is_liked'],
      likeCount: json['like_count'],
      disclaimer: json['disclaimer'],
      authorName: json['author_name'],
    );
  }
}