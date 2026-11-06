// screens/cooking/ingredients_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/recipe.dart';

class IngredientsPage extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onContinue;

  const IngredientsPage({
    super.key,
    required this.recipe,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Ingredients',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Prepare these ingredients before you start',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFFC9A96E),
                ),
              ),
              const SizedBox(height: 24),

              // Ingredients List
              Expanded(
                child: ListView.builder(
                  itemCount: recipe.ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = recipe.ingredients[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          // Checkbox icon
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD966).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 16,
                              color: Color(0xFFFFB347),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Ingredient name (left aligned)
                          Expanded(
                            flex: 2,
                            child: Text(
                              ingredient.name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Amount (right aligned)
                          if (ingredient.amount.isNotEmpty)
                            SizedBox(
                              width: 80,
                              child: Text(
                                ingredient.amount,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: const Color(0xFFC9A96E),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Start Cooking Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD966),
                    foregroundColor: const Color(0xFF6B4C2A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Start Cooking',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}