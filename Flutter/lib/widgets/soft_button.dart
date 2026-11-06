// lib/widgets/soft_button.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A borderless button with a white background and colored text.
/// No outline, no elevation, no shadow — pure white pill button.
class SoftButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color textColor;
  final IconData? icon;
  final bool fullWidth;
  final EdgeInsets padding;
  final double fontSize;

  const SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor = const Color(0xFFFFB347),
    this.icon,
    this.fullWidth = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: onPressed == null ? Colors.grey : textColor),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: onPressed == null ? Colors.grey : textColor,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}