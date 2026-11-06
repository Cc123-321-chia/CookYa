// screens/profile/level_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';

class LevelDetailPage extends StatelessWidget {
  final UserModel currentUser;
  final List<LevelInfo> levelInfo;
  final List<PointRule> pointRules;

  const LevelDetailPage({
    super.key,
    required this.currentUser,
    required this.levelInfo,
    required this.pointRules,
  });

  /// Users become mentors automatically once they reach this level.
  static const int mentorMinLevel = 3;

  @override
  Widget build(BuildContext context) {
    final currentLevelInfo = levelInfo.firstWhere(
      (level) => level.level == currentUser.level,
      orElse: () => levelInfo.last,
    );

    // Safe: if the user is at the max level, fall back to the current one.
    final nextLevelInfo = levelInfo.firstWhere(
      (level) => level.level == currentUser.level + 1,
      orElse: () => currentLevelInfo,
    );

    final progress = currentUser.nextLevelPoints > 0
        ? (currentUser.currentPoints / currentUser.nextLevelPoints)
            .clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Level ${currentUser.level} - ${currentLevelInfo.title}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF6B4C2A),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLevelCard(currentLevelInfo, nextLevelInfo, progress),
            const SizedBox(height: 20),
            _buildPointsCard(),
            const SizedBox(height: 20),
            _buildAllLevelsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    LevelInfo currentLevelInfo,
    LevelInfo nextLevelInfo,
    double progress,
  ) {
    final isMaxLevel = currentUser.level >= levelInfo.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  currentLevelInfo.icon,
                  size: 28,
                  color: const Color(0xFFFFB347),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLevelInfo.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    Text(
                      'Level ${currentUser.level}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFFC9A96E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Current Points',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      '${currentUser.currentPoints}',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB347),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      isMaxLevel ? 'Max Level' : 'To Next Level',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      isMaxLevel
                          ? '—'
                          : '${(currentUser.nextLevelPoints - currentUser.currentPoints).clamp(0, 999999)}',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB347),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB347),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFFB347)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                nextLevelInfo.icon,
                size: 14,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                isMaxLevel
                    ? 'You are at the highest level'
                    : 'Next: ${nextLevelInfo.title}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.stars,
                  size: 22,
                  color: Color(0xFFFFB347),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'How to Earn Points',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPointRuleItem('Upload a dish', '+1', Icons.upload_file),
          _buildPointRuleItem('Post a recipe', '+10', Icons.post_add),
          _buildPointRuleItem(
              'Post ingredients guidance', '+5', Icons.edit_note),
          _buildPointRuleItem(
              'Receive a like on your post', '+1', Icons.favorite),
          _buildPointRuleItem(
              'Receive an Expert/Official like', '+10',
              Icons.workspace_premium),
          _buildPointRuleItem(
              'Chef likes your dish', '+10', Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _buildPointRuleItem(String activity, String points, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFFFB347)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              activity,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ),
          Text(
            points,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFB347),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllLevelsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 22,
                  color: Color(0xFFFFB347),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'All Levels',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...levelInfo.map((level) {
            final isCurrentLevel = level.level == currentUser.level;
            final isMentorLevel = level.level >= mentorMinLevel;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentLevel
                    ? const Color(0xFFFFF3E0)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: isCurrentLevel
                    ? Border.all(
                        color: const Color(0xFFFFB347), width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentLevel
                          ? const Color(0xFFFFB347).withValues(alpha: 0.15)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      level.icon,
                      size: 22,
                      color: isCurrentLevel
                          ? const Color(0xFFFFB347)
                          : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Level ${level.level}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                            if (isMentorLevel)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Mentor',
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (isCurrentLevel)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB347),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Current',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          level.title,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFFFB347),
                          ),
                        ),
                        Text(
                          '${level.minPoints} - ${level.maxPoints == 999999 ? '∞' : level.maxPoints} points',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}