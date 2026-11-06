// lib/admin/admin_report_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../services/admin_api_service.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onResolved;

  const AdminReportDetailScreen({
    super.key,
    required this.report,
    required this.onResolved,
  });

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  int _currentImageIndex = 0;
  bool _isProcessing = false;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  Map<String, dynamic> get _report => widget.report;
  Map<String, dynamic> get _post {
    final p = _report['post_detail'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return {'deleted': true};
  }

  bool get _isDeleted => _post['deleted'] == true;

  List<String> get _imageUrls {
    final urls = <String>[];
    final photoUrls = (_post['photoUrls'] as List?) ?? [];
    for (final p in photoUrls) {
      final s = p.toString();
      if (s.isNotEmpty) urls.add(s);
    }
    if (urls.isEmpty) {
      final img = (_post['imageUrl'] ?? '').toString();
      if (img.isNotEmpty) urls.add(img);
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
    final videoUrl = (_post['videoUrl'] ?? '').toString();
    if (videoUrl.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoInitialized = true);
    } catch (_) {
      // Silently ignore video errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Report Review',
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
                      return isWide ? _buildWide() : _buildNarrow();
                    },
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildWide() {
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

  Widget _buildNarrow() {
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
    if (_isDeleted) {
      return _deletedBanner();
    }
    final images = _imageUrls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _typeBadge(),
        const SizedBox(height: 12),
        if (images.isEmpty) _placeholder() else _imageCarousel(images),
        if (_videoController != null && _videoInitialized) ...[
          const SizedBox(height: 16),
          _videoPlayer(),
        ],
      ],
    );
  }

  Widget _deletedBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF5350)),
      ),
      child: Column(
        children: [
          const Icon(Icons.delete_forever, size: 48, color: Color(0xFFEF5350)),
          const SizedBox(height: 8),
          Text(
            'This post has been deleted.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageCarousel(List<String> images) {
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
                errorBuilder: (_, __, ___) => _placeholder(),
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

  Widget _placeholder() {
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
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No image',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoPlayer() {
    final controller = _videoController!;
    return Container(
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
                  controller.value.isPlaying ? controller.pause() : controller.play();
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
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBadge() {
    final type = _post['type'] ?? _report['post_type'] ?? 'recipe';
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
            (type as String).toUpperCase(),
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
    final title = (_post['title'] ?? _report['post_title'] ?? 'Untitled').toString();
    final description = (_post['description'] ?? '').toString();
    final authorName = (_post['authorName'] ?? _report['post_author_name'] ?? 'Unknown').toString();
    final authorAvatar = (_post['authorAvatar'] ?? '').toString();
    final createdAt = (_post['createdAt'] ?? '').toString();

    final tags = (_post['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final cookingTools = (_post['cookingTools'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final ingredients = (_post['ingredients'] as List?) ?? [];
    final steps = (_post['steps'] as List?) ?? [];

    final reporterName = (_report['reporter_name'] ?? 'Unknown').toString();
    final reason = _reportReasonLabel((_report['reason'] ?? '').toString());
    final note = (_report['note'] ?? '').toString();
    final reportTime = _formatDate((_report['created_at'] ?? '').toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reported-post title
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

        // Author
        if (!_isDeleted)
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
              Text(
                authorName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFFC9A96E),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),

        // ===== REPORT INFO CARD =====
        _reportInfoCard(reporterName, reason, note, reportTime),
        const SizedBox(height: 20),

        // ===== POST BODY =====
        if (!_isDeleted) ...[
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
          if (ingredients.isNotEmpty) ...[
            _sectionTitle('Ingredients', Icons.eco),
            const SizedBox(height: 8),
            _ingredientList(ingredients),
            const SizedBox(height: 20),
          ],
          if (steps.isNotEmpty) ...[
            _sectionTitle('Steps', Icons.format_list_numbered),
            const SizedBox(height: 8),
            _stepList(steps),
            const SizedBox(height: 20),
          ],
        ],
      ],
    );
  }

  Widget _reportInfoCard(String reporter, String reason, String note, String time) {
    return Container(
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
            children: [
              const Icon(Icons.flag, size: 18, color: Color(0xFFFF9800)),
              const SizedBox(width: 6),
              Text(
                'Report Information',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _reportRow('Reason', reason),
          _reportRow('Reported by', reporter),
          _reportRow('When', time),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note from reporter:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF4A3728),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFC9A96E),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ),
        ],
      ),
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

  Widget _ingredientList(List<dynamic> ingredients) {
    return Column(
      children: ingredients.asMap().entries.map((entry) {
        final idx = entry.key;
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
                    '${idx + 1}',
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

  Widget _stepList(List<dynamic> steps) {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final idx = entry.key;
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
                    '${idx + 1}',
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
              onPressed: () => _showResolveDialog('keep'),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                'Keep Post',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: const BorderSide(color: Color(0xFF4CAF50)),
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
              onPressed: () => _showResolveDialog('remove'),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                'Remove Post',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
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

  void _showResolveDialog(String action) {
    final noteController = TextEditingController();
    final isRemove = action == 'remove';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isRemove ? 'Remove this post?' : 'Keep this post?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRemove
                  ? 'The post will be permanently deleted. Reporter and author will be notified.'
                  : 'No action will be taken. Reporter will be notified.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Admin note (optional)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _doResolve(action, noteController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isRemove ? const Color(0xFFEF5350) : const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isRemove ? 'Remove' : 'Keep',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doResolve(String action, String note) async {
    setState(() => _isProcessing = true);
    final result = await AdminApiService.adminResolveReport(
      reportId: _report['id'].toString(),
      action: action,
      adminNote: note,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'remove'
                ? '✅ Post removed and author notified'
                : '✅ Report kept and reporter notified',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      widget.onResolved();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------- Helpers ----------------

  String _reportReasonLabel(String reason) {
    const labels = {
      'inappropriate': 'Inappropriate content',
      'spam': 'Spam / Advertising',
      'violence': 'Violence or dangerous content',
      'harassment': 'Harassment or hate speech',
      'copyright': 'Copyright violation',
      'other': 'Other',
    };
    return labels[reason] ?? reason;
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}