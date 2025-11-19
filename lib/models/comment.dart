class Comment {
  final String id;
  final String articleId;
  final String userId;
  final String? parentCommentId;
  final String content;
  final DateTime createdAt;
  final String? userName;
  final List<Comment> replies;
  
  Comment({
    required this.id,
    required this.articleId,
    required this.userId,
    this.parentCommentId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.replies = const [],
  });
  
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? '',
      articleId: json['article_id'] ?? '',
      userId: json['user_id'] ?? '',
      parentCommentId: json['parent_comment_id'],
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),

      // FIX: Use `user_name` FIRST, fallback to `users.full_name`
      userName: json['user_name'] ??
                json['users']?['full_name'] ??
                'Anonymous',
    );
  }
}
