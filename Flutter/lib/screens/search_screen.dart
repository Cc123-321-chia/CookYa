// screens/search_screen.dart (for completeness)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Search Recipes',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 80, color: Color(0xFFFFD966)),
            const SizedBox(height: 16),
            Text(
              'Search your favorite recipes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}