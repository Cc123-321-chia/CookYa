// widgets/duration_slider.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DurationSlider extends StatefulWidget {
  final int durationMinutes;
  final ValueChanged<int> onChanged;

  const DurationSlider({
    super.key,
    required this.durationMinutes,
    required this.onChanged,
  });

  @override
  State<DurationSlider> createState() => _DurationSliderState();
}

class _DurationSliderState extends State<DurationSlider> {
  double _value = 0;
  bool _isNotSet = true;

  @override
  void initState() {
    super.initState();
    _value = _minutesToSliderValue(widget.durationMinutes);
    _isNotSet = widget.durationMinutes == 0;
  }

  @override
  void didUpdateWidget(DurationSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationMinutes != widget.durationMinutes) {
      setState(() {
        _value = _minutesToSliderValue(widget.durationMinutes);
        _isNotSet = widget.durationMinutes == 0;
      });
    }
  }

  double _minutesToSliderValue(int minutes) {
    if (minutes <= 60) return minutes / 60;
    if (minutes <= 300) return 1 + (minutes - 60) / 240;
    return 2.0;
  }

  int _sliderValueToMinutes(double value) {
    if (value <= 1.0) return (value * 60).round();
    if (value <= 2.0) return 60 + ((value - 1) * 240).round();
    return 300;
  }

  String _formatDuration(int minutes) {
    if (minutes >= 300) return '5+ hours';
    if (minutes >= 60) {
      double hours = minutes / 60.0;
      return '${hours.toStringAsFixed(1)} hours';
    }
    return '$minutes min${minutes == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,  // 🔥 居中
      children: [
        if (_isNotSet) ...[
          const SizedBox(height: 4),
          Text(
            'Slide to set duration',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ] else ...[
          Text(
            _formatDuration(_sliderValueToMinutes(_value)),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        ],
        const SizedBox(height: 4),
        // 🔥 用 Container 包裹 Slider，限制宽度
        Container(
          width: double.infinity,  // 撑满父容器
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            value: _value,
            min: 0,
            max: 2.0,
            divisions: 200,
            activeColor: const Color(0xFFFFB347),
            inactiveColor: const Color(0xFFFFD966),
            onChanged: (double newValue) {
              setState(() {
                _value = newValue;
                final minutes = _sliderValueToMinutes(newValue);
                _isNotSet = minutes == 0;
                widget.onChanged(minutes);
              });
            },
          ),
        ),
      ],
    );
  }
}