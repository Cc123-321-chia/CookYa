// screens/profile/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/recipe.dart';
import '../../models/follow_models.dart';
import 'follow_list_screen.dart';
import '../ingredient/models.dart';
import '../ingredient/ingredients_detail_screen.dart';
import '../recipes/post_detail_screen.dart';
import '../ingredient/widgets.dart' as ingredient_widgets;
import '../../widgets/recipe_card.dart';
import '../../widgets/user_badge.dart';
import '../mentor-mentee/chat_detail_screen.dart';
import 'models.dart';

class UserProfileScreen extends StatefulWidget {
  /// Target user's 8-char user_id (e.g. "83980268").
  final String userId;

  /// If true, bottom buttons show "Request Mentorship" instead of Message/Follow.
  final bool fromMentorTab;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.fromMentorTab = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedSection = 0;

  int _postsSubCategory = 0;
  int _likedSubCategory = 0;
  int _commentsSubCategory = 0;

  UserProfileModel? _user;
  bool _isLoading = true;
  String? _errorMessage;

  List<Recipe> _myRecipes = [];
  List<IngredientPost> _myIngredients = [];
  List<Recipe> _likedRecipes = [];
  List<IngredientPost> _likedIngredients = [];
  List<CommentCard> _commentsOnRecipes = [];
  List<CommentCard> _commentsOnGuidance = [];
  bool _isLoadingContent = false;

