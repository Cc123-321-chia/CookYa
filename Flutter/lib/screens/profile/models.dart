// screens/profile/models.dart
import 'package:flutter/material.dart';
import '../../utils/url_helper.dart';

enum ContentType { recipe, ingredientsGuidance }

class UserModel {
  final String id;
  final String userId;
  final String name;
  final String avatarUrl;
  final String bio;
  final int level;
  final int currentPoints;
  final int nextLevelPoints;
  final int followers;
  final int following;
  final int totalLikes;

  // Role flags (read from backend UserSerializer)
  final bool isMentor;
  final bool isExpert;
  final bool isVerifiedExpert;
  final bool isOfficial;
  final bool isCulinaryInstructor;
  final String role;
  final Map<String, dynamic> roleInfo;

  // Activity counters
  final int recipeCount;
  final int ingredientCount;
  final int dishCount;
  final int totalPosts;
  final int recipeLikesReceived;
  final int ingredientLikesReceived;
  final int dishLikesReceived;
  final int totalLikesReceived;
  final int recipeLikesGiven;
  final int ingredientLikesGiven;
  final int dishLikesGiven;
  final int totalLikesGiven;
  final int recipeComments;
  final int ingredientComments;
  final int dishComments;
  final int totalComments;

  const UserModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.level,
    required this.currentPoints,
    required this.nextLevelPoints,
    required this.followers,
    required this.following,
    required this.totalLikes,
    this.isMentor = false,
    this.isExpert = false,
    this.isVerifiedExpert = false,
    this.isOfficial = false,
    this.isCulinaryInstructor = false,
    this.role = 'user',
    this.roleInfo = const {},
    this.recipeCount = 0,
    this.ingredientCount = 0,
    this.dishCount = 0,
    this.totalPosts = 0,
    this.recipeLikesReceived = 0,
    this.ingredientLikesReceived = 0,
    this.dishLikesReceived = 0,
    this.totalLikesReceived = 0,
    this.recipeLikesGiven = 0,
    this.ingredientLikesGiven = 0,
    this.dishLikesGiven = 0,
    this.totalLikesGiven = 0,
    this.recipeComments = 0,
    this.ingredientComments = 0,
    this.dishComments = 0,
    this.totalComments = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final level = json['level'] ?? 1;
    final points = json['points'] ?? 0;

    final avatar = json['avatar'] ?? '';
    final avatarUrl = avatar.isNotEmpty ? avatar : '';

    return UserModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id'] ?? 'unknown',
      name: json['username'] ?? 'User',
      avatarUrl: avatarUrl,
      bio: json['bio']?.isNotEmpty == true
          ? json['bio']
          : 'Food lover sharing recipes!',
      level: level,
      currentPoints: points,
      nextLevelPoints: UserModel._getNextLevelPoints(level),
      followers: json['followers_count'] ?? 0,
      following: json['following_count'] ?? 0,
      totalLikes: json['total_likes_received'] ?? 0,
      isMentor: json['is_mentor'] == true,
      isExpert: json['is_expert'] == true,
      isVerifiedExpert: json['is_verified_expert'] == true,
      isOfficial: json['is_official'] == true,
      isCulinaryInstructor: json['is_culinary_instructor'] == true,
      role: json['role'] ?? 'user',
      roleInfo: (json['role_info'] is Map)
          ? Map<String, dynamic>.from(json['role_info'])
          : const {},
      recipeCount: json['recipe_count'] ?? 0,
      ingredientCount: json['ingredient_count'] ?? 0,
      dishCount: json['dish_count'] ?? 0,
      totalPosts: json['total_posts'] ?? 0,
      recipeLikesReceived: json['recipe_likes_received'] ?? 0,
      ingredientLikesReceived: json['ingredient_likes_received'] ?? 0,
      dishLikesReceived: json['dish_likes_received'] ?? 0,
      totalLikesReceived: json['total_likes_received'] ?? 0,
      recipeLikesGiven: json['recipe_likes_given'] ?? 0,
      ingredientLikesGiven: json['ingredient_likes_given'] ?? 0,
      dishLikesGiven: json['dish_likes_given'] ?? 0,
      totalLikesGiven: json['total_likes_given'] ?? 0,
      recipeComments: json['recipe_comments'] ?? 0,
      ingredientComments: json['ingredient_comments'] ?? 0,
      dishComments: json['dish_comments'] ?? 0,
      totalComments: json['total_comments'] ?? 0,
    );
  }

  /// Points required to reach the next level (assuming current level).
  static int _getNextLevelPoints(int currentLevel) {
    const levels = [
      0,
      100,
      250,
      450,
      700,
      1000,
      1350,
      1750,
      2500,
      3500,
      5000,
    ];
    if (currentLevel >= levels.length) return 999999;
    return levels[currentLevel];
  }

  Map<String, dynamic> getRoleInfo() => roleInfo;

  bool get isMentorRole => isMentor || level >= 3;

  bool get isExpertRole => isExpert;

  /// Official overrides all other roles in the UI.
  bool get isOfficialRole => isOfficial;
}

