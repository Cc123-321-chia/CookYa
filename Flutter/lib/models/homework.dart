// models/homework.dart
import 'package:flutter/material.dart';

class Homework {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String imageUrl;
  final String recipeId;
  final String recipeTitle;
  final String review;
  final String rating; // 'good', 'ok', 'bad'
  final DateTime createdAt;

  // Likes / recommendation
  final int likes;
  final bool isLiked;
  final String? recommendation; // 'chef' | 'official' | null

  Homework({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.imageUrl,
    required this.recipeId,
    required this.recipeTitle,
    required this.review,
    required this.rating,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
    this.recommendation,
  });

  // ==================== Rating ====================

  IconData get ratingIcon {
    switch (rating) {
      case 'good':
        return Icons.sentiment_very_satisfied;
      case 'ok':
        return Icons.sentiment_neutral;
      case 'bad':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_very_satisfied;
    }
  }

  Color get ratingColor {
    switch (rating) {
      case 'good':
        return const Color(0xFF4CAF50);
      case 'ok':
        return const Color(0xFFFF9800);
      case 'bad':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String get ratingLabel {
    switch (rating) {
      case 'good':
        return 'Good';
      case 'ok':
        return 'OK';
      case 'bad':
        return 'Bad';
      default:
        return 'Good';
    }
  }

  // ==================== JSON ====================

  factory Homework.fromJson(Map<String, dynamic> json) {
    return Homework(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['user']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown',
      userAvatar: json['user_avatar']?.toString() ?? '',
      imageUrl: json['image_url']?.toString().isNotEmpty == true
          ? json['image_url'].toString()
          : (json['image']?.toString() ?? ''),
      recipeId: json['recipe_id']?.toString() ?? '',
      recipeTitle: json['recipe_title']?.toString() ?? '',
      review: json['review']?.toString() ?? '',
      rating: json['rating']?.toString() ?? 'good',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likes: (json['likes_count'] is int)
          ? json['likes_count']
          : int.tryParse(json['likes_count']?.toString() ?? '') ?? 0,
      isLiked: json['is_liked'] == true,
      recommendation: json['recommendation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'image_url': imageUrl,
        'recipe_id': recipeId,
        'recipe_title': recipeTitle,
        'review': review,
        'rating': rating,
        'created_at': createdAt.toIso8601String(),
        'likes_count': likes,
        'is_liked': isLiked,
        'recommendation': recommendation,
      };

  Homework copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? imageUrl,
    String? recipeId,
    String? recipeTitle,
    String? review,
    String? rating,
    DateTime? createdAt,
    int? likes,
    bool? isLiked,
    String? recommendation,
  }) {
    return Homework(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      imageUrl: imageUrl ?? this.imageUrl,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      review: review ?? this.review,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      recommendation: recommendation ?? this.recommendation,
    );
  }
}