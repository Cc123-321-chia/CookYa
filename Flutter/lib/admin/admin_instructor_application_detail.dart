// lib/admin/admin_instructor_application_detail.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';

class AdminInstructorApplicationDetailScreen extends StatefulWidget {
  final String applicationId;

  const AdminInstructorApplicationDetailScreen({
    super.key,
    required this.applicationId,
  });

  @override
  State<AdminInstructorApplicationDetailScreen> createState() =>
      _AdminInstructorApplicationDetailScreenState();
}

class _AdminInstructorApplicationDetailScreenState
    extends State<AdminInstructorApplicationDetailScreen> {
  Map<String, dynamic>? _application;
  bool _isLoading = true;
  bool _isProcessing = false;
  int _currentShopPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await AdminApiService.getInstructorApplicationDetail(
      widget.applicationId,
    );
    if (!mounted) return;
    setState(() {
      _application = data;
      _isLoading = false;
      _currentShopPhotoIndex = 0;
    });
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    final ok = await AdminApiService.approveInstructorApplication(
      widget.applicationId,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Approved!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      navigator.pop(true);
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to approve'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reject Application',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for rejection.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'e.g. Business license not clear, missing food license...',
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
              style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(dialogContext);

              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              setState(() => _isProcessing = true);
              final result = await AdminApiService.rejectInstructorApplication(
                id: widget.applicationId,
                reason: reason,
              );

              if (!mounted) return;
              setState(() => _isProcessing = false);

              if (result['success'] == true) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Rejected'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
                navigator.pop(true);
              } else {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result['error'] ?? 'Failed'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Reject',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    if (_application == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF6B4C2A),
          title: const Text('Not found'),
        ),
        body: const Center(child: Text('Application not found')),
      );
    }

    final a = _application!;
    final status = (a['status'] ?? 'pending').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Instructor Application',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF6B4C2A),
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
                      return isWide
                          ? _buildWide(a, status)
                          : _buildNarrow(a, status);
                    },
                  ),
                ),
                if (status == 'pending') _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildWide(Map<String, dynamic> a, String status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildMediaPanel(a),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildContentPanel(a, status),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(Map<String, dynamic> a, String status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMediaPanel(a),
          const SizedBox(height: 20),
          _buildContentPanel(a, status),
        ],
      ),
    );
  }

  // ---------------- Media panel ----------------

  Widget _buildMediaPanel(Map<String, dynamic> a) {
    final coverPhoto = (a['cover_photo'] ?? '').toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusBadge((a['status'] ?? 'pending').toString()),
        const SizedBox(height: 16),
        _buildImageCard(
          'Shop Avatar',
          a['avatar'],
          useNaturalAspect: true,
        ),
        if (coverPhoto.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildImageCard('Cover Photo', coverPhoto, height: 140),
        ],
        const SizedBox(height: 16),
        _buildSectionTitle('Shop Photos', Icons.photo_library),
        const SizedBox(height: 8),
        _buildShopPhotos(a['shop_photos']),
      ],
    );
  }

  Widget _buildShopPhotos(dynamic photos) {
    final raw = (photos as List?) ?? [];
    // Deduplicate by image URL in case the backend stored duplicates.
    final seen = <String>{};
    final list = <dynamic>[];
    for (final p in raw) {
      final url = (p['image'] ?? '').toString();
      if (url.isEmpty || seen.contains(url)) continue;
      seen.add(url);
      list.add(p);
    }
    if (list.isEmpty) {
      return _emptyBox('No shop photos');
    }
    final safeIndex =
        _currentShopPhotoIndex.clamp(0, list.length - 1).toInt();
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              list[safeIndex]['image'].toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _emptyBox('Failed to load'),
            ),
          ),
        ),
        if (list.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(list.length, (i) {
              final selected = i == safeIndex;
              return GestureDetector(
                onTap: () => setState(() => _currentShopPhotoIndex = i),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFB347)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      list[i]['image'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF5F7FA),
                        child: const Icon(Icons.broken_image,
                            size: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '${safeIndex + 1} / ${list.length}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFC9A96E),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------- Content panel ----------------

  Widget _buildContentPanel(Map<String, dynamic> a, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(a),
        const SizedBox(height: 16),

        // Description
        if ((a['description'] ?? '').toString().isNotEmpty)
          _sectionCard(
            title: 'Description',
            icon: Icons.description,
            child: Text(
              a['description'].toString(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.6,
                color: const Color(0xFF4A3728),
              ),
            ),
          ),

        // Class Information
        if ((a['class_title'] ?? '').toString().isNotEmpty ||
            (a['class_description'] ?? '').toString().isNotEmpty ||
            (a['price'] ?? '').toString().isNotEmpty ||
            (a['schedule'] ?? '').toString().isNotEmpty)
          _sectionCard(
            title: 'Class Information',
            icon: Icons.restaurant_menu,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((a['class_title'] ?? '').toString().isNotEmpty)
                  _infoRow('Title', a['class_title'].toString()),
                if ((a['price'] ?? '').toString().isNotEmpty)
                  _infoRow('Price', a['price'].toString()),
                if ((a['schedule'] ?? '').toString().isNotEmpty)
                  _infoRow('Schedule', a['schedule'].toString()),
                if ((a['class_description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    a['class_description'].toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.5,
                      color: const Color(0xFF4A3728),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // Tags
        if ((a['tags'] as List?)?.isNotEmpty == true)
          _sectionCard(
            title: 'Tags',
            icon: Icons.local_offer,
            child: _chipWrap(a['tags'] as List),
          ),

        // Dishes
        if ((a['dishes'] as List?)?.isNotEmpty == true)
          _sectionCard(
            title: 'Dishes',
            icon: Icons.restaurant,
            child: _chipWrap(a['dishes'] as List),
          ),

        // Certificates
        if ((a['certificates'] as List?)?.isNotEmpty == true)
          _sectionCard(
            title: 'Certificates',
            icon: Icons.emoji_events,
            child: _chipWrap(a['certificates'] as List),
          ),

        // Legal Documents
        _sectionCard(
          title: 'Legal Documents',
          icon: Icons.verified,
          child: Column(
            children: [
              _documentRow('Business License', a['business_license']),
              _documentRow('Food License', a['food_license']),
              _documentRow('Health Certificate', a['health_certificate']),
            ],
          ),
        ),

        // Certifications
        _sectionCard(
          title: 'Certifications',
          icon: Icons.workspace_premium,
          child: Column(
            children: [
              _documentRow('Chef Certification', a['chef_certification']),
              _documentRow('Insurance', a['insurance']),
              _documentRow('Food Safety', a['food_safety_certificate']),
            ],
          ),
        ),

        // Status message
        if (status != 'pending') _buildStatusMessage(status, a['reject_reason']),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFFFFB347)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> a) {
    final userAvatar = (a['user_avatar'] ?? '').toString();
    final username = (a['username'] ?? '-').toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFFFB347),
            backgroundImage:
                userAvatar.isNotEmpty ? NetworkImage(userAvatar) : null,
            child: userAvatar.isEmpty
                ? Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['shop_name'] ?? '-',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D1F0E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 14, color: Color(0xFFC9A96E)),
                    const SizedBox(width: 4),
                    Text(
                      username,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.email,
                        size: 14, color: Color(0xFFC9A96E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (a['user_email'] ?? a['email'] ?? '-').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B4C2A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone,
                        size: 14, color: Color(0xFFC9A96E)),
                    const SizedBox(width: 4),
                    Text(
                      (a['phone'] ?? '-').toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Color(0xFFC9A96E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (a['address'] ?? '-').toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF6B4C2A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 14, color: Color(0xFFC9A96E)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(a['applied_at']),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFC9A96E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;
    switch (status) {
      case 'approved':
        color = const Color(0xFF4CAF50);
        icon = Icons.check_circle;
        label = 'Approved';
        break;
      case 'rejected':
        color = const Color(0xFFDC2626);
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      default:
        color = const Color(0xFFFF9800);
        icon = Icons.hourglass_top;
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(
    String label,
    dynamic url, {
    double height = 160,
    bool useNaturalAspect = false,
  }) {
    final hasImage = url != null && url.toString().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: hasImage ? () => _openImage(url.toString(), label) : null,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: useNaturalAspect ? 0 : height,
              maxHeight: useNaturalAspect ? 320 : height,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.network(
                    url.toString(),
                    fit: useNaturalAspect ? BoxFit.contain : BoxFit.cover,
                    errorBuilder: (_, __, ___) => _emptyBox('Failed to load'),
                  )
                : _emptyBox('No image'),
          ),
        ),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4A3728),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipWrap(List items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            e.toString(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFFF8C00),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _documentRow(String label, dynamic url) {
    final hasFile = url != null && url.toString().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            hasFile ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: hasFile ? const Color(0xFF4CAF50) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF4A3728),
              ),
            ),
          ),
          if (hasFile)
            ElevatedButton.icon(
              onPressed: () => _openImage(url.toString(), label),
              icon: const Icon(Icons.visibility, size: 14),
              label: Text(
                'View',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            )
          else
            Text(
              'Not uploaded',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String status, dynamic reason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status == 'approved'
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application ${status[0].toUpperCase()}${status.substring(1)}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: status == 'approved'
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFDC2626),
            ),
          ),
          if (reason != null && reason.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: $reason',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
              onPressed: _approve,
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

  void _openImage(String url, String label) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C2A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B4C2A)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('Failed to load image'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '-';
    }
  }
}