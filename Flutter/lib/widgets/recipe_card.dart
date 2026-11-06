// widgets/recipe_card.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import 'recommendation_badge.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    List<String> displayTags = [];
    String? remainingCount;
    if (recipe.tags.length <= 3) {
      displayTags = recipe.tags;
    } else {
      displayTags = recipe.tags.sublist(0, 3);
      remainingCount = '+${recipe.tags.length - 3}';
    }

    final recommendation = RecommendationBadge.parse(recipe.recommendation);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                height: 130,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(),
                    if (recommendation != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: RecommendationBadge(type: recommendation),
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
                      recipe.title,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF6B4C2A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.authorName,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayTags.isNotEmpty || remainingCount != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          ...displayTags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF5E6),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFFD966),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(0xFFC9A96E),
                                  ),
                                ),
                              )),
                          if (remainingCount != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0B5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                remainingCount,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
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
                        Icon(Icons.favorite,
                            size: 14, color: Colors.red.shade300),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.likes}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.comment,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text(
                          '${recipe.comments}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
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
    if (recipe.imageUrl == null || recipe.imageUrl!.isEmpty) {
      return Container(
        color: const Color(0xFFFFF0B5),
        child: const Icon(Icons.food_bank, color: Color(0xFFFFD966), size: 40),
      );
    }

    if (recipe.imageUrl!.startsWith('assets')) {
      return Image.asset(
        recipe.imageUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFFFF0B5),
            child: const Icon(Icons.broken_image,
                color: Color(0xFFFFD966), size: 40),
          );
        },
      );
    }

    final fixedUrl = ApiService.resolveImageUrl(recipe.imageUrl);
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
        debugPrint('RecipeCard image error: $url → $error');
        return Container(
          color: const Color(0xFFFFF0B5),
          child:
              const Icon(Icons.food_bank, color: Color(0xFFFFD966), size: 40),
        );
      },
    );
  }
}