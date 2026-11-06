// widgets/author_badge.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small "Author" pill shown next to the author's name in comments
/// and community dish cards.
class AuthorBadge extends StatelessWidget {
  /// Font size of the "Author" label.
  /// Adjust per context (e.g. smaller for compact cards).
  final double fontSize;

  const AuthorBadge({super.key, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC), // light red background
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Author',
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE53935), // red text
          height: 1.2,
        ),
      ),
    );
  }
}