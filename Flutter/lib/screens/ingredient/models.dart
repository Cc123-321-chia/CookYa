// screens/ingredient/models.dart
import 'dart:io';
import '../../services/api_service.dart';

class IngredientPost {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final List<String> photoUrls;
  final String? videoUrl;
  final String? videoCoverUrl;
  final String authorId;
  final String authorUserId;
  final String authorName;
  final String authorAvatar;
  final int likes;
  final int comments;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isLiked;

  /// 'official' | 'expert' | null — used by RecommendationBadge on cards.
  final String? recommendation;

  // Local files for upload
  final List<File>? localPhotos;
  final File? localVideo;
  final File? localVideoCover;

  IngredientPost({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.photoUrls = const [],
    this.videoUrl,
    this.videoCoverUrl,
    required this.authorId,
    this.authorUserId = '',
    required this.authorName,
    required this.authorAvatar,
    required this.likes,
    required this.comments,
    this.tags = const [],
    required this.createdAt,
    this.editedAt,
    this.isLiked = false,
    this.recommendation,
    this.localPhotos,
    this.localVideo,
    this.localVideoCover,
  });

  // ==================== Date helpers ====================

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

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays > 7) {
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  String get coverPhotoUrl {
    final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      if (imageUrl!.startsWith('/')) return '$baseUrl$imageUrl';
      return imageUrl!;
    }
    if (photoUrls.isNotEmpty) {
      final firstPhoto = photoUrls[0];
      if (firstPhoto.startsWith('/')) return '$baseUrl$firstPhoto';
      return firstPhoto;
    }
    return '';
  }

  // ==================== JSON ====================

  factory IngredientPost.fromJson(Map<String, dynamic> json) {
    List<String> tagsList = [];
    if (json['tags'] != null && json['tags'] is List) {
      for (var tag in json['tags']) {
        if (tag is String) {
          tagsList.add(tag);
        } else if (tag is List) {
          for (var innerTag in tag) {
            tagsList.add(innerTag.toString());
          }
        } else {
          tagsList.add(tag.toString());
        }
      }
    }

    List<String> photoUrlsList = [];
    if (json['photo_urls'] != null && json['photo_urls'] is List) {
      photoUrlsList =
          (json['photo_urls'] as List).map((p) => p.toString()).toList();
    }

    String authorIdStr = '';
    if (json['author_id'] != null) {
      authorIdStr = json['author_id'].toString();
    } else if (json['author'] != null) {
      if (json['author'] is int) {
        authorIdStr = json['author'].toString();
      } else if (json['author'] is Map) {
        authorIdStr = json['author']['id']?.toString() ?? '';
      } else {
        authorIdStr = json['author'].toString();
      }
    }

    String authorUserIdStr = '';
    if (json['author_user_id'] != null) {
      authorUserIdStr = json['author_user_id'].toString();
    }

    return IngredientPost(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      photoUrls: photoUrlsList,
      videoUrl: json['video_url']?.toString(),
      videoCoverUrl: json['video_cover_url']?.toString(),
      authorId: authorIdStr,
      authorUserId: authorUserIdStr,
      authorName: json['author_name']?.toString() ?? 'Unknown',
      authorAvatar: json['author_avatar']?.toString() ?? '',
      likes: json['likes_count'] is int
          ? json['likes_count']
          : (json['likes_count'] ?? 0),
      comments: json['comments_count'] is int
          ? json['comments_count']
          : (json['comments_count'] ?? 0),
      tags: tagsList,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'].toString())
          : null,
      isLiked: json['is_liked'] == true,
      recommendation: json['recommendation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'tags': tags,
      };
}


// ==================== Comment model ====================

class IngredientComment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String text;
  final DateTime createdAt;

  IngredientComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.text,
    required this.createdAt,
  });

  factory IngredientComment.fromJson(Map<String, dynamic> json) {
    return IngredientComment(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown',
      userAvatar: json['user_avatar']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}