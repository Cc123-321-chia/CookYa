// widgets/timer_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// A circular timer widget for a cooking step.
///
/// Features:
///   - Accepts an optional [initialMinutes] auto-detected from the step text.
///   - User can adjust the duration with +/- buttons or by tapping the number.
///   - Supports minutes and hours (max 24 hours).
///   - Fires a completion dialog when the timer reaches zero.
///   - [compact] mode renders a smaller version for dialogs / bottom sheets.
class TimerButton extends StatefulWidget {
  final int? initialMinutes;
  final bool compact;

  const TimerButton({
    super.key,
    this.initialMinutes,
    this.compact = false,
  });

  @override
  State<TimerButton> createState() => _TimerButtonState();
}

class _TimerButtonState extends State<TimerButton> {
  bool _isRunning = false;
  Timer? _ticker;
  int _remainingSeconds = 0;

  /// Total duration in minutes currently set by the user.
  int _durationMinutes = 1;

  static const int _maxMinutes = 24 * 60; // 24 hours

  @override
  void initState() {
    super.initState();
    _durationMinutes = (widget.initialMinutes ?? 1).clamp(1, _maxMinutes);
    _remainingSeconds = _durationMinutes * 60;
  }

  @override
  void didUpdateWidget(covariant TimerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt new suggested time if the timer is idle.
    if (!_isRunning &&
        widget.initialMinutes != null &&
        widget.initialMinutes != oldWidget.initialMinutes) {
      setState(() {
        _durationMinutes = widget.initialMinutes!.clamp(1, _maxMinutes);
        _remainingSeconds = _durationMinutes * 60;
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ==================== Controls ====================

  void _start() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _remainingSeconds = _durationMinutes * 60;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _ticker?.cancel();
        setState(() {
          _isRunning = false;
          _remainingSeconds = 0;
        });
        _showCompletionDialog();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _cancel() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _durationMinutes * 60;
    });
  }

  void _adjust(int deltaMinutes) {
    if (_isRunning) return;
    final next = (_durationMinutes + deltaMinutes).clamp(1, _maxMinutes);
    if (next == _durationMinutes) return;
    setState(() {
      _durationMinutes = next;
      _remainingSeconds = next * 60;
    });
  }

  // ==================== Display helpers ====================

  String _fmtSeconds(int totalSeconds) {
    if (totalSeconds >= 3600) {
      final h = totalSeconds ~/ 3600;
      final m = (totalSeconds % 3600) ~/ 60;
      final s = totalSeconds % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '$minutes min';
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.timer, size: 50, color: Color(0xFFFFD966)),
        content: Text(
          'Time is up!\nYour ${_fmtMinutes(_durationMinutes)} step is complete.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB347),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustDialog() {
    final controller = TextEditingController(text: '$_durationMinutes');
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Set Timer',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter duration in minutes (max 24 hours).',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  suffixText: 'min',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFFFB347), width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                if (v != null && v > 0 && v <= _maxMinutes) {
                  setState(() {
                    _durationMinutes = v;
                    _remainingSeconds = v * 60;
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Set',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final circleSize = widget.compact ? 110.0 : 160.0;
    final timeFontSize = widget.compact ? 18.0 : 22.0;
    final iconSize = widget.compact ? 22.0 : 28.0;
    final runningFontSize = widget.compact ? 18.0 : 24.0;
    final btnSize = widget.compact ? 30.0 : 36.0;
    final startPaddingH = widget.compact ? 18.0 : 24.0;
    final startFontSize = widget.compact ? 13.0 : 14.0;
    final topSpacing = widget.compact ? 8.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular body
        GestureDetector(
          onTap: _isRunning ? null : _showAdjustDialog,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD966).withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 6,
                ),
              ],
              border: Border.all(
                color: _isRunning
                    ? const Color(0xFFFFB347)
                    : const Color(0xFFFFD966),
                width: 3,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRunning ? Icons.timer : Icons.timer_outlined,
                  size: iconSize,
                  color: const Color(0xFFFFB347),
                ),
                const SizedBox(height: 6),
                if (_isRunning)
                  Text(
                    _fmtSeconds(_remainingSeconds),
                    style: GoogleFonts.poppins(
                      fontSize: runningFontSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B4C2A),
                    ),
                  )
                else ...[
                  Text(
                    _fmtMinutes(_durationMinutes),
                    style: GoogleFonts.poppins(
                      fontSize: timeFontSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        size: 11,
                        color: Color(0xFFC9A96E),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Tap to set',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: const Color(0xFFC9A96E),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(height: topSpacing),

        // Controls
        if (_isRunning)
          TextButton.icon(
            onPressed: _cancel,
            icon: const Icon(Icons.close, size: 18),
            label: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roundButton(
                icon: Icons.remove,
                onTap: () => _adjust(-1),
                size: btnSize,
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _start,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD966),
                  foregroundColor: const Color(0xFF6B4C2A),
                  padding: EdgeInsets.symmetric(
                      horizontal: startPaddingH, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Start',
                  style: GoogleFonts.poppins(
                    fontSize: startFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _roundButton(
                icon: Icons.add,
                onTap: () => _adjust(1),
                size: btnSize,
              ),
            ],
          ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5E6),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFD966), width: 1.5),
        ),
        child: Icon(icon, size: size * 0.55, color: const Color(0xFFC9A96E)),
      ),
    );
  }
}