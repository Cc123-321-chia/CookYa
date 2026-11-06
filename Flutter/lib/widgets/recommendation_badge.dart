// widgets/recommendation_badge.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gold badge shown on card corners when a post is endorsed by
/// an Official or an Expert/Chef.
enum RecommendationType { official, chef }

class RecommendationBadge extends StatelessWidget {
  final RecommendationType type;
  final double fontSize;

  const RecommendationBadge({
    super.key,
    required this.type,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final label = type == RecommendationType.official
        ? 'Official Pick'
        : 'Chef Pick';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 12, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF59E0B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to map a backend recommendation string to the enum.
  static RecommendationType? parse(String? value) {
    switch (value) {
      case 'official':
        return RecommendationType.official;
      case 'chef':
      case 'expert':
        return RecommendationType.chef;
      default:
        return null;
    }
  }
}