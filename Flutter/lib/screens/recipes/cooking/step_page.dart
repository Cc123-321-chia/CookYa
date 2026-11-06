// screens/cooking/step_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/timer_button.dart';
import '../../../models/recipe.dart';

/// A single cooking step page.
///
/// Supports optional translated content (instruction + note) and
/// auto-detects a timer duration from the step text (explicit only).
class StepPage extends StatelessWidget {
  final int stepNumber;
  final StepItem stepItem;
  final int totalSteps;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final bool isLastStep;

  final String? translatedText;
  final String? translatedNote;
  final bool showOriginal;
  final String selectedLanguage;

  const StepPage({
    super.key,
    required this.stepNumber,
    required this.stepItem,
    required this.totalSteps,
    required this.onBack,
    required this.onContinue,
    required this.isLastStep,
    this.translatedText,
    this.translatedNote,
    this.showOriginal = false,
    this.selectedLanguage = 'English',
  });

  // ==================== Time detection ====================

  /// Returns a suggested duration in minutes if the step explicitly mentions
  /// a time, else `null`. Keyword-only steps (e.g. "boil until tender") get
  /// NO timer — the user can still open one manually if they want.
  int? _detectMinutes() {
    final text = '${stepItem.instruction} ${stepItem.note ?? ''}'.toLowerCase();

    // Range with unit: "3-5 min", "3 to 5 minutes", "1-2 hours".
    final rangeMatch = RegExp(
      r'(\d+)\s*(?:-|to|~|–|—)\s*(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m)\b',
    ).firstMatch(text);
    if (rangeMatch != null) {
      final low = int.parse(rangeMatch.group(1)!);
      final unit = rangeMatch.group(3)!;
      return unit.startsWith('h') ? low * 60 : low;
    }

    // Single number with unit: "90 minutes", "1 hour".
    final singleMatch = RegExp(
      r'(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m)\b',
    ).firstMatch(text);
    if (singleMatch != null) {
      final n = int.parse(singleMatch.group(1)!);
      final unit = singleMatch.group(2)!;
      return unit.startsWith('h') ? n * 60 : n;
    }

    final zhRange = RegExp(r'(\d+)\s*[-到至~]\s*(\d+)\s*分钟').firstMatch(text);
    if (zhRange != null) return int.parse(zhRange.group(1)!);

    final zhMin = RegExp(r'(\d+)\s*分钟').firstMatch(text);
    if (zhMin != null) return int.parse(zhMin.group(1)!);

    final zhHour = RegExp(r'(\d+)\s*(小时|钟头)').firstMatch(text);
    if (zhHour != null) return int.parse(zhHour.group(1)!) * 60;

    // No explicit time found — do NOT show a timer.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final detectedMinutes = _detectMinutes();
    final hasTimer = detectedMinutes != null;

    final displayText = translatedText ?? stepItem.instruction;
    final displayNote = translatedNote ?? stepItem.note;

    return Container(
      color: const Color(0xFFFFF9E6),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Step number badge.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD966),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD966).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Step $stepNumber of $totalSteps',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFFC9A96E),
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Instruction card.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      displayText,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        height: 1.5,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                    if (showOriginal && translatedText != null) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Original: ${stepItem.instruction}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Language: $selectedLanguage',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // Optional cooking tip.
              if (stepItem.note != null && stepItem.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD966)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline,
                              size: 20, color: Color(0xFFFFB347)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cooking Tip',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFFFB347),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayNote ?? stepItem.note!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: const Color(0xFF6B4C2A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (showOriginal && translatedNote != null) ...[
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'Original: ${stepItem.note}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Timer (only when the step explicitly mentions a duration).
              if (hasTimer) ...[
                const SizedBox(height: 20),
                TimerButton(
                  initialMinutes: detectedMinutes,
                  compact: true,
                ),
              ],

              const SizedBox(height: 24),

              // Bottom buttons.
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBack,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFFFD966), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFC9A96E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD966),
                          foregroundColor: const Color(0xFF6B4C2A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          isLastStep ? 'Complete' : 'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}