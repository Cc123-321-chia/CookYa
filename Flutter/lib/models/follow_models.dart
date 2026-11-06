// lib/models/follow_models.dart

// ==================== FollowUser ====================
class FollowUser {
  final String id;
  final String userId;
  final String username;
  final String avatarUrl;
  final String bio;
  final int level;
  final bool isMentor;

  FollowUser({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    required this.level,
    required this.isMentor,
  });

  factory FollowUser.fromJson(Map<String, dynamic> json) {
    return FollowUser(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'User',
      avatarUrl: json['avatar']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      level: json['level'] ?? 1,
      isMentor: json['is_mentor'] == true,
    );
  }
}

// ==================== UserProfileModel ====================
class UserProfileModel {
  final String id;           // Django integer id ("11")
  final String userId;       // 8位 ("83980268")
  final String username;
  final String avatarUrl;    // 完整 URL 或空
  final String bio;
  final int level;
  final int points;
  final int nextLevelPoints;
  final int followersCount;
  final int followingCount;
  final int totalLikes;
  final bool isMentor;
  final bool isOfficial;
  final bool isExpert;
  final bool isCulinaryInstructor;

  UserProfileModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    required this.level,
    required this.points,
    required this.nextLevelPoints,
    required this.followersCount,
    required this.followingCount,
    required this.totalLikes,
    required this.isMentor,
    required this.isOfficial,
    required this.isExpert,
    required this.isCulinaryInstructor,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final level = json['level'] ?? 1;
    final avatar = json['avatar']?.toString() ?? '';

    return UserProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'User',
      avatarUrl: avatar,
      bio: json['bio']?.toString() ?? '',
      level: level,
      points: json['points'] ?? 0,
      nextLevelPoints: _getNextLevelPoints(level),
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      totalLikes: json['total_likes_received'] ?? 0,
      isMentor: json['is_mentor'] == true,
      isOfficial: json['is_official'] == true,
      isExpert: json['is_expert'] == true,
      isCulinaryInstructor: json['is_culinary_instructor'] == true,
    );
  }

  static int _getNextLevelPoints(int currentLevel) {
    const levels = [
      0, 100, 250, 450, 700, 1000, 1350, 1750,
      2500, 3500, 5000,
    ];
    if (currentLevel >= levels.length) return 999999;
    return levels[currentLevel];
  }
}