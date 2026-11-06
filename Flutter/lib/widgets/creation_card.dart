// widgets/creation_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'author_badge.dart';
import 'recommendation_badge.dart';

class CreationCard extends StatefulWidget {
  final String homeworkId;
  final String userName;
  final String userAvatar;
  final String imageUrl;
  final String comment;
  final String rating; // 'good' | 'ok' | 'bad'
  final bool isAuthor;
  final String? recommendation; // 'chef' | 'official' | null
  final int initialLikes;
  final bool initialIsLiked;

  const CreationCard({
    super.key,
    required this.homeworkId,
    required this.userName,
    required this.userAvatar,
    required this.imageUrl,
    required this.comment,
    this.rating = 'good',
    this.isAuthor = false,
    this.recommendation,
    this.initialLikes = 0,
    this.initialIsLiked = false,
  });

  @override
  State<CreationCard> createState() => _CreationCardState();
}

class _CreationCardState extends State<CreationCard> {
  late int _likes;
  late bool _isLiked;
  bool _isLikeLoading = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
    _isLiked = widget.initialIsLiked;
  }

  Future<void> _toggleLike() async {
    if (ApiService.authToken == null) {
      _showSnackBar('Please login to like');
      return;
    }
    if (_isLikeLoading) return;

    setState(() {
      _isLikeLoading = true;
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });

    try {
      final token = ApiService.authToken;
      final url = Uri.parse(
          '${ApiService.baseUrl}/recipes/homeworks/${widget.homeworkId}/like/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Token $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isLiked = data['liked'] == true;
          _likes = (data['likes_count'] is int)
              ? data['likes_count']
              : int.tryParse('${data['likes_count']}') ?? _likes;
          _isLikeLoading = false;
        });
      } else {
        setState(() {
          _isLiked = !_isLiked;
          _likes += _isLiked ? 1 : -1;
          _isLikeLoading = false;
        });
        _showSnackBar('Failed to update like');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLiked = !_isLiked;
        _likes += _isLiked ? 1 : -1;
        _isLikeLoading = false;
      });
      _showSnackBar('Error updating like');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFFB347),
      ),
    );
  }

  Widget _getRatingWidget() {
    IconData icon;
    Color color;
    String label;

    switch (widget.rating) {
      case 'good':
        icon = Icons.sentiment_very_satisfied;
        color = const Color(0xFF4CAF50);
        label = 'Good';
        break;
      case 'ok':
        icon = Icons.sentiment_neutral;
        color = const Color(0xFFFF9800);
        label = 'OK';
        break;
      case 'bad':
        icon = Icons.sentiment_very_dissatisfied;
        color = const Color(0xFFF44336);
        label = 'Bad';
        break;
      default:
        icon = Icons.sentiment_satisfied_alt;
        color = const Color(0xFFC9A96E);
        label = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = RecommendationBadge.parse(widget.recommendation);

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
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFFD966),
            backgroundImage:
                widget.userAvatar.isNotEmpty ? NetworkImage(widget.userAvatar) : null,
            child: widget.userAvatar.isEmpty
                ? const Icon(Icons.person, size: 20, color: Color(0xFF6B4C2A))
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
                        widget.userName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: const Color(0xFF6B4C2A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isAuthor) ...[
                      const SizedBox(width: 6),
                      const AuthorBadge(),
                    ],
                    const Spacer(),
                    _getRatingWidget(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.comment,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          widget.imageUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 150,
                            color: const Color(0xFFFFF0B5),
                            child: const Icon(Icons.restaurant,
                                size: 40, color: Color(0xFFFFD966)),
                          ),
                        ),
                        if (recommendation != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: RecommendationBadge(
                              type: recommendation,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: _isLiked
                                ? Colors.red.shade400
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_likes',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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