// widgets/post_action_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/recipe.dart';
import '../screens/recipes/cooking/cooking_tutorial_screen.dart';
import '../screens/recipes/add_dish_post_screen.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PostActionBar extends StatefulWidget {
  final String recipeId;
  final Recipe recipe;
  final VoidCallback? onCommentTap;
  final VoidCallback? onLikeUpdated;
  final VoidCallback? onDishUploaded;
  const PostActionBar({
    super.key,
    required this.recipeId,
    required this.recipe,
    this.onCommentTap,
    this.onLikeUpdated,
    this.onDishUploaded,
  });

  @override
  State<PostActionBar> createState() => _PostActionBarState();
}

class _PostActionBarState extends State<PostActionBar> {
  bool isLiked = false;
  int likeCount = 0;
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    try {
      final token = ApiService.authToken;
      if (token == null) {
        setState(() {
          likeCount = widget.recipe.likes;
          commentCount = widget.recipe.comments;
          isLiked = false;
        });
        return;
      }

      setState(() {
        likeCount = widget.recipe.likes;
        commentCount = widget.recipe.comments;
      });

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/recipes/${widget.recipeId}/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            likeCount = data['likes_count'] ?? widget.recipe.likes;
            commentCount = data['comments_count'] ?? widget.recipe.comments;
            isLiked = data['is_liked'] == true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          likeCount = widget.recipe.likes;
          commentCount = widget.recipe.comments;
        });
      }
    }
  }

  Future<void> _handleLike() async {
    if (ApiService.authToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to like'),
            backgroundColor: Color(0xFFFFB347),
          ),
        );
      }
      return;
    }

    // Optimistic update
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      final result = await ApiService.toggleLikeRecipe(widget.recipeId);
      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            isLiked = result['liked'];
            likeCount = result['likes_count'];
          });
          if (widget.onLikeUpdated != null) {
            widget.onLikeUpdated!();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLiked = !isLiked;
            likeCount += isLiked ? 1 : -1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update like'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLiked = !isLiked;
          likeCount += isLiked ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 上传 dish → 打开 AddDishPostScreen，并传 recipeId / title
  Future<void> _handleUploadDish() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDishPostScreen(
          recipeId: widget.recipeId,
          recipeTitle: widget.recipe.title,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your dish was shared!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onDishUploaded?.call();
    }
  }

  void refreshComments() {
    _loadLikeStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            _buildActionButton(
              icon: isLiked ? Icons.favorite : Icons.favorite_border,
              label: '$likeCount',
              color: isLiked ? Colors.red : Colors.grey.shade600,
              onTap: _handleLike,
            ),
            const SizedBox(width: 24),
            _buildActionButton(
              icon: Icons.comment_outlined,
              label: '$commentCount',
              color: Colors.grey.shade600,
              onTap: () {
                if (widget.onCommentTap != null) {
                  widget.onCommentTap!();
                }
              },
            ),
            const SizedBox(width: 24),
            _buildActionButton(
              icon: Icons.cloud_upload_outlined,
              label: 'Upload',
              subtitle: 'Your Dish',
              color: const Color(0xFFFFB347),
              onTap: _handleUploadDish,
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CookingTutorialScreen(recipe: widget.recipe),
                  ),
                );
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD966),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_filled,
                      color: Color(0xFF6B4C2A),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cook Now',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
}