// screens/profile/follow_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/follow_models.dart';
import '../../services/api_service.dart';

class FollowListScreen extends StatefulWidget {
  /// 'followers' 或 'following'
  final String type;
  final String userId;
  final String title;

  const FollowListScreen({
    super.key,
    required this.type,
    required this.userId,
    required this.title,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<FollowUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = widget.type == 'followers'
          ? await ApiService.getFollowers(widget.userId)
          : await ApiService.getFollowing(widget.userId);

      if (result['success'] == true) {
        final List<dynamic> data = result['data'];

        final List<FollowUser> users = data.map((raw) {
          final Map<String, dynamic> json = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};

          // followers 列表：用 follower_xxx 字段
          // following 列表：用 user_xxx 字段
          if (widget.type == 'followers') {
            return FollowUser(
              id: json['follower']?.toString() ?? '',
              userId: json['follower_user_id']?.toString() ?? '',
              username: json['follower_username']?.toString() ?? 'User',
              avatarUrl: json['follower_avatar']?.toString() ?? '',
              bio: json['follower_bio']?.toString() ?? '',
              level: json['follower_level'] ?? 1,
              isMentor: json['follower_is_mentor'] == true,
            );
          } else {
            return FollowUser(
              id: json['user']?.toString() ?? '',
              userId: json['user_user_id']?.toString() ?? '',
              username: json['user_username']?.toString() ?? 'User',
              avatarUrl: json['user_avatar']?.toString() ?? '',
              bio: json['user_bio']?.toString() ?? '',
              level: json['user_level'] ?? 1,
              isMentor: json['user_is_mentor'] == true,
            );
          }
        }).toList();

        setState(() {
          _users = users;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF6B4C2A),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB347)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFFB347)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD966),
                foregroundColor: const Color(0xFF6B4C2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                widget.type == 'followers'
                    ? Icons.people_outline
                    : Icons.person_add_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                widget.type == 'followers'
                    ? 'No followers yet'
                    : 'Not following anyone yet',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(FollowUser user) {
    final avatarUrl = user.avatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFFFD966),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? const Icon(Icons.person, size: 26, color: Color(0xFF6B4C2A))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C2A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isMentor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Mentor',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${user.userId} · Level ${user.level}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
                if (user.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      user.bio.length > 40
                          ? '${user.bio.substring(0, 40)}...'
                          : user.bio,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}