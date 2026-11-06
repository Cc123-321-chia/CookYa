// lib/admin/admin_approval_detail.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../services/admin_api_service.dart';

class AdminApprovalDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? pendingItem;
  final List<Map<String, dynamic>>? pendingItems;
  final VoidCallback onApproved;
  final bool readOnly;

  const AdminApprovalDetailScreen({
    super.key,
    this.pendingItem,
    this.pendingItems,
    required this.onApproved,
    this.readOnly = false,
  });

  @override
  State<AdminApprovalDetailScreen> createState() =>
      _AdminApprovalDetailScreenState();
}

class _AdminApprovalDetailScreenState extends State<AdminApprovalDetailScreen> {
  int _currentIndex = 0;
  bool _isProcessing = false;
  int _currentImageIndex = 0;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  List<Map<String, dynamic>> get _items {
    if (widget.pendingItems != null && widget.pendingItems!.isNotEmpty) {
      return widget.pendingItems!;
    } else if (widget.pendingItem != null) {
      return [widget.pendingItem!];
    }
    return [];
  }

  Map<String, dynamic> get _currentItem => _items[_currentIndex];

  List<String> get _imageUrls {
    final urls = <String>[];
    final photoUrls = (_currentItem['photoUrls'] as List?) ?? [];
    for (final p in photoUrls) {
      final s = p.toString();
      if (s.isNotEmpty) urls.add(s);
    }
    if (urls.isEmpty) {
      final imageUrl = (_currentItem['imageUrl'] ?? '').toString();
      if (imageUrl.isNotEmpty) urls.add(imageUrl);
    }
    return urls;
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;

    final videoUrl = (_currentItem['videoUrl'] ?? '').toString();
    if (videoUrl.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoInitialized = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _videoInitialized = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Details'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF6B4C2A),
        ),
        body: const Center(child: Text('No items')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? 'View Post'
              : 'Review (${_currentIndex + 1}/${_items.length})',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF6B4C2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!widget.readOnly && _items.length > 1) ...[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _currentIndex > 0
                  ? () {
                      setState(() {
                        _currentIndex--;
                        _currentImageIndex = 0;
                      });
                      _initVideo();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _currentIndex < _items.length - 1
                  ? () {
                      setState(() {
                        _currentIndex++;
                        _currentImageIndex = 0;
                      });
                      _initVideo();
                    }
                  : null,
            ),
          ],
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) return _buildWideLayout();
                      return _buildNarrowLayout();
                    },
                  ),
                ),
                if (!widget.readOnly) _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildMediaPanel(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildContentPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaPanel(),
          const SizedBox(height: 20),
          _buildContentPanel(),
        ],
      ),
    );
  }

  // ---------------- Media ----------------

  Widget _buildMediaPanel() {
    final images = _imageUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTypeBadge(),
        const SizedBox(height: 12),
        if (images.isEmpty) _buildPlaceholder() else _buildImageCarousel(images),
        if (_videoController != null && _videoInitialized) ...[
          const SizedBox(height: 16),
          _buildVideoPlayer(),
        ],
      ],
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    final hasMultiple = images.length > 1;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                images[_currentImageIndex],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              ),
            ),
            if (hasMultiple && _currentImageIndex > 0)
              Positioned(
                left: 8,
                child: _navArrow(
                  icon: Icons.chevron_left,
                  onTap: () => setState(() => _currentImageIndex--),
                ),
              ),
            if (hasMultiple && _currentImageIndex < images.length - 1)
              Positioned(
                right: 8,
                child: _navArrow(
                  icon: Icons.chevron_right,
                  onTap: () => setState(() => _currentImageIndex++),
                ),
              ),
          ],
        ),
        if (hasMultiple) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              return GestureDetector(
                onTap: () => setState(() => _currentImageIndex = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == i
                        ? const Color(0xFFFFB347)
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '${_currentImageIndex + 1} / ${images.length}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFC9A96E),
            ),
          ),
        ],
      ],
    );
  }

  Widget _navArrow({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EDE8)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _currentItem['type'] == 'recipe' ? Icons.restaurant : Icons.eco,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No image',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    final controller = _videoController!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
              child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFFFFB347),
                  bufferedColor: Colors.white30,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final type = _currentItem['type'] ?? 'recipe';
    final isRecipe = type == 'recipe';
    final color = isRecipe ? const Color(0xFFFF9800) : const Color(0xFF2196F3);
    final bg = isRecipe ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD);
    final icon = isRecipe ? Icons.restaurant : Icons.eco;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            isRecipe ? 'RECIPE' : 'INGREDIENT',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Content ----------------

  Widget _buildContentPanel() {
    final title = (_currentItem['title'] ?? 'Untitled').toString();
    final description = (_currentItem['description'] ?? '').toString();
    final authorName = (_currentItem['authorName'] ?? 'Unknown').toString();
    final authorAvatar = (_currentItem['authorAvatar'] ?? '').toString();
    final createdAt = (_currentItem['createdAt'] ?? '').toString();

    final cuisineType = (_currentItem['cuisineType'] ?? '').toString();
    final difficulty = (_currentItem['difficultyLevel'] ?? '').toString();
    final duration = (_currentItem['durationMinutes'] ?? 0) as int;
    final likes = (_currentItem['likes'] ?? 0) as int;
    final comments = (_currentItem['comments'] ?? 0) as int;

    final tags = (_currentItem['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final dishes = (_currentItem['dishes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final cookingTools = (_currentItem['cookingTools'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final ingredients = (_currentItem['ingredients'] as List?) ?? [];
    final steps = (_currentItem['steps'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D1F0E),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFFB347),
              backgroundImage:
                  authorAvatar.isNotEmpty ? NetworkImage(authorAvatar) : null,
              child: authorAvatar.isEmpty
                  ? Text(
                      authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authorName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  Text(
                    _formatDateTime(createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFC9A96E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (cuisineType.isNotEmpty) _infoChip(Icons.public, cuisineType),
            if (difficulty.isNotEmpty)
              _infoChip(Icons.signal_cellular_alt, difficulty),
            if (duration > 0) _infoChip(Icons.access_time, '$duration min'),
            _infoChip(Icons.favorite, '$likes likes'),
            _infoChip(Icons.comment, '$comments comments'),
          ],
        ),
        const SizedBox(height: 20),
        if (description.isNotEmpty) ...[
          _sectionTitle('Description', Icons.description),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.6,
              color: const Color(0xFF4A3728),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (tags.isNotEmpty) ...[
          _sectionTitle('Tags', Icons.local_offer),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map(_tagChip).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (cookingTools.isNotEmpty) ...[
          _sectionTitle('Cooking Tools', Icons.kitchen),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: cookingTools.map(_tagChip).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (dishes.isNotEmpty) ...[
          _sectionTitle('Dishes', Icons.restaurant_menu),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: dishes.map(_tagChip).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (ingredients.isNotEmpty) ...[
          _sectionTitle('Ingredients', Icons.eco),
          const SizedBox(height: 8),
          _buildIngredientList(ingredients),
          const SizedBox(height: 20),
        ],
        if (steps.isNotEmpty) ...[
          _sectionTitle('Steps', Icons.format_list_numbered),
          const SizedBox(height: 8),
          _buildStepList(steps),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFB347)),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EDE8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFC9A96E)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '#$text',
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: const Color(0xFFFF8C00),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIngredientList(List<dynamic> ingredients) {
    return Column(
      children: ingredients.asMap().entries.map((entry) {
        final index = entry.key;
        final ing = entry.value;
        String name = '';
        String amount = '';
        if (ing is Map) {
          name = (ing['name'] ?? '').toString();
          amount = (ing['amount'] ?? '').toString();
        } else {
          name = ing.toString();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  amount.isNotEmpty ? '$name — $amount' : name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF4A3728),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepList(List<dynamic> steps) {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        String instruction = '';
        String note = '';
        if (step is Map) {
          instruction = (step['instruction'] ?? '').toString();
          note = (step['note'] ?? '').toString();
        } else {
          instruction = step.toString();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFFB347).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instruction,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF4A3728),
                        height: 1.5,
                      ),
                    ),
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 12, color: Color(0xFFC9A96E)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              note,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFFC9A96E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------- Bottom bar ----------------

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showRejectDialog,
              icon: const Icon(Icons.close, size: 18),
              label: Text(
                'Reject',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _doApprove,
              icon: const Icon(Icons.check, size: 18),
              label: Text(
                'Approve',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doApprove() async {
    setState(() => _isProcessing = true);
    final postType = _currentItem['type'] ?? 'recipe';
    final postId = _currentItem['id']?.toString() ?? '';
    final ok = await AdminApiService.approvePost(
      postType: postType,
      postId: postId,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Approved'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      _removeCurrentAndContinue();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to approve'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog() {
    String selectedReason = 'unrelated';
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Reject Post',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a reason:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildReasonOption(
                    setDialogState,
                    selectedReason,
                    'violation',
                    'Violation',
                    'This will PERMANENTLY SUSPEND the user.',
                    isDanger: true,
                    onSelected: (v) => setDialogState(() => selectedReason = v),
                  ),
                  _buildReasonOption(
                    setDialogState,
                    selectedReason,
                    'unrelated',
                    'Unrelated to Cooking',
                    'No penalty.',
                    onSelected: (v) => setDialogState(() => selectedReason = v),
                  ),
                  _buildReasonOption(
                    setDialogState,
                    selectedReason,
                    'wrong_category',
                    'Wrong Category',
                    'e.g. recipe posted under ingredients.',
                    onSelected: (v) => setDialogState(() => selectedReason = v),
                  ),
                  _buildReasonOption(
                    setDialogState,
                    selectedReason,
                    'other',
                    'Other',
                    'Custom reason.',
                    onSelected: (v) => setDialogState(() => selectedReason = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Additional note (optional)',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _doReject(selectedReason, noteController.text.trim());
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReasonOption(
    StateSetter setDialogState,
    String current,
    String value,
    String label,
    String subtitle, {
    bool isDanger = false,
    required Function(String) onSelected,
  }) {
    final isSelected = current == value;
    final color = isDanger ? const Color(0xFFDC2626) : const Color(0xFF6B4C2A);
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDanger ? const Color(0xFFFEF2F2) : const Color(0xFFFFF5E6))
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDanger ? const Color(0xFFEF5350) : const Color(0xFFFFB347))
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? color : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDanger
                          ? const Color(0xFFDC2626)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doReject(String reason, String note) async {
    setState(() => _isProcessing = true);
    final postType = _currentItem['type'] ?? 'recipe';
    final postId = _currentItem['id']?.toString() ?? '';
    final result = await AdminApiService.rejectPost(
      postType: postType,
      postId: postId,
      reason: reason,
      note: note,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      final suspended = result['account_suspended'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspended
                ? '❌ Rejected — user account suspended'
                : '❌ Rejected',
          ),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
      _removeCurrentAndContinue();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to reject'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeCurrentAndContinue() {
    final newItems = List<Map<String, dynamic>>.from(_items);
    newItems.removeAt(_currentIndex);
    widget.onApproved();

    if (newItems.isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (_currentIndex >= newItems.length) {
      _currentIndex = newItems.length - 1;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminApprovalDetailScreen(
          pendingItems: newItems,
          onApproved: widget.onApproved,
        ),
      ),
    );
  }

  String _formatDateTime(String iso) {
    if (iso.isEmpty) return 'Recently';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays > 7) {
        return '${dt.day}/${dt.month}/${dt.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inMinutes}m ago';
      }
    } catch (_) {
      return 'Recently';
    }
  }
}