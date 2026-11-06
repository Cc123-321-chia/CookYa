// widgets/user_badge.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Badge types for user identity/role chips.
enum UserBadgeType { author, mentor, expert, official, culinaryInstructor }

/// Small pill badge used next to a user's name.
/// Colours:
///   - author              -> red
///   - mentor              -> purple
///   - expert              -> blue
///   - official            -> deep blue / brand color
///   - culinaryInstructor  -> green
class UserBadge extends StatelessWidget {
  final UserBadgeType type;
  final double fontSize;

  const UserBadge({
    super.key,
    required this.type,
    this.fontSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color textColor;
    late final Color bgColor;

    switch (type) {
      case UserBadgeType.author:
        label = 'Author';
        textColor = const Color(0xFFE53935);
        bgColor = const Color(0xFFFDECEC);
        break;
      case UserBadgeType.mentor:
        label = 'Mentor';
        textColor = const Color(0xFF8B5CF6);
        bgColor = const Color(0xFFF3EEFF);
        break;
      case UserBadgeType.expert:
        label = 'Expert';
        textColor = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFEAF2FE);
        break;
      case UserBadgeType.official:
        label = 'Official';
        textColor = const Color(0xFF1E40AF);
        bgColor = const Color(0xFFDBEAFE);
        break;
      case UserBadgeType.culinaryInstructor:
        label = 'Culinary Instructor';
        textColor = const Color(0xFF00B894);
        bgColor = const Color(0xFFE6F9F3);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.2,
        ),
      ),
    );
  }
}