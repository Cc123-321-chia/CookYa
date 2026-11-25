import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinCodeField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const PinCodeField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<PinCodeField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _currentValue =>
      _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    value = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (value.length > 1 && index == 0) {
      final chars = value.split('');
      for (int i = 0; i < widget.length && i < chars.length; i++) {
        _controllers[i].text = chars[i];
      }
      final next = chars.length >= widget.length ? widget.length - 1 : chars.length;
      _focusNodes[next].requestFocus();
      setState(() {});
      _checkComplete();
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    widget.onChanged?.call(_currentValue);
    _checkComplete();
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  void _checkComplete() {
    if (_currentValue.length == widget.length &&
        !_currentValue.contains(RegExp(r'[^0-9]'))) {
      widget.onCompleted(_currentValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        final filled = _controllers[i].text.isNotEmpty;
        final focused = _focusNodes[i].hasFocus;
        return Container(
          width: 48,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: KeyboardListener(
            focusNode: FocusNode(), 
            onKeyEvent: (e) => _onKeyDown(i, e),
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              autofocus: i == 0,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: i == 0 ? widget.length : 1, 
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: filled ? Colors.blue : Colors.grey.shade300,
                    width: filled ? 2 : 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2.5),
                ),
              ),
              onChanged: (v) => _onDigitChanged(i, v),
            ),
          ),
        );
      }),
    );
  }
}