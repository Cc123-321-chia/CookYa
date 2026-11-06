// widgets/star_rating.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StarRating extends StatefulWidget {
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final double starSize;
  final bool showLabel;

  const StarRating({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.starSize = 30,
    this.showLabel = true,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  int _rating = 0;
  bool _isNotSet = true;

  @override
  void initState() {
    super.initState();
    _rating = widget.rating;
    _isNotSet = widget.rating == 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isNotSet) ...[
          const SizedBox(height: 8),
          Text(
            'Tap stars to set difficulty',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ] else ...[
          if (widget.showLabel)
            Text(
              _getDifficultyLabel(_rating),
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_rating == starIndex) {
                    _rating = 0;
                    _isNotSet = true;
                  } else {
                    _rating = starIndex;
                    _isNotSet = false;
                  }
                  widget.onRatingChanged(_rating);
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  starIndex <= _rating ? Icons.star : Icons.star_border,
                  color: starIndex <= _rating ? const Color(0xFFFFB347) : Colors.grey.shade300,
                  size: widget.starSize,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  String _getDifficultyLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Very Easy';
      case 2:
        return 'Easy';
      case 3:
        return 'Medium';
      case 4:
        return 'Hard';
      case 5:
        return 'Very Hard';
      default:
        return 'Not set';
    }
  }
}