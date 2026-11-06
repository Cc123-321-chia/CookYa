import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CuisineAutocomplete extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const CuisineAutocomplete({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const List<String> _cuisines = [
    'Japanese', 'Italian', 'Korean', 'French',
    'Chinese', 'Thai', 'Indian', 'American',
    'Mexican', 'Vietnamese', 'Greek', 'Spanish'
  ];

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _cuisines.where((cuisine) => cuisine
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        onChanged(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          onChanged: (newValue) => onChanged(newValue),
          decoration: InputDecoration(
            hintText: 'Select or type cuisine (e.g., Japanese)',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        );
      },
    );
  }
}