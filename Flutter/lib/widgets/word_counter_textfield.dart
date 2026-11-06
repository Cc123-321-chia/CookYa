import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WordCounterTextfield extends StatefulWidget {
  final String hintText;
  final int maxWords;
  final ValueChanged<String> onChanged;

  const WordCounterTextfield({
    super.key,
    required this.hintText,
    required this.maxWords,
    required this.onChanged,
  });

  @override
  State<WordCounterTextfield> createState() => _WordCounterTextfieldState();
}

class _WordCounterTextfieldState extends State<WordCounterTextfield> {
  final TextEditingController _controller = TextEditingController();
  int _wordCount = 0;
  bool _isExceeded = false;

  void _updateWordCount(String text) {
    final words = text.trim().isEmpty ? [] : text.trim().split(RegExp(r'\s+'));
    setState(() {
      _wordCount = words.length;
      _isExceeded = _wordCount > widget.maxWords;
    });

    if (!_isExceeded) {
      widget.onChanged(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          onChanged: _updateWordCount,
          maxLines: 4,
          maxLength: widget.maxWords * 6, // Rough estimate for character limit
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isExceeded ? Colors.red : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _isExceeded ? Colors.red : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            counterText: '',
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$_wordCount/${widget.maxWords} words',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _isExceeded ? Colors.red : Colors.grey.shade600,
              fontWeight: _isExceeded ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (_isExceeded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Maximum ${widget.maxWords} words allowed',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }
}