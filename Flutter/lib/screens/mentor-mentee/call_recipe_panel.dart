// lib/screens/mentor-mentee/call_recipe_panel.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/timer_button.dart';

/// Bottom sheet panel shown during a video call that walks through a
/// recipe (ingredients -> steps) with optional timers.
class CallRecipePanel extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final int currentStep; // 0 = ingredients, 1..n = steps
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onClose;

  const CallRecipePanel({
    super.key,
    required this.recipe,
    required this.currentStep,
    required this.loading,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final rawSteps = recipe['steps'];
    final steps = rawSteps is List ? rawSteps : const [];
    final totalSteps = steps.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle + close button.
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFFFFB347),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Title + progress.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        recipe['title']?.toString() ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6B4C2A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      currentStep == 0
                          ? 'Ingredients'
                          : 'Step $currentStep of $totalSteps',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFFC9A96E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: loading
                      ? 0
                      : (currentStep + 1) / (totalSteps + 1),
                  backgroundColor: const Color(0xFFFFF3E0),
                  color: const Color(0xFFFFB347),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),

          // Content.
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFB347),
                    ),
                  )
                : currentStep == 0
                    ? _buildIngredients()
                    : _buildStep(_stepDataAt(steps, currentStep - 1)),
          ),

          // Navigation buttons.
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrev,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFC9A96E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Previous',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFC9A96E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading ? null : onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB347),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      currentStep >= totalSteps ? 'Complete' : 'Next',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Step helpers ====================

  /// Steps in [recipe] may be a plain String or a Map with
  /// `instruction` / `note`. Normalize.
  _StepData _stepDataAt(List<dynamic> steps, int index) {
    if (index < 0 || index >= steps.length) {
      return const _StepData(instruction: '', note: null);
    }
    final raw = steps[index];
    if (raw is Map) {
      return _StepData(
        instruction: raw['instruction']?.toString() ?? '',
        note: raw['note']?.toString(),
      );
    }
    return _StepData(instruction: raw.toString(), note: null);
  }

  // ==================== Ingredients view ====================

  Widget _buildIngredients() {
    final raw = recipe['ingredients'];
    final list = raw is List ? raw : const [];
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No ingredients',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        String name = '';
        String amount = '';
        if (item is Map) {
          name = item['name']?.toString() ?? '';
          amount = item['amount']?.toString() ?? '';
        } else {
          name = item.toString();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD966).withAlpha(76),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check,
                  size: 14,
                  color: Color(0xFFFFB347),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
              ),
              if (amount.isNotEmpty)
                Text(
                  amount,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==================== Step view ====================

  Widget _buildStep(_StepData step) {
    final minutes = _detectMinutes(step.instruction, step.note);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFFB347),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$currentStep',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.instruction,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.4,
              color: const Color(0xFF6B4C2A),
            ),
            textAlign: TextAlign.center,
          ),
          if (step.note != null && step.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD966)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: Color(0xFFFFB347),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.note!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (minutes != null) ...[
            const SizedBox(height: 16),
            TimerButton(initialMinutes: minutes, compact: true),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== Time detection ====================

  /// Returns a suggested timer duration in minutes only if the step
  /// explicitly mentions a time. Keyword-only steps get no timer.
  int? _detectMinutes(String instruction, String? note) {
    final text = '$instruction ${note ?? ''}'.toLowerCase();

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

    // Chinese range: "3-5分钟".
    final zhRange = RegExp(r'(\d+)\s*[-到至~]\s*(\d+)\s*分钟').firstMatch(text);
    if (zhRange != null) return int.parse(zhRange.group(1)!);

    // Chinese single minutes: "5分钟".
    final zhMin = RegExp(r'(\d+)\s*分钟').firstMatch(text);
    if (zhMin != null) return int.parse(zhMin.group(1)!);

    // Chinese hours: "1小时" / "2钟头".
    final zhHour = RegExp(r'(\d+)\s*(小时|钟头)').firstMatch(text);
    if (zhHour != null) return int.parse(zhHour.group(1)!) * 60;

    // No explicit time found — do NOT show a timer.
    return null;
  }
}

/// Simple value type for a step instruction + optional note.
class _StepData {
  final String instruction;
  final String? note;
  const _StepData({required this.instruction, this.note});
}