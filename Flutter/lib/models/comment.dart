// models/comment.dart
import 'dart:io';

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final List<String> photoUrls;
  final List<File>? localPhotos;
  final int rating; // 1-5
  final DateTime createdAt;
  final int likes;
  final bool isLiked;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.photoUrls = const [],
    this.localPhotos,
    required this.rating,
    required this.createdAt,
    this.likes = 0,
    this.isLiked = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown User',
      userAvatar: json['user_avatar']?.toString() ?? '',
      content: json['text']?.toString() ?? json['content']?.toString() ?? '',
      photoUrls: json['photo_urls'] != null
          ? List<String>.from(json['photo_urls'])
          : [],
      rating: (json['rating'] ?? 0) as int,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likes: (json['likes'] ?? 0) as int,
      isLiked: json['is_liked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'rating': rating,
        'photo_urls': photoUrls,
      };

  String get ratingDisplay {
    // 使用 Unicode 码点代替 emoji
    if (rating >= 5) return '\u{1F3E1}'; // 🏠 用房子代表 5 星
    if (rating >= 4) return '\u{2B50}';   // ⭐ 4 星
    if (rating >= 3) return '\u{1F31F}'; // 🌟 3 星
    if (rating >= 2) return '\u{2728}';   // ✨ 2 星
    return '\u{1F4A1}';                   // 💡 1 星
  }

  String get ratingEmoji {
    // 使用 Unicode 码点
    switch (rating) {
      case 5:
        return '\u{1F525}'; // 🔥 完美
      case 4:
        return '\u{1F60A}'; // 😊 很好
      case 3:
        return '\u{1F610}'; // 😐 一般
      case 2:
        return '\u{1F641}'; // 🙁 较差
      default:
        return '\u{1F622}'; // 😢 很差
    }
  }
}