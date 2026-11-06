// screens/post_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import '../../models/recipe.dart';
import '../../models/comment.dart';
import '../../widgets/post_action_bar.dart';
import '../../widgets/creation_card.dart';
import '../../widgets/author_badge.dart';
import '../../services/api_service.dart';
import '../profile/user_profile_screen.dart';
import 'add_post/add_post_screen.dart';
import 'post_detail_fullscreen.dart';

class MediaItem {
  final bool isVideo;
  final String url;

  const MediaItem({required this.isVideo, required this.url});
}

class PostDetailScreen extends StatefulWidget {
  final String recipeId;

  const PostDetailScreen({super.key, required this.recipeId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Recipe? _recipe;
  bool _isLoading = true;
  String? _errorMessage;

  int _currentMediaIndex = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  final List<MediaItem> _mediaItems = [];
  double? _mediaAspectRatio;

  List<Map<String, dynamic>> _creations = [];

  // Current user identifiers: `id` is the DB id, `user_id` is the public 8-char id.
  String? _currentUserId;
  String? _currentUserUserId;

  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchRecipeDetail();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // ==================== Current user ====================

  Future<void> _loadCurrentUser() async {
    final result = await ApiService.getCurrentUserId();
    if (result['success'] == true && mounted) {
      setState(() {
        _currentUserId = result['id']?.toString();
        _currentUserUserId = result['user_id']?.toString();
      });
    }
  }

  bool get _isOwner {
    if (_recipe == null || _currentUserId == null) return false;
    return _recipe!.authorId == _currentUserId;
  }

  bool _isMyComment(Comment comment) {
    if (_currentUserUserId == null) return false;
    return comment.userId == _currentUserUserId;
  }

  /// True when the comment is written by the recipe's author.
  bool _isPostAuthorComment(Comment comment) {
    final authorUserId = _recipe?.authorUserId;
    if (authorUserId == null || authorUserId.isEmpty) return false;
    return comment.userId == authorUserId;
  }

  // ==================== Follow ====================

  Future<void> _checkFollowStatus() async {
    if (_recipe == null || _recipe!.authorUserId.isEmpty) return;
    final result = await ApiService.checkFollow(_recipe!.authorUserId);
    if (mounted && result['success'] == true) {
      setState(() {
        _isFollowing = result['is_following'] == true;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_recipe == null || _recipe!.authorUserId.isEmpty) return;
    if (_isFollowLoading) return;

    setState(() => _isFollowLoading = true);

    final result = _isFollowing
        ? await ApiService.unfollowUser(_recipe!.authorUserId)
        : await ApiService.followUser(_recipe!.authorUserId);

    if (!mounted) return;

    setState(() {
      _isFollowLoading = false;
      if (result['success'] == true) {
        _isFollowing = !_isFollowing;
      }
    });

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to update follow'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openAuthorProfile() {
    if (_recipe == null) return;
    if (_recipe!.authorUserId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: _recipe!.authorUserId),
      ),
    );
  }

  // ==================== Fetch detail ====================

  Future<void> _fetchRecipeDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = ApiService.authToken;
      final url = Uri.parse('${ApiService.baseUrl}/recipes/${widget.recipeId}/');

      final response = await http.get(
        url,
        headers: token != null ? {'Authorization': 'Token $token'} : {},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recipe = Recipe.fromJson(data);
          _buildMediaItems();
          _buildCreations();
          _isLoading = false;
        });

        if (!_isOwner) {
          await _checkFollowStatus();
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load recipe: ${response.statusCode}';
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

  void _buildCreations() {
    _creations.clear();
    if (_recipe == null) return;

    final homeworks = _recipe!.homeworks ?? [];
    final authorUserId = _recipe!.authorUserId;

    for (final homework in homeworks) {
      final hwUserId = homework.userId;
      _creations.add({
        'homeworkId': homework.id,
        'userName': homework.userName,
        'userAvatar': homework.userAvatar,
        'imageUrl': homework.imageUrl,
        'comment': homework.review,
        'rating': homework.rating,
        'likes': homework.likes,
        'isLiked': homework.isLiked,
        'recommendation': homework.recommendation,
        'isAuthor': authorUserId.isNotEmpty && hwUserId == authorUserId,
      });
    }
  }

  // ==================== Media ====================

  void _buildMediaItems() {
    _mediaItems.clear();
    if (_recipe == null) return;

    for (final photoUrl in _recipe!.photoUrls) {
      if (photoUrl.isNotEmpty) {
        _mediaItems.add(MediaItem(
          isVideo: false,
          url: ApiService.resolveImageUrl(photoUrl),
        ));
      }
    }

    if (_recipe!.videoUrl != null && _recipe!.videoUrl!.isNotEmpty) {
      _mediaItems.add(MediaItem(
        isVideo: true,
        url: ApiService.resolveImageUrl(_recipe!.videoUrl!),
      ));
    }

    if (_mediaItems.isEmpty) return;

    if (_mediaItems[0].isVideo) {
      _initVideoController(_mediaItems[0].url);
    } else {
      _loadFirstImageAspectRatio(_mediaItems[0].url);
    }
  }

  void _loadFirstImageAspectRatio(String url) {
    final stream = NetworkImage(url).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (mounted && h > 0) {
          setState(() => _mediaAspectRatio = w / h);
        }
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (mounted) setState(() => _mediaAspectRatio = 16 / 9);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  Future<void> _initVideoController(String url) async {
    try {
      _videoController?.dispose();
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {
        _isVideoInitialized = true;
        _mediaAspectRatio ??= _videoController!.value.aspectRatio;
      });
      _videoController!.play();
      _videoController!.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) setState(() => _mediaAspectRatio = 16 / 9);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentMediaIndex = index);

    if (index < _mediaItems.length && _mediaItems[index].isVideo) {
      if (_videoController == null ||
          _videoController!.dataSource != _mediaItems[index].url) {
        _initVideoController(_mediaItems[index].url);
      } else if (!_videoController!.value.isPlaying) {
        _videoController!.play();
      }
    } else {
      if (_videoController != null && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    }
  }

  void _showFullscreenMedia(int startIndex) {
    if (_mediaItems.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMediaScreen(
          items: _mediaItems
              .map((e) => FullscreenMediaItem(isVideo: e.isVideo, url: e.url))
              .toList(),
          startIndex: startIndex,
        ),
      ),
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null || _recipe == null) return _buildErrorState();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_mediaItems.isNotEmpty) _buildMediaFrame(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAuthorRow(),
                        const SizedBox(height: 16),
                        Text(
                          _recipe!.description,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF6B4C2A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTags(),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFFFF0B5)),
                        const SizedBox(height: 12),
                        _buildDetailChips(),
                        const SizedBox(height: 12),
                        if (_recipe!.cookingTools.isNotEmpty)
                          _buildCookingTools(),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFFFF0B5)),
                        const SizedBox(height: 8),
                        _buildIngredients(),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFFFF0B5)),
                        const SizedBox(height: 8),
                        _buildSteps(),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFFFF0B5)),
                        const SizedBox(height: 8),
                        if (_creations.isNotEmpty) _buildCreationsSection(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          PostActionBar(
            recipeId: _recipe!.id.toString(),
            recipe: _recipe!,
            onCommentTap: _showCommentsDialog,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        color: const Color(0xFF6B4C2A),
      ),
      title: Text(
        _recipe?.title ?? 'Recipe',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: const Color(0xFF6B4C2A),
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF6B4C2A)),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _handleEdit();
                break;
              case 'delete':
                _handleDelete();
                break;
              case 'report':
                _handleReport();
                break;
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];
            if (_isOwner) {
              items.add(_menuItem('edit', Icons.edit_outlined, 'Edit',
                  const Color(0xFF6B4C2A)));
              items.add(
                  _menuItem('delete', Icons.delete_outline, 'Delete', Colors.red));
            } else {
              items.add(_menuItem(
                  'report', Icons.flag_outlined, 'Report', const Color(0xFF6B4C2A)));
            }
            return items;
          },
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.poppins(color: color)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF6B4C2A),
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

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF6B4C2A),
        ),
        title: Text(
          'Error',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFFFB347)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Recipe not found',
              style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRecipeDetail,
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

  // ==================== Author row ====================

  Widget _buildAuthorRow() {
    final avatarUrl = ApiService.resolveImageUrl(_recipe!.authorAvatar);

    return Row(
      children: [
        GestureDetector(
          onTap: _isOwner ? null : _openAuthorProfile,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFFFD966),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 20, color: Color(0xFF6B4C2A))
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recipe!.authorName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _recipe!.isEdited
                        ? 'Edited by ${_recipe!.editedDateText}'
                        : 'Posted by ${_recipe!.postedDateText}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFC9A96E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        if (!_isOwner) _buildFollowButton(),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recipe!.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5E6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD966), width: 0.5),
          ),
          child: Text(
            tag.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFC9A96E),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailChips() {
    return Row(
      children: [
        Expanded(
          child: _buildDetailChip(
            icon: Icons.restaurant,
            label: _recipe!.cuisineType.isNotEmpty ? _recipe!.cuisineType : 'Any',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDetailChip(
            icon: Icons.timer,
            label: _recipe!.formattedDuration,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDetailChip(
            icon: Icons.speed,
            label: _recipe!.difficultyText,
          ),
        ),
      ],
    );
  }

  Widget _buildCookingTools() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cooking Tools',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recipe!.cookingTools.map((tool) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD966)),
                ),
                child: Text(
                  tool.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        ..._recipe!.ingredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ingredient = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD966),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    ingredient.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (ingredient.amount.isNotEmpty)
                  SizedBox(
                    width: 80,
                    child: Text(
                      ingredient.amount,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFFC9A96E),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 12),
        ..._recipe!.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD966),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.instruction,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF6B4C2A),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (step.note != null && step.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5E6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFD966).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Color(0xFFFFB347),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step.note!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFC9A96E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCreationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dishes from the community',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        ..._creations.map((item) {
          return CreationCard(
            homeworkId: item['homeworkId'] as String,
            userName: item['userName'] as String,
            userAvatar:
                ApiService.resolveImageUrl(item['userAvatar'] as String),
            imageUrl: ApiService.resolveImageUrl(item['imageUrl'] as String),
            comment: item['comment'] as String,
            rating: item['rating']?.toString() ?? 'good',
            isAuthor: item['isAuthor'] == true,
            recommendation: item['recommendation']?.toString(),
            initialLikes: (item['likes'] is int) ? item['likes'] as int : 0,
            initialIsLiked: item['isLiked'] == true,
          );
        }),
      ],
    );
  }

  // ==================== Media frame ====================

  Widget _buildMediaFrame() {
    final aspect = _mediaAspectRatio;
    if (aspect == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: const Color(0xFFFFF9E6),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFB347)),
          ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showFullscreenMedia(_currentMediaIndex),
          child: AspectRatio(
            aspectRatio: aspect,
            child: Container(
              color: const Color(0xFFFFF9E6),
              child: PageView.builder(
                onPageChanged: _onPageChanged,
                itemCount: _mediaItems.length,
                itemBuilder: (context, index) {
                  final item = _mediaItems[index];
                  if (item.isVideo) return _buildVideoPlayer();
                  return _buildImage(item.url);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_mediaItems.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_mediaItems.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentMediaIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentMediaIndex == index
                      ? const Color(0xFFFFB347)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const Icon(
        Icons.broken_image,
        size: 80,
        color: Color(0xFFFFD966),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_isVideoInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB347)),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => _showFullscreenMedia(_currentMediaIndex),
          onTap: () async {
            final v = _videoController;
            if (v == null) return;
            if (v.value.isPlaying) {
              await v.pause();
            } else {
              if (v.value.position >= v.value.duration) {
                await v.seekTo(Duration.zero);
              }
              await v.play();
            }
            if (mounted) setState(() {});
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              if (!_videoController!.value.isPlaying)
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Follow button ====================

  Widget _buildFollowButton() {
    final bg = _isFollowing ? Colors.grey.shade300 : const Color(0xFFFFD966);
    final fg = _isFollowing ? Colors.grey.shade700 : const Color(0xFF6B4C2A);

    return SizedBox(
      height: 36,
      child: _isFollowLoading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFFB347),
                ),
              ),
            )
          : TextButton(
              onPressed: _toggleFollow,
              style: TextButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _isFollowing ? 'Following' : 'Follow',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
    );
  }

  // ==================== Comments ====================

  void _showCommentsDialog() {
    final comments = _recipe?.commentList ?? [];
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Column(
                  children: [
                    _buildSheetHandle(bottomSheetContext),
                    const SizedBox(height: 8),
                    Text(
                      'Comments (${comments.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: comments.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFC9A96E),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                return _buildCommentItem(
                                  comments[index],
                                  bottomSheetContext,
                                  setModalState,
                                  avatarRadius: 14,
                                  nameFontSize: 12,
                                  contentFontSize: 13,
                                );
                              },
                            ),
                    ),
                    _buildCommentInput(commentController, bottomSheetContext),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetHandle(BuildContext bottomSheetContext) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 40, height: 4),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(bottomSheetContext),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 20,
                color: Color(0xFFC9A96E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    Comment comment,
    BuildContext bottomSheetContext,
    StateSetter setModalState, {
    required double avatarRadius,
    required double nameFontSize,
    required double contentFontSize,
  }) {
    final isMine = _isMyComment(comment);
    final isAuthor = _isPostAuthorComment(comment);
    final avatarUrl = ApiService.resolveImageUrl(comment.userAvatar);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: const Color(0xFFFFB347),
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: avatarRadius * 0.75,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.userName,
                        style: GoogleFonts.poppins(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C2A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAuthor) ...[
                      const SizedBox(width: 6),
                      AuthorBadge(fontSize: nameFontSize - 3),
                    ],
                    if (isMine) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _confirmDeleteComment(
                          comment,
                          bottomSheetContext,
                          setModalState,
                        ),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.poppins(
                            fontSize: nameFontSize - 1,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: GoogleFonts.poppins(
                    fontSize: contentFontSize,
                    color: const Color(0xFF6B4C2A).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(
    TextEditingController controller,
    BuildContext bottomSheetContext,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: controller,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              controller.clear();

              await _addComment(text);
              if (!mounted) return;
              Navigator.pop(bottomSheetContext);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFB347),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment(String content) async {
    try {
      final token = ApiService.authToken;
      final url =
          Uri.parse('${ApiService.baseUrl}/recipes/${widget.recipeId}/comments/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Token $token',
        },
        body: jsonEncode({'text': content, 'photo_urls': []}),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        await _fetchRecipeDetail();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMsg = 'Failed: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmDeleteComment(
    Comment comment,
    BuildContext bottomSheetContext,
    StateSetter setModalState,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Comment?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFF6B4C2A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFFC9A96E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteComment(comment.id);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(bottomSheetContext);
      await _fetchRecipeDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Comment deleted'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to delete comment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== Post actions ====================

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPostScreen(editRecipeId: widget.recipeId),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _fetchRecipeDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Recipe?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          'This action cannot be undone. Are you sure you want to delete this recipe?',
          style:
              GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B4C2A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFFC9A96E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteRecipe(widget.recipeId);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Recipe deleted'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to delete'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleReport() {
    String? selectedReason;
    final noteController = TextEditingController();

    final reasons = <Map<String, String>>[
      {'value': 'inappropriate', 'label': 'Inappropriate content'},
      {'value': 'spam', 'label': 'Spam / Advertising'},
      {'value': 'violence', 'label': 'Violence or dangerous content'},
      {'value': 'harassment', 'label': 'Harassment or hate speech'},
      {'value': 'copyright', 'label': 'Copyright violation'},
      {'value': 'other', 'label': 'Other'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFFF9E6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.flag_outlined,
                    color: Color(0xFFFFB347), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Report Post',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a reason:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...reasons.map((r) {
                    final isSelected = selectedReason == r['value'];
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedReason = r['value']);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFF5E6)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFFB347)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected
                                  ? const Color(0xFFFFB347)
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              r['label']!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text(
                    'Additional details (optional):',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe the issue...',
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFFFFB347), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
                ),
              ),
              TextButton(
                onPressed: selectedReason == null
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        await _submitReport(
                          selectedReason!,
                          noteController.text.trim(),
                        );
                      },
                style: TextButton.styleFrom(
                  backgroundColor: selectedReason == null
                      ? Colors.grey.shade300
                      : const Color(0xFFFFB347),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Submit',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitReport(String reason, String note) async {
    final result = await ApiService.reportPost(
      postType: 'recipe',
      postId: widget.recipeId,
      reason: reason,
      note: note,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Report submitted. Our team will review it shortly.'
              : (result['error'] ?? 'Failed to submit report'),
        ),
        backgroundColor:
            result['success'] == true ? Colors.green : Colors.red,
      ),
    );
  }

  // ==================== Helpers ====================

  Widget _buildDetailChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFF0B5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFFB347)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}