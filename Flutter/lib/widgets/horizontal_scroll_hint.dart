// lib/widgets/horizontal_scroll_hint.dart
import 'package:flutter/material.dart';

/// Wraps a horizontal scrollable child with a right-arrow indicator
/// that disappears once the user scrolls to the end.
class HorizontalScrollHint extends StatefulWidget {
  final Widget child;
  final double height;
  final EdgeInsets padding;
  final ScrollController? controller;

  const HorizontalScrollHint({
    super.key,
    required this.child,
    required this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.controller,
  });

  @override
  State<HorizontalScrollHint> createState() => _HorizontalScrollHintState();
}

class _HorizontalScrollHintState extends State<HorizontalScrollHint> {
  late ScrollController _controller;
  bool _ownsController = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = ScrollController();
      _ownsController = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateArrowVisibility();
      _controller.addListener(_updateArrowVisibility);
    });
  }

  void _updateArrowVisibility() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canScrollRight = position.pixels < position.maxScrollExtent - 8;
    if (canScrollRight != _showRightArrow) {
      setState(() => _showRightArrow = canScrollRight);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    } else {
      _controller.removeListener(_updateArrowVisibility);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          ListView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            children: [widget.child],
          ),
          if (_showRightArrow)
            Positioned(
              right: 4,
              child: IgnorePointer(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}