// models/recipe.dart
import 'dart:io';
import 'comment.dart';
import 'homework.dart';

class StepItem {
  final String instruction;
  final String? note;

  StepItem({
    required this.instruction,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'instruction': instruction,
        'note': note,
      };

  factory StepItem.fromJson(Map<String, dynamic> json) {
    return StepItem(
      instruction: json['instruction']?.toString() ?? '',
      note: json['note']?.toString(),
    );
  }
}

class IngredientItem {
  final String name;
  final String amount;

  IngredientItem({
    required this.name,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
      };

  factory IngredientItem.fromJson(Map<String, dynamic> json) {
    return IngredientItem(
      name: json['name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
    );
  }
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String authorId;
  final String authorUserId;
  final String authorName;
  final String authorAvatar;
  final int likes;
  final bool isLiked;
  final int comments;
  final int dishes;

  final List<IngredientItem> ingredients;
  final List<StepItem> steps;
  final String cuisineType;
  final int durationMinutes;
  final int difficultyLevel;
  final List<String> cookingTools;
  final List<String> tags;

  final List<String> photoUrls;
  final String? videoUrl;
  final String? videoCoverUrl;
  final DateTime createdAt;
  final DateTime? editedAt;

  final double? rating;
  final int? reviewCount;

  final List<File>? localPhotos;
  final File? localVideo;
  final File? localVideoCover;

  final List<Comment>? commentList;
  final int totalComments;

  final List<Homework>? homeworks;
  final int totalHomeworks;

  /// 'official' | 'expert' | null — used by RecommendationBadge on cards.
  final String? recommendation;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.authorId,
    this.authorUserId = '',
    required this.authorName,
    required this.authorAvatar,
    required this.likes,
    this.isLiked = false,
    required this.comments,
    required this.dishes,
    required this.ingredients,
    required this.steps,
    required this.cuisineType,
    required this.durationMinutes,
    required this.difficultyLevel,
    required this.cookingTools,
    required this.tags,
    this.photoUrls = const [],
    this.videoUrl,
    this.videoCoverUrl,
    required this.createdAt,
    this.editedAt,
    this.rating,
    this.reviewCount,
    this.localPhotos,
    this.localVideo,
    this.localVideoCover,
    this.commentList,
    this.totalComments = 0,
    this.homeworks,
    this.totalHomeworks = 0,
    this.recommendation,
  });

  String get difficultyText {
    switch (difficultyLevel) {
      case 1:
        return 'Very Easy';
      case 2:
        return 'Easy';
      case 3:
        return 'Medium';
      case 4:
        return 'Hard';
      case 5:
        return 'Very Hard';
      default:
        return 'Medium';
    }
  }

  String get formattedDuration {
    if (durationMinutes >= 300) return '5+ hours';
    if (durationMinutes >= 60) {
      final hours = durationMinutes / 60.0;
      return '${hours.toStringAsFixed(1)} hours';
    }
    return '$durationMinutes min${durationMinutes == 1 ? '' : 's'}';
  }

  String get coverPhotoUrl =>
      imageUrl ?? (photoUrls.isNotEmpty ? photoUrls[0] : '');

  bool get isEdited => editedAt != null;

  String get postedDateText {
    final d = createdAt;
    return '${d.day}/${d.month}/${d.year}';
  }

  String get editedDateText {
    if (editedAt == null) return '';
    final d = editedAt!;
    return '${d.day}/${d.month}/${d.year}';
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<String> cookingToolsList = [];
    if (json['cooking_tools'] != null && json['cooking_tools'] is List) {
      for (var tool in json['cooking_tools']) {
        if (tool is String) {
          cookingToolsList.add(tool);
        } else if (tool is Map && tool.containsKey('name')) {
          cookingToolsList.add(tool['name'].toString());
        }
      }
    }

    List<String> tagsList = [];
    if (json['tags'] != null && json['tags'] is List) {
      for (var tag in json['tags']) {
        if (tag is String) {
          tagsList.add(tag);
        } else if (tag is Map && tag.containsKey('name')) {
          tagsList.add(tag['name'].toString());
        }
      }
    }

    List<IngredientItem> ingredientsList = [];
    if (json['ingredients'] != null && json['ingredients'] is List) {
      ingredientsList = (json['ingredients'] as List).map((item) {
        final Map<String, dynamic> ingredientMap =
            item is Map ? Map<String, dynamic>.from(item) : {};
        return IngredientItem.fromJson(ingredientMap);
      }).toList();
    }

    List<StepItem> stepsList = [];
    if (json['steps'] != null && json['steps'] is List) {
      stepsList = (json['steps'] as List).map((item) {
        final Map<String, dynamic> stepMap =
            item is Map ? Map<String, dynamic>.from(item) : {};
        return StepItem.fromJson(stepMap);
      }).toList();
    }

    List<String> photoUrlsList = [];
    if (json['photo_urls'] != null && json['photo_urls'] is List) {
      photoUrlsList =
          (json['photo_urls'] as List).map((p) => p.toString()).toList();
    }

    String authorIdValue = '';
    if (json['author_id'] != null) {
      authorIdValue = json['author_id'].toString();
    } else if (json['author'] != null) {
      authorIdValue = json['author'].toString();
    }

    List<Comment>? commentList;
    if (json['comments'] != null && json['comments'] is List) {
      commentList = (json['comments'] as List)
          .map((c) =>
              Comment.fromJson(c is Map ? Map<String, dynamic>.from(c) : {}))
          .toList();
    }

    List<Homework>? homeworksList;
    if (json['homeworks'] != null && json['homeworks'] is List) {
      homeworksList = (json['homeworks'] as List)
          .map((h) =>
              Homework.fromJson(h is Map ? Map<String, dynamic>.from(h) : {}))
          .toList();
    }

    return Recipe(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      authorId: authorIdValue,
      authorUserId: json['author_user_id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Unknown Chef',
      authorAvatar: json['author_avatar']?.toString() ?? '',
      likes: (json['likes_count'] ?? json['likes'] ?? 0) as int,
      isLiked: json['is_liked'] == true,
      comments: (json['comments_count'] ?? 0) as int,
      dishes: (json['dishes_count'] ?? 0) as int,
      ingredients: ingredientsList,
      steps: stepsList,
      cuisineType: json['cuisine_type']?.toString() ?? '',
      durationMinutes: (json['duration_minutes'] ?? 30) as int,
      difficultyLevel: (json['difficulty_level'] ?? 2) as int,
      cookingTools: cookingToolsList,
      tags: tagsList,
      photoUrls: photoUrlsList,
      videoUrl: json['video_url']?.toString(),
      videoCoverUrl: json['video_cover_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'].toString())
          : null,
      rating: json['rating'] != null
          ? (json['rating'] is int
              ? (json['rating'] as int).toDouble()
              : json['rating'] as double)
          : null,
      reviewCount: json['review_count'] as int?,
      commentList: commentList,
      totalComments: (json['total_comments'] ?? 0) as int,
      homeworks: homeworksList,
      totalHomeworks: (json['total_homeworks'] ?? 0) as int,
      recommendation: json['recommendation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'cuisine_type': cuisineType,
        'duration_minutes': durationMinutes,
        'difficulty_level': difficultyLevel,
        'cooking_tools': cookingTools,
        'tags': tags,
        'ingredients':
            ingredients.map((i) => {'name': i.name, 'amount': i.amount}).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}