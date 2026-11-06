// screens/ingredient/ingredients_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import '../../services/api_service.dart';
import 'add_ingredient_post_screen.dart';
import 'ingredient_detail_fullscreen.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/author_badge.dart';

class MediaItem {
  final bool isVideo;
  final String url;

  const MediaItem({required this.isVideo, required this.url});
}

class IngredientDetailScreen extends StatefulWidget {
  final IngredientPost post;

  const IngredientDetailScreen({super.key, required this.post});

  @override
  State<IngredientDetailScreen> createState() => _IngredientDetailScreenState();
}

class _IngredientDetailScreenState extends State<IngredientDetailScreen> {
  bool isLiked = false;
  late int likeCount;

  bool _isFollowing = false;
  bool _isFollowLoading = false;

  List<IngredientComment> _comments = [];
  int _commentCount = 0;
  int _currentMediaIndex = 0;

  // `id` is the DB id, `user_id` is the public 8-char id.
  String? _currentUserId;
  String? _currentUserUserId;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  final List<MediaItem> _mediaItems = [];
  double? _mediaAspectRatio;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post.likes;
    isLiked = widget.post.isLiked;
    _commentCount = widget.post.comments;
    _loadCurrentUser();
    _fetchComments();
    _buildMediaItems();
    _refreshPostDetail();
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
      await _checkFollowStatus();
    }
  }

  bool get _isOwner {
    if (_currentUserId == null) return false;
    return widget.post.authorId == _currentUserId;
  }

  bool _isMyComment(IngredientComment comment) {
    if (_currentUserUserId == null) return false;
    return comment.userId == _currentUserUserId;
  }

  /// True when the comment is written by the post's author.
  bool _isPostAuthorComment(IngredientComment comment) {
    final authorUserId = widget.post.authorUserId;
    if (authorUserId.isEmpty) return false;
    return comment.userId == authorUserId;
  }

  // ==================== Follow ====================

  Future<void> _checkFollowStatus() async {
    if (_isOwner) return;
    final authorUserId = widget.post.authorUserId;
    if (authorUserId.isEmpty) return;
    final result = await ApiService.checkFollow(authorUserId);
    if (mounted && result['success'] == true) {
      setState(() => _isFollowing = result['is_following'] == true);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isOwner) return;
    final authorUserId = widget.post.authorUserId;
    if (authorUserId.isEmpty) return;
    if (_isFollowLoading) return;

    setState(() => _isFollowLoading = true);

    final result = _isFollowing
        ? await ApiService.unfollowUser(authorUserId)
        : await ApiService.followUser(authorUserId);

    if (!mounted) return;

    setState(() {
      _isFollowLoading = false;
      if (result['success'] == true) {
        _isFollowing = !_isFollowing;
      }
    });

    if (result['success'] != true) {
      _showSnackBar(result['error'] ?? 'Failed to update follow');
    }
  }

  Future<void> _refreshPostDetail() async {
    try {
      final result = await ApiService.getIngredientPost(widget.post.id);
      if (result['success'] == true && mounted) {
        final fresh = IngredientPost.fromJson(result['data']);
        setState(() {
          isLiked = fresh.isLiked;
          likeCount = fresh.likes;
        });
      }
    } catch (e) {
      debugPrint('Refresh detail error: $e');
    }
  }

  // ==================== Media ====================

  void _buildMediaItems() {
    _mediaItems.clear();

    for (final photoUrl in widget.post.photoUrls) {
      if (photoUrl.isNotEmpty) {
        _mediaItems.add(MediaItem(
          isVideo: false,
          url: ApiService.resolveImageUrl(photoUrl),
        ));
      }
    }

    if (widget.post.videoUrl != null && widget.post.videoUrl!.isNotEmpty) {
      _mediaItems.add(MediaItem(
        isVideo: true,
        url: ApiService.resolveImageUrl(widget.post.videoUrl),
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
        builder: (context) => IngredientFullscreenScreen(
          items: _mediaItems
              .map((e) => IngredientFullscreenItem(isVideo: e.isVideo, url: e.url))
              .toList(),
          startIndex: startIndex,
        ),
      ),
    );
  }

  // ==================== Comments data ====================

  Future<void> _fetchComments() async {
    try {
      final result = await ApiService.getIngredientComments(widget.post.id);
      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        if (!mounted) return;
        setState(() {
          _comments = data
              .map((json) => IngredientComment.fromJson(
                  json is Map ? Map<String, dynamic>.from(json) : {}))
              .toList();
          _commentCount = _comments.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
  }

  // ==================== Like ====================

  void _handleLike() async {
    if (ApiService.authToken == null) {
      _showSnackBar('Please login to like');
      return;
    }

    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      final result = await ApiService.toggleLikeIngredientPost(widget.post.id);
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        if (mounted) {
          setState(() {
            isLiked = data['liked'] == true;
            likeCount = data['likes_count'] ?? likeCount;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
          likeCount += isLiked ? 1 : -1;
        });
        _showSnackBar('Failed to update like');
      }
    }
  }

  void _openAuthorProfile() {
    if (_isOwner) return;
    final uid = widget.post.authorUserId;
    if (uid.isEmpty) {
      _showSnackBar('User ID not available');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfileScreen(userId: uid)),
    );
  }

  // ==================== Add comment ====================

  void _showCommentDialog() {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: const Color(0xFFFFF9E6),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A96E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Add Comment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: commentController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Write a comment...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        final text = commentController.text.trim();
                        if (text.isEmpty) return;

                        try {
                          final result = await ApiService.addIngredientComment(
                            postId: widget.post.id,
                            text: text,
                          );

                          if (!mounted) return;

                          if (result['success'] == true) {
                            Navigator.pop(bottomSheetContext);
                            await _fetchComments();
                            if (!mounted) return;
                            _showSnackBar('Comment added');
                          } else {
                            _showSnackBar('Failed to add comment');
                          }
                        } catch (e) {
                          _showSnackBar('Error adding comment');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB347),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== Comments list ====================

  void _showCommentsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: const Color(0xFFFFF9E6),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A96E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          Text(
                            'Comments ($_commentCount)',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6B4C2A),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(bottomSheetContext),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 18, color: Color(0xFF6B4C2A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _comments.isEmpty
                          ? Center(
                              child: Text(
                                'No comments yet',
                                style: GoogleFonts.poppins(
                                    color: const Color(0xFFC9A96E)),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                return _buildCommentItem(
                                  _comments[index],
                                  bottomSheetContext,
                                  setModalState,
                                  avatarRadius: 20,
                                  nameFontSize: 14,
                                  contentFontSize: 13,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Shared comment row used by the bottom sheet and the inline preview.
  Widget _buildCommentItem(
    IngredientComment comment,
    BuildContext bottomSheetContext,
    StateSetter setModalState, {
    required double avatarRadius,
    required double nameFontSize,
    required double contentFontSize,
    bool showDelete = true,
  }) {
    final isMine = _isMyComment(comment);
    final isAuthor = _isPostAuthorComment(comment);
    final avatarUrl = ApiService.resolveImageUrl(comment.userAvatar);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      fontWeight: FontWeight.bold,
                      fontSize: avatarRadius * 0.75,
                    ),
                  )
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
                      AuthorBadge(fontSize: nameFontSize - 5),
                    ],
                    if (isMine && showDelete) ...[
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
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: GoogleFonts.poppins(
                    fontSize: contentFontSize,
                    color: const Color(0xFF6B4C2A).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteComment(
    IngredientComment comment,
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
          style:
              GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B4C2A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
            ),
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

    final result = await ApiService.deleteIngredientComment(comment.id);
    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pop(bottomSheetContext);
      await _fetchComments();
      if (!mounted) return;
      _showSnackBar('Comment deleted');
    } else {
      _showSnackBar(result['error'] ?? 'Failed to delete comment');
    }
  }

  // ==================== Post actions ====================

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddIngredientPostScreen(editPostId: widget.post.id),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _refreshPostDetail();
      if (!mounted) return;
      _showSnackBar('Post updated');
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Post?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(
          'This action cannot be undone. Are you sure?',
          style:
              GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B4C2A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
            ),
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

    final result = await ApiService.deleteIngredientPost(widget.post.id);
    if (!mounted) return;

    if (result['success'] == true) {
      _showSnackBar('Post deleted');
      if (mounted) Navigator.pop(context, true);
    } else {
      _showSnackBar(result['error'] ?? 'Failed to delete');
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
      postType: 'ingredient',
      postId: widget.post.id,
      reason: reason,
      note: note,
    );

    if (!mounted) return;

    _showSnackBar(
      result['success'] == true
          ? 'Report submitted. Our team will review it shortly.'
          : (result['error'] ?? 'Failed to submit report'),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFFFB347)),
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

    final video = _videoController!;

    return Center(
      child: AspectRatio(
        aspectRatio: video.value.aspectRatio,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => _showFullscreenMedia(_currentMediaIndex),
          onTap: () async {
            if (video.value.isPlaying) {
              await video.pause();
            } else {
              if (video.value.position >= video.value.duration) {
                await video.seekTo(Duration.zero);
              }
              await video.play();
            }
            if (mounted) setState(() {});
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(video),
              if (!video.value.isPlaying)
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

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAuthorRow(),
            if (_mediaItems.isNotEmpty) _buildMediaFrame(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.post.content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.6,
                      color: const Color(0xFF6B4C2A).withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (widget.post.tags.isNotEmpty) _buildTags(),
                  const SizedBox(height: 24),
                  _buildCommentEntry(),
                  const SizedBox(height: 24),
                  _buildCommentsHeader(),
                  const SizedBox(height: 12),
                  ..._comments.take(3).map(
                        (comment) => _buildCommentItem(
                          comment,
                          Navigator.of(context).context,
                          (fn) {},
                          avatarRadius: 18,
                          nameFontSize: 13,
                          contentFontSize: 12,
                          showDelete: false,
                        ),
                      ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ApiService.authToken != null
            ? _handleLike
            : () => _showSnackBar('Please login to like'),
        backgroundColor: isLiked ? Colors.red : Colors.grey.shade300,
        child: Icon(
          isLiked ? Icons.favorite : Icons.favorite_border,
          color: Colors.white,
          size: 28,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.post.title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B4C2A),
        ),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF6B4C2A)),
        onPressed: () => Navigator.pop(context),
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
              items.add(_menuItem(
                  'edit', Icons.edit_outlined, 'Edit', const Color(0xFF6B4C2A)));
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

  Widget _buildAuthorRow() {
    final avatarUrl = ApiService.resolveImageUrl(widget.post.authorAvatar);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isOwner ? null : _openAuthorProfile,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFB347),
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          widget.post.authorName.isNotEmpty
                              ? widget.post.authorName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    Text(
                      widget.post.isEdited
                          ? 'Edited by ${widget.post.editedDateText}'
                          : 'Posted by ${widget.post.postedDateText}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
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
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.post.tags
          .map((tag) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFFFFD966), width: 0.5),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xFFC9A96E)),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCommentEntry() {
    return GestureDetector(
      onTap: ApiService.authToken != null
          ? _showCommentDialog
          : () => _showSnackBar('Please login to comment'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFFB347),
              child: Icon(Icons.person, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              ApiService.authToken != null
                  ? 'Add a comment...'
                  : 'Login to comment',
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

  Widget _buildCommentsHeader() {
    return Row(
      children: [
        const Icon(Icons.chat_bubble_outline,
            size: 20, color: Color(0xFFC9A96E)),
        const SizedBox(width: 8),
        Text(
          'Comments ($_commentCount)',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _comments.isNotEmpty ? _showCommentsList : null,
          child: Text(
            _comments.isNotEmpty ? 'View all >' : 'No comments yet',
            style: GoogleFonts.poppins(
              color: _comments.isNotEmpty
                  ? const Color(0xFFFFB347)
                  : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small "Author" pill shown next to a comment author who owns the post.
class _AuthorBadge extends StatelessWidget {
  final double fontSize;

  const _AuthorBadge({this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD966), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium,
              size: 10, color: Color(0xFFFFB347)),
          const SizedBox(width: 3),
          Text(
            'Author',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC9A96E),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}