  // Follow
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  // Mentorship
  bool _isMyMentor = false;
  bool _hasPendingRequest = false;
  bool _isRequestingMentorship = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedSection = _tabController.index);
      _loadContentForSection(_selectedSection);
    });
    _loadUser();
    _checkFollowStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== Load ====================

  Future<void> _loadUser() async {

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getUserProfileByUserId(widget.userId);

      if (result['success'] == true) {
        final user = UserProfileModel.fromJson(result['data']);
        final raw = result['data'] as Map<String, dynamic>;
        debugPrint('🔵 RAW is_official=${raw['is_official']}, is_mentor=${raw['is_mentor']}, is_culinary_instructor=${raw['is_culinary_instructor']}');
        debugPrint('🔵 PARSED isOfficial=${user.isOfficial}, isMentor=${user.isMentor}, isCulinaryInstructor=${user.isCulinaryInstructor}');
        setState(() {
          _user = user;
          _isMyMentor = raw['is_mentor_of_current'] == true;
          _hasPendingRequest = raw['has_pending_request'] == true;
          _isLoading = false;
        });
        _loadContentForSection(_selectedSection);
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load user';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFollowStatus() async {
    final result = await ApiService.checkFollow(widget.userId);
    if (result['success'] == true && mounted) {
      setState(() {
        _isFollowing = result['is_following'] == true;
      });
    }
  }

  Future<void> _loadContentForSection(int section) async {
    if (_user == null) return;
    setState(() => _isLoadingContent = true);

    try {
      final token = ApiService.authToken;
      if (token == null) return;

      final baseUrl = ApiService.baseUrl;
      final uid = _user!.userId;

      switch (section) {
        case 0:
          if (_postsSubCategory == 0) {
            final response = await http.get(
              Uri.parse('$baseUrl/recipes/?author=${_user!.id}'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              if (!mounted) return;
              setState(() {
                _myRecipes =
                    data.map((json) => Recipe.fromJson(json)).toList();
              });
            }
          } else {
            final response = await http.get(
              Uri.parse('$baseUrl/ingredients/?author=${_user!.id}'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              if (!mounted) return;
              setState(() {
                _myIngredients = data
                    .map((json) => IngredientPost.fromJson(json))
                    .toList();
              });
            }
          }
          break;

        case 1:
          if (_likedSubCategory == 0) {
            final response = await http.get(
              Uri.parse('$baseUrl/users/$uid/liked/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              if (!mounted) return;
              setState(() {
                _likedRecipes =
                    data.map((json) => Recipe.fromJson(json)).toList();
              });
            }
          } else {
            final response = await http.get(
              Uri.parse('$baseUrl/ingredients/users/$uid/liked/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              if (!mounted) return;
              setState(() {
                _likedIngredients = data
                    .map((json) => IngredientPost.fromJson(json))
                    .toList();
              });
            }
          }
          break;

        case 2:
          if (_commentsSubCategory == 0) {
            final response = await http.get(
              Uri.parse('$baseUrl/users/$uid/comments/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              if (!mounted) return;
              setState(() {
                _commentsOnRecipes = data
                    .map((json) => CommentCard.fromRecipeCommentJson(json))
                    .toList();
              });
            }
          } else {
            final response = await http.get(
              Uri.parse('$baseUrl/ingredients/users/$uid/comments/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              if (!mounted) return;
              setState(() {
                _commentsOnGuidance = data
                    .map((json) =>
                        CommentCard.fromIngredientCommentJson(json))
                    .toList();
              });
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('Error loading content: $e');
    }

    if (mounted) setState(() => _isLoadingContent = false);
  }

  // ==================== Follow ====================

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    setState(() => _isFollowLoading = true);

    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !wasFollowing;
      if (_user != null) {
        _user = UserProfileModel(
          id: _user!.id,
          userId: _user!.userId,
          username: _user!.username,
          avatarUrl: _user!.avatarUrl,
          bio: _user!.bio,
          level: _user!.level,
          points: _user!.points,
          nextLevelPoints: _user!.nextLevelPoints,
          followersCount: _user!.followersCount + (wasFollowing ? -1 : 1),
          followingCount: _user!.followingCount,
          totalLikes: _user!.totalLikes,
          isMentor: _user!.isMentor,
          isOfficial: _user!.isOfficial,
          isExpert: _user!.isExpert,
          isCulinaryInstructor: _user!.isCulinaryInstructor,
        );
      }
    });

    final result = wasFollowing
        ? await ApiService.unfollowUser(widget.userId)
        : await ApiService.followUser(widget.userId);

    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        _isFollowing = wasFollowing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isFollowLoading = false);
  }

  // ==================== Message / Chat ====================

  void _openChat() {
    if (_user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          otherUserId: _user!.userId,
          contactName: _user!.username,
          contactAvatar: _user!.avatarUrl,
          isMentor: _user!.isMentor,
        ),
      ),
    );
  }

  // ==================== Mentorship request ====================

  Future<void> _requestMentorship() async {
    if (_user == null) return;
    if (_isRequestingMentorship) return;
    if (_hasPendingRequest || _isMyMentor) return;

    setState(() => _isRequestingMentorship = true);

    final result = await ApiService.sendMentorshipRequest(
      mentorUserId: _user!.userId,
    );

    if (!mounted) return;
    setState(() => _isRequestingMentorship = false);

    if (result['success'] == true) {
      setState(() => _hasPendingRequest = true);

      // Navigate to chat automatically
      final data = result['data'] as Map<String, dynamic>?;
      final messageMap = data?['message'] as Map<String, dynamic>?;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            otherUserId: _user!.userId,
            contactName: _user!.username,
            contactAvatar: _user!.avatarUrl,
            isMentor: _user!.isMentor,
            initialMessage: messageMap,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to send request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF6B4C2A)),
          ),
          title: Text(
            'Loading...',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    if (_errorMessage != null || _user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF6B4C2A)),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFFFFB347)),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'User not found',
                style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD966),
                  foregroundColor: const Color(0xFF6B4C2A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          _user!.username,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B4C2A)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUser,
        color: const Color(0xFFFFB347),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    _buildProfileHeader(),
                    _buildTabBar(),
                    SliverToBoxAdapter(
                      child: _isLoadingContent
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFFB347)),
                              ),
                            )
                          : _buildContentForSection(),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAvatar(),
                const SizedBox(width: 20),
                Expanded(child: _buildUserInfo()),
              ],
            ),
            const SizedBox(height: 20),
            _buildBio(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 20),
            Container(
              height: 1,
              color: const Color(0xFFFFB347).withAlpha(50),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _user!.avatarUrl;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD966).withAlpha(50),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: const Color(0xFFFFD966),
        backgroundImage:
            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? const Icon(Icons.person, size: 50, color: Color(0xFF6B4C2A))
            : null,
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _user!.username,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'ID: ${_user!.userId}',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFFC9A96E),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        // Level chip + role badges (Official overrides everything else)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events,
                      size: 14, color: Color(0xFFFFB347)),
                  const SizedBox(width: 4),
                  Text(
                    'Level ${_user!.level}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB347),
                    ),
                  ),
                ],
              ),
            ),
            if (_user!.isOfficial)
              const UserBadge(type: UserBadgeType.official, fontSize: 10)
            else ...[
              if (_user!.isMentor)
                const UserBadge(type: UserBadgeType.mentor, fontSize: 10),
              if (_user!.isExpert)
                const UserBadge(type: UserBadgeType.expert, fontSize: 10),
              if (_user!.isCulinaryInstructor)
                const UserBadge(
                    type: UserBadgeType.culinaryInstructor, fontSize: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildBio() {
    return Text(
      _user!.bio.isNotEmpty ? _user!.bio : 'Food lover sharing recipes!',
      style: GoogleFonts.poppins(
        fontSize: 13,
        color: const Color(0xFF6B4C2A).withAlpha(200),
        height: 1.4,
      ),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildClickableStat(
          number: _user!.followersCount.toString(),
          label: 'Followers',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowListScreen(
                  type: 'followers',
                  userId: _user!.userId,
                  title: 'Followers',
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 40),
        _buildClickableStat(
          number: _user!.followingCount.toString(),
          label: 'Following',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowListScreen(
                  type: 'following',
                  userId: _user!.userId,
                  title: 'Following',
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 40),
        _buildClickableStat(
          number: _user!.totalLikes.toString(),
          label: 'Likes',
          onTap: null,
        ),
      ],
    );
  }

  Widget _buildClickableStat({
    required String number,
    required String label,
    VoidCallback? onTap,
  }) {
    final content = Column(
      children: [
        Text(
          number,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFFC9A96E),
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }

  // ==================== Action buttons ====================

  Widget _buildActionButtons() {
    if (widget.fromMentorTab) {
      return _buildMentorModeButtons();
    }
    return Row(
      children: [
        Expanded(child: _buildMessageButton()),
        const SizedBox(width: 12),
        Expanded(child: _buildFollowButton()),
      ],
    );
  }

  Widget _buildMentorModeButtons() {
    if (_isMyMentor) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF00B894).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00B894), size: 20),
            const SizedBox(width: 8),
            Text(
              'You are mentee of this chef',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF00B894),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasPendingRequest) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Request Pending',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: _isRequestingMentorship ? null : _requestMentorship,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB347),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRequestingMentorship)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.school, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Request Mentorship',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageButton() {
    return GestureDetector(
      onTap: _openChat,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 18, color: Color(0xFFFFB347)),
            const SizedBox(width: 6),
            Text(
              'Message',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    return GestureDetector(
      onTap: _isFollowLoading ? null : _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color:
              _isFollowing ? Colors.grey.shade200 : const Color(0xFFFFB347),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isFollowLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                _isFollowing ? Icons.check : Icons.person_add,
                size: 18,
                color:
                    _isFollowing ? const Color(0xFF6B4C2A) : Colors.white,
              ),
            const SizedBox(width: 6),
            Text(
              _isFollowing ? 'Following' : 'Follow',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isFollowing ? const Color(0xFF6B4C2A) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Tab bar & content ====================

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFB347),
          unselectedLabelColor: const Color(0xFFC9A96E),
          indicator: const BoxDecoration(),
          dividerColor: Colors.transparent,
          labelStyle:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Liked'),
            Tab(text: 'Comments'),
          ],
        ),
      ),
    );
  }

  Widget _buildContentForSection() {
    switch (_selectedSection) {
      case 0:
        return _buildPostsContent();
      case 1:
        return _buildLikedContent();
      case 2:
        return _buildCommentsContent();
      default:
        return _buildPostsContent();
    }
  }

  Widget _buildPostsContent() {
    return Column(
      children: [
        _buildSubTabRow(
          leftLabel: 'Recipes',
          rightLabel: 'Ingredients Guidance',
          selected: _postsSubCategory,
          onLeft: () {
            setState(() => _postsSubCategory = 0);
            _loadContentForSection(0);
          },
          onRight: () {
            setState(() => _postsSubCategory = 1);
            _loadContentForSection(0);
          },
        ),
        _postsSubCategory == 0
            ? _buildRecipeGrid(_myRecipes)
            : _buildIngredientGrid(_myIngredients),
      ],
    );
  }

  Widget _buildLikedContent() {
    return Column(
      children: [
        _buildSubTabRow(
          leftLabel: 'Recipes',
          rightLabel: 'Ingredients Guidance',
          selected: _likedSubCategory,
          onLeft: () {
            setState(() => _likedSubCategory = 0);
            _loadContentForSection(1);
          },
          onRight: () {
            setState(() => _likedSubCategory = 1);
            _loadContentForSection(1);
          },
        ),
        _likedSubCategory == 0
            ? _buildRecipeGrid(_likedRecipes)
            : _buildIngredientGrid(_likedIngredients),
      ],
    );
  }

  Widget _buildCommentsContent() {
    return Column(
      children: [
        _buildSubTabRow(
          leftLabel: 'Recipes',
          rightLabel: 'Ingredients Guidance',
          selected: _commentsSubCategory,
          onLeft: () {
            setState(() => _commentsSubCategory = 0);
            _loadContentForSection(2);
          },
          onRight: () {
            setState(() => _commentsSubCategory = 1);
            _loadContentForSection(2);
          },
        ),
        _commentsSubCategory == 0
            ? _buildCommentsList(_commentsOnRecipes)
            : _buildCommentsList(_commentsOnGuidance),
      ],
    );
  }

  Widget _buildSubTabRow({
    required String leftLabel,
    required String rightLabel,
    required int selected,
    required VoidCallback onLeft,
    required VoidCallback onRight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SubTabButton(
              text: leftLabel,
              isSelected: selected == 0,
              onTap: onLeft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SubTabButton(
              text: rightLabel,
              isSelected: selected == 1,
              onTap: onRight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeGrid(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No recipes yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 280,
        ),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return RecipeCard(
            recipe: recipe,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PostDetailScreen(recipeId: recipe.id),
                ),
              );
              if (mounted) _loadContentForSection(_selectedSection);
            },
          );
        },
      ),
    );
  }

  Widget _buildIngredientGrid(List<IngredientPost> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No ingredients posts yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return ingredient_widgets.IngredientCard(
            post: post,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IngredientDetailScreen(post: post),
                ),
              );
              if (mounted) _loadContentForSection(_selectedSection);
            },
          );
        },
      ),
    );
  }

  Widget _buildCommentsList(List<CommentCard> comments) {
    if (comments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.comment_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No comments yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return GestureDetector(
          onTap: () async {
            if (comment.type == ContentType.recipe) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PostDetailScreen(recipeId: comment.postId),
                ),
              );
              if (mounted) _loadContentForSection(_selectedSection);
            } else {
              _navigateToIngredientDetail(comment.postId);
            }
          },
          child: CommentCardWidget(comment: comment),
        );
      },
    );
  }

  void _navigateToIngredientDetail(String postId) async {
    try {
      final token = ApiService.authToken;
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/ingredients/$postId/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final post = IngredientPost.fromJson(data);
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IngredientDetailScreen(post: post),
            ),
          );
          if (mounted) _loadContentForSection(_selectedSection);
        }
      }
    } catch (e) {
      debugPrint('Error loading ingredient: $e');
    }
  }
}

// ==================== Helper Widgets ====================

class SubTabButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const SubTabButton({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFB347) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFFC9A96E),
            ),
          ),
        ),
      ),
    );
  }
}

class CommentCardWidget extends StatelessWidget {
  final CommentCard comment;

  const CommentCardWidget({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              comment.imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: const Color(0xFFFFF0B5),
                child: const Icon(Icons.restaurant, color: Color(0xFFFFD966)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.contentTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  comment.commentText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.date,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}