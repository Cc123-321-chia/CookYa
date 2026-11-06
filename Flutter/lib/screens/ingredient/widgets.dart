// screens/ingredient/widgets.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models.dart';
import '../../services/api_service.dart';
import '../../widgets/recommendation_badge.dart';

class IngredientCard extends StatelessWidget {
  final IngredientPost post;
  final VoidCallback onTap;

  const IngredientCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    List<String> displayTags = [];
    String? remainingCount;
    if (post.tags.length <= 3) {
      displayTags = post.tags;
    } else {
      displayTags = post.tags.sublist(0, 3);
      remainingCount = '+${post.tags.length - 3}';
    }

    final recommendation = RecommendationBadge.parse(post.recommendation);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Image with badge =====
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(),
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

            // ===== Content =====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
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
                      post.authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayTags.isNotEmpty || remainingCount != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...displayTags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF5E6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFFD966),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: const Color(0xFFC9A96E),
                                  ),
                                ),
                              )),
                          if (remainingCount != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0B5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                remainingCount,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFC9A96E),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.favorite_border,
                            size: 13, color: Color(0xFFC9A96E)),
                        const SizedBox(width: 3),
                        Text(
                          '${post.likes}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFFC9A96E),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.chat_bubble_outline,
                            size: 13, color: Color(0xFFC9A96E)),
                        const SizedBox(width: 3),
                        Text(
                          '${post.comments}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFFC9A96E),
                          ),
                        ),
                      ],
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

  Widget _buildImage() {
    final coverUrl = post.coverPhotoUrl;
    if (coverUrl.isEmpty) {
      return Container(
        color: const Color(0xFFFFF0B5),
        child: const Icon(Icons.image, color: Color(0xFFFFD966), size: 40),
      );
    }

    final fixedUrl = ApiService.resolveImageUrl(coverUrl);
    return CachedNetworkImage(
      imageUrl: fixedUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFFFFF0B5),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFFB347),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        return Container(
          color: const Color(0xFFFFF0B5),
          child: const Icon(Icons.image, color: Color(0xFFFFD966), size: 40),
        );
      },
    );
  }
}

// Keep the old CommentCard widget unchanged below (if used elsewhere).
class CommentCard extends StatelessWidget {
  final String userName;
  final String comment;
  final String? imageUrl;
  final DateTime createdAt;

  const CommentCard({
    super.key,
    required this.userName,
    required this.comment,
    this.imageUrl,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final fixedAvatar =
        imageUrl != null ? ApiService.resolveImageUrl(imageUrl) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFB347),
            backgroundImage: fixedAvatar.isNotEmpty
                ? CachedNetworkImageProvider(fixedAvatar)
                : null,
            child: fixedAvatar.isEmpty
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
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
}