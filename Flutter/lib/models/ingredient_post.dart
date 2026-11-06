// models/ingredient_post.dart

// 食材帖子数据模型
class IngredientPost {
  final String id;
  final String title;
  final String imagePath;
  int likes;
  int comments;
  final String description;
  final String authorName;
  final String authorAvatar;
  final String timePosted;
  final String fullContent;
  List<Map<String, String>> commentsList;

  IngredientPost({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.likes,
    required this.comments,
    required this.description,
    required this.authorName,
    required this.authorAvatar,
    required this.timePosted,
    required this.fullContent,
    this.commentsList = const [],
  });

  IngredientPost copyWith({
    String? id,
    String? title,
    String? imagePath,
    int? likes,
    int? comments,
    String? description,
    String? authorName,
    String? authorAvatar,
    String? timePosted,
    String? fullContent,
    List<Map<String, String>>? commentsList,
  }) {
    return IngredientPost(
      id: id ?? this.id,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      description: description ?? this.description,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      timePosted: timePosted ?? this.timePosted,
      fullContent: fullContent ?? this.fullContent,
      commentsList: commentsList ?? this.commentsList,
    );
  }
}

// 评论数据模型
class CommentData {
  final String id;
  final String userName;
  final String userAvatar;
  final String text;
  final DateTime timestamp;
  final String? imageUrl;
  final int likes;
  final List<ReplyData> replies;

  CommentData({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.timestamp,
    this.imageUrl,
    this.likes = 0,
    this.replies = const [],
  });

  CommentData copyWith({
    String? id,
    String? userName,
    String? userAvatar,
    String? text,
    DateTime? timestamp,
    String? imageUrl,
    int? likes,
    List<ReplyData>? replies,
  }) {
    return CommentData(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      likes: likes ?? this.likes,
      replies: replies ?? this.replies,
    );
  }
}

// 回复数据模型
class ReplyData {
  final String id;
  final String userName;
  final String userAvatar;
  final String text;
  final DateTime timestamp;
  final int likes;

  ReplyData({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.timestamp,
    this.likes = 0,
  });

  ReplyData copyWith({
    String? id,
    String? userName,
    String? userAvatar,
    String? text,
    DateTime? timestamp,
    int? likes,
  }) {
    return ReplyData(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      likes: likes ?? this.likes,
    );
  }
}