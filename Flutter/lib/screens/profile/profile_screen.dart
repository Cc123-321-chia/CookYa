// screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/recipe.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/user_badge.dart';
import 'my_dishes_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'level_detail_screen.dart';
import 'models.dart';
import '../recipes/widgets.dart';
import '../groceries/grocery_screen.dart';
import '../ingredient/models.dart';
import '../ingredient/ingredients_detail_screen.dart';
import '../recipes/post_detail_screen.dart';
import '../ingredient/widgets.dart' as ingredient_widgets;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedSection = 0;

  // Sub-categories
  int _postsSubCategory = 0;
  int _likedSubCategory = 0;
  int _commentsSubCategory = 0;

  // User data
  UserModel? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  // Content data
  List<Recipe> _myRecipes = [];
  List<IngredientPost> _myIngredients = [];
  List<Recipe> _likedRecipes = [];
  List<IngredientPost> _likedIngredients = [];
  List<CommentCard> _commentsOnRecipes = [];
  List<CommentCard> _commentsOnGuidance = [];
  bool _isLoadingContent = false;

  // Static level data
  final List<LevelInfo> _levelInfo = const [
    LevelInfo(level: 1, minPoints: 0, maxPoints: 100, title: 'Seedling Chef', icon: Icons.eco),
    LevelInfo(level: 2, minPoints: 100, maxPoints: 250, title: 'Apprentice Cook', icon: Icons.restaurant),
    LevelInfo(level: 3, minPoints: 250, maxPoints: 450, title: 'Home Chef', icon: Icons.local_fire_department),
    LevelInfo(level: 4, minPoints: 450, maxPoints: 700, title: 'Skilled Cook', icon: Icons.kitchen),
    LevelInfo(level: 5, minPoints: 700, maxPoints: 1000, title: 'Master Chef', icon: Icons.emoji_events),
    LevelInfo(level: 6, minPoints: 1000, maxPoints: 1350, title: 'Elite Chef Mentor', icon: Icons.workspace_premium),
    LevelInfo(level: 7, minPoints: 1350, maxPoints: 1750, title: 'Legendary Chef', icon: Icons.auto_awesome),
    LevelInfo(level: 8, minPoints: 1750, maxPoints: 2500, title: 'Culinary Master', icon: Icons.diamond),
    LevelInfo(level: 9, minPoints: 2500, maxPoints: 3500, title: 'Grand Master', icon: Icons.rocket_launch),
    LevelInfo(level: 10, minPoints: 3500, maxPoints: 5000, title: 'Cooking God', icon: Icons.all_inclusive),
    LevelInfo(level: 11, minPoints: 5000, maxPoints: 999999, title: 'Ultimate Chef', icon: Icons.stars),
  ];

  // Daily-login bonus removed.
  final List<PointRule> _pointRules = const [
    PointRule(activity: 'Upload a dish', points: 1, icon: Icons.upload_file),
    PointRule(activity: 'Chef likes your dish', points: 10, icon: Icons.emoji_events),
    PointRule(activity: 'Receive a like on your post', points: 1, icon: Icons.favorite),
    PointRule(activity: 'Post a recipe', points: 10, icon: Icons.post_add),
    PointRule(activity: 'Post ingredients guidance', points: 5, icon: Icons.edit_note),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedSection = _tabController.index;
      });
      _loadContentForSection(_selectedSection);
    });
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getNextLevelPoints(int currentLevel) {
    const levelThresholds = [
      0, 100, 250, 450, 700, 1000, 1350, 1750, 2500, 3500, 5000,
    ];
    if (currentLevel >= levelThresholds.length) return 999999;
    return levelThresholds[currentLevel];
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = ApiService.authToken;

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please login first';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/users/profile/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final userData = jsonResponse['data'];

        final avatar = userData['avatar'] ?? '';
        final avatarUrl = avatar.isNotEmpty ? avatar : '';

        setState(() {
          _currentUser = UserModel(
            id: userData['id']?.toString() ?? '',
            userId: userData['user_id'] ?? 'unknown',
            name: userData['username'] ?? 'User',
            avatarUrl: avatarUrl,
            bio: userData['bio']?.isNotEmpty == true
                ? userData['bio']
                : 'Food lover sharing recipes!',
            level: userData['level'] ?? 1,
            currentPoints: userData['points'] ?? 0,
            nextLevelPoints: _getNextLevelPoints(userData['level'] ?? 1),
            followers: userData['followers_count'] ?? 0,
            following: userData['following_count'] ?? 0,
            totalLikes: userData['total_likes_received'] ?? 0,
            isMentor: userData['is_mentor'] == true,
            isExpert: userData['is_expert'] == true,
            isOfficial: userData['is_official'] == true,
            isCulinaryInstructor: userData['is_culinary_instructor'] == true,
          );
          _isLoading = false;
        });

        _loadContentForSection(_selectedSection);
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load profile: ${response.statusCode}';
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

  Future<void> _loadContentForSection(int section) async {
    if (_currentUser == null) return;

    setState(() {
      _isLoadingContent = true;
    });

    try {
      final token = ApiService.authToken;
      if (token == null) return;

      final baseUrl = ApiService.baseUrl;

      switch (section) {
        case 0:
          if (_postsSubCategory == 0) {
            final response = await http.get(
              Uri.parse('$baseUrl/recipes/?author=${_currentUser!.id}'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              setState(() {
                _myRecipes =
                    data.map((json) => Recipe.fromJson(json)).toList();
              });
            }
          } else {
            final response = await http.get(
              Uri.parse('$baseUrl/ingredients/?author=${_currentUser!.id}'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
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
              Uri.parse('$baseUrl/recipes/liked/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              setState(() {
                _likedRecipes =
                    data.map((json) => Recipe.fromJson(json)).toList();
              });
            }
          } else {
            final response = await http.get(
              Uri.parse('$baseUrl/ingredients/liked/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
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
              Uri.parse('$baseUrl/recipes/my-comments/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
              setState(() {
                _commentsOnRecipes = data
                    .map((json) => CommentCard.fromRecipeCommentJson(json))
                    .toList();
              });
            }
          } else {
            final response = await http.get(
              Uri.parse('$baseUrl/ingredients/my-comments/'),
              headers: {'Authorization': 'Token $token'},
            );
            if (response.statusCode == 200) {
              final List<dynamic> data = jsonDecode(response.body);
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

    setState(() {
      _isLoadingContent = false;
    });
  }

  void _updateProfile(Map<String, dynamic> updatedData) {
    if (_currentUser == null) return;
    setState(() {
      _currentUser = UserModel(
        id: _currentUser!.id,
        userId: updatedData['userId'] ?? _currentUser!.userId,
        name: updatedData['name'] ?? _currentUser!.name,
        avatarUrl: updatedData['avatarUrl'] ?? _currentUser!.avatarUrl,
        bio: updatedData['bio'] ?? _currentUser!.bio,
        level: _currentUser!.level,
        currentPoints: _currentUser!.currentPoints,
        nextLevelPoints: _currentUser!.nextLevelPoints,
        followers: _currentUser!.followers,
        following: _currentUser!.following,
        totalLikes: _currentUser!.totalLikes,
        isMentor: _currentUser!.isMentor,
        isExpert: _currentUser!.isExpert,
        isOfficial: _currentUser!.isOfficial,
        isCulinaryInstructor: _currentUser!.isCulinaryInstructor,
      );
    });
  }

  void _showLevelDetailPage() {
    if (_currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LevelDetailPage(
          currentUser: _currentUser!,
          levelInfo: _levelInfo,
          pointRules: _pointRules,
        ),
      ),
    );
  }

  void _showMyDishesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyDishesScreen()),
    );
  }

  void _editProfile() {
    if (_currentUser == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userData: {
            'name': _currentUser!.name,
            'bio': _currentUser!.bio,
            'avatarUrl': _currentUser!.avatarUrl,
            'userId': _currentUser!.userId,
          },
          onProfileUpdated: _updateProfile,
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await _fetchUserProfile();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFFB347),
      ),
    );
  }

  void _navigateToIngredientDetail(String postId) async {
    try {
      final token = ApiService.authToken;
      if (token == null) {
        _showSnackBar('Please login first');
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/ingredients/$postId/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final post = IngredientPost.fromJson(data);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => IngredientDetailScreen(post: post),
            ),
          );
        }
      } else {
        _showSnackBar('Failed to load ingredient');
      }
    } catch (e) {
      debugPrint('Error loading ingredient: $e');
      _showSnackBar('Error loading ingredient');
    }
  }

  void _showGroceryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroceryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    if (_errorMessage != null || _currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFFFFB347)),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to load profile',
                style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD966),
                  foregroundColor: const Color(0xFF6B4C2A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
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
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined, size: 24),
            color: const Color(0xFFC9A96E),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined, size: 24),
            color: const Color(0xFFC9A96E),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
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
    final avatarUrl = _currentUser!.avatarUrl;

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
        backgroundImage: avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(
                ApiService.resolveImageUrl(avatarUrl))
            : null,
        child: avatarUrl.isEmpty
            ? const Icon(
                Icons.person,
                size: 50,
                color: Color(0xFF6B4C2A),
              )
            : null,
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentUser!.name,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 2),
        // ID + role badges
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'ID: ${_currentUser!.userId}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFC9A96E),
                fontWeight: FontWeight.w500,
              ),
            ),
            // Official overrides other roles
            if (_currentUser!.isOfficial)
              const UserBadge(type: UserBadgeType.official, fontSize: 10)
            else ...[
              if (_currentUser!.isMentor)
                const UserBadge(type: UserBadgeType.mentor, fontSize: 10),
              if (_currentUser!.isExpert)
                const UserBadge(type: UserBadgeType.expert, fontSize: 10),
              if (_currentUser!.isCulinaryInstructor)
                const UserBadge(
                    type: UserBadgeType.culinaryInstructor, fontSize: 10),
            ],
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showLevelDetailPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 14,
                  color: Color(0xFFFFB347),
                ),
                const SizedBox(width: 4),
                Text(
                  'Level ${_currentUser!.level}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFB347),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBio() {
    return Text(
      _currentUser!.bio,
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
        StatColumn(
            number: _currentUser!.followers.toString(), label: 'Followers'),
        const SizedBox(width: 40),
        StatColumn(
            number: _currentUser!.following.toString(), label: 'Following'),
        const SizedBox(width: 40),
        StatColumn(
            number: _currentUser!.totalLikes.toString(), label: 'Likes'),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(child: _buildMyDishesButton()),
        const SizedBox(width: 12),
        Expanded(child: _buildGroceryButton()),
      ],
    );
  }

  Widget _buildMyDishesButton() {
    return GestureDetector(
      onTap: _showMyDishesPage,
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
            const Icon(Icons.dinner_dining,
                size: 18, color: Color(0xFFFFB347)),
            const SizedBox(width: 6),
            Text(
              'My Dishes',
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

  Widget _buildGroceryButton() {
    return GestureDetector(
      onTap: _showGroceryScreen,
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
            const Icon(
              Icons.shopping_cart_outlined,
              size: 18,
              color: Color(0xFFFFB347),
            ),
            const SizedBox(width: 6),
            Text(
              'Grocery',
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
            Tab(text: 'My Posts'),
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
        return _buildMyPostsContent();
      case 1:
        return _buildLikedContent();
      case 2:
        return _buildCommentsContent();
      default:
        return _buildMyPostsContent();
    }
  }

  Widget _buildMyPostsContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SubTabButton(
                  text: 'Recipes',
                  isSelected: _postsSubCategory == 0,
                  onTap: () {
                    setState(() => _postsSubCategory = 0);
                    _loadContentForSection(0);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SubTabButton(
                  text: 'Ingredients Guidance',
                  isSelected: _postsSubCategory == 1,
                  onTap: () {
                    setState(() => _postsSubCategory = 1);
                    _loadContentForSection(0);
                  },
                ),
              ),
            ],
          ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SubTabButton(
                  text: 'Recipes',
                  isSelected: _likedSubCategory == 0,
                  onTap: () {
                    setState(() => _likedSubCategory = 0);
                    _loadContentForSection(1);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SubTabButton(
                  text: 'Ingredients Guidance',
                  isSelected: _likedSubCategory == 1,
                  onTap: () {
                    setState(() => _likedSubCategory = 1);
                    _loadContentForSection(1);
                  },
                ),
              ),
            ],
          ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: SubTabButton(
                  text: 'Recipes',
                  isSelected: _commentsSubCategory == 0,
                  onTap: () {
                    setState(() => _commentsSubCategory = 0);
                    _loadContentForSection(2);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SubTabButton(
                  text: 'Ingredients Guidance',
                  isSelected: _commentsSubCategory == 1,
                  onTap: () {
                    setState(() => _commentsSubCategory = 1);
                    _loadContentForSection(2);
                  },
                ),
              ),
            ],
          ),
        ),
        _commentsSubCategory == 0
            ? _buildCommentsList(_commentsOnRecipes)
            : _buildCommentsList(_commentsOnGuidance),
      ],
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
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PostDetailScreen(recipeId: recipe.id),
                ),
              );
              if (result == true) {
                _loadContentForSection(_selectedSection);
              }
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
          childAspectRatio: 0.68,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return ingredient_widgets.IngredientCard(
            post: post,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => IngredientDetailScreen(post: post),
                ),
              );
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
              if (mounted) {
                _loadContentForSection(_selectedSection);
              }
            } else {
              _navigateToIngredientDetail(comment.postId);
            }
          },
          child: CommentCardWidget(comment: comment),
        );
      },
    );
  }
}

// ==================== Helper Widgets ====================

class StatColumn extends StatelessWidget {
  final String number;
  final String label;

  const StatColumn({
    super.key,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}

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
            child: CachedNetworkImage(
              imageUrl: ApiService.resolveImageUrl(comment.imageUrl),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: const Color(0xFFFFF0B5),
                child:
                    const Icon(Icons.restaurant, color: Color(0xFFFFD966)),
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
          Row(
            children: [
              Icon(
                Icons.favorite_border,
                size: 14,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                '${comment.likes}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}