class LevelInfo {
  final int level;
  final int minPoints;
  final int maxPoints;
  final String title;
  final IconData icon;

  const LevelInfo({
    required this.level,
    required this.minPoints,
    required this.maxPoints,
    required this.title,
    required this.icon,
  });
}

class PointRule {
  final String activity;
  final int points;
  final IconData icon;

  const PointRule({
    required this.activity,
    required this.points,
    required this.icon,
  });
}

class ContentCard {
  final String id;
  final String title;
  final String imageUrl;
  final String author;
  final int likes;
  final ContentType type;

  const ContentCard({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.author,
    required this.likes,
    required this.type,
  });

  factory ContentCard.fromRecipeJson(Map<String, dynamic> json) {
    final photoUrls = json['photo_urls'] as List? ?? [];
    String imageUrl = photoUrls.isNotEmpty
        ? photoUrls[0].toString()
        : (json['image_url']?.toString() ?? '');

    if (imageUrl.isNotEmpty && imageUrl.startsWith('/')) {
      imageUrl = '${UrlHelper.baseUrl}$imageUrl';
    }

    if (imageUrl.isEmpty) {
      imageUrl = 'https://images.unsplash.com/photo-1584661590039-d8e9b8d6c9e9';
    }

    return ContentCard(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      imageUrl: imageUrl,
      author: json['author_name'] ?? 'Unknown',
      likes: json['likes_count'] ?? 0,
      type: ContentType.recipe,
    );
  }

  factory ContentCard.fromIngredientJson(Map<String, dynamic> json) {
    final photoUrls = json['photo_urls'] as List? ?? [];
    String imageUrl = photoUrls.isNotEmpty
        ? photoUrls[0].toString()
        : (json['image_url']?.toString() ?? '');

    if (imageUrl.isNotEmpty && imageUrl.startsWith('/')) {
      imageUrl = '${UrlHelper.baseUrl}$imageUrl';
    }

    if (imageUrl.isEmpty) {
      imageUrl = 'https://images.unsplash.com/photo-1584661590039-d8e9b8d6c9e9';
    }

    return ContentCard(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Untitled',
      imageUrl: imageUrl,
      author: json['author_name'] ?? 'Unknown',
      likes: json['likes_count'] ?? 0,
      type: ContentType.ingredientsGuidance,
    );
  }
}

class CommentCard {
  final String id;
  final String postId;
  final String contentTitle;
  final String commentText;
  final String imageUrl;
  final String author;
  final String date;
  final int likes;
  final ContentType type;

  const CommentCard({
    required this.id,
    required this.postId,
    required this.contentTitle,
    required this.commentText,
    required this.imageUrl,
    required this.author,
    required this.date,
    required this.likes,
    required this.type,
  });

  factory CommentCard.fromRecipeCommentJson(Map<String, dynamic> json) {
    String imageUrl = json['recipe_image'] ??
        'https://images.unsplash.com/photo-1584661590039-d8e9b8d6c9e9';
    if (imageUrl.startsWith('/')) {
      imageUrl = '${UrlHelper.baseUrl}$imageUrl';
    }

    return CommentCard(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      contentTitle: json['recipe_title'] ?? 'Untitled',
      commentText: json['text'] ?? '',
      imageUrl: imageUrl,
      author: json['user_name'] ?? 'Unknown',
      date: _formatDate(json['created_at']),
      likes: json['likes'] ?? 0,
      type: ContentType.recipe,
    );
  }

  factory CommentCard.fromIngredientCommentJson(Map<String, dynamic> json) {
    String imageUrl = json['post_image'] ??
        'https://images.unsplash.com/photo-1584661590039-d8e9b8d6c9e9';
    if (imageUrl.startsWith('/')) {
      imageUrl = '${UrlHelper.baseUrl}$imageUrl';
    }

    return CommentCard(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      contentTitle: json['post_title'] ?? 'Untitled',
      commentText: json['text'] ?? '',
      imageUrl: imageUrl,
      author: json['user_name'] ?? 'Unknown',
      date: _formatDate(json['created_at']),
      likes: json['likes'] ?? 0,
      type: ContentType.ingredientsGuidance,
    );
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Just now';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 7) {
        return '${date.month}/${date.day}/${date.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} days ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hours ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} minutes ago';
      }
      return 'Just now';
    } catch (e) {
      return 'Just now';
    }
  }
}