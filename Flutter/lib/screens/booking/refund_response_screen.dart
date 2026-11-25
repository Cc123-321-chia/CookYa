// screens/booking/refund_response_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';

class RefundResponseScreen extends StatefulWidget {
  final String refundId;

  const RefundResponseScreen({super.key, required this.refundId});

  @override
  State<RefundResponseScreen> createState() => _RefundResponseScreenState();
}

class _RefundResponseScreenState extends State<RefundResponseScreen> {
  final _responseController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  RefundRequestModel? _refund;
  bool _loading = true;
  String? _error;
  File? _image;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService.getRefundDetail(widget.refundId);
    if (!mounted) return;
    if (result['success'] == true) {
      // ApiService wraps the body as {success, data: {success, data: {...refund}}},
      // so unwrap one extra level when needed.
      final raw = result['data'];
      final refundJson = (raw is Map && raw['data'] is Map) ? raw['data'] : raw;
      debugPrint('RefundResponse parsed refund id = ${refundJson['id']}');
      debugPrint('booking_info = ${refundJson['booking_info']}');
      setState(() {
        _refund = RefundRequestModel.fromJson(refundJson);
        if (_refund!.instructorResponse.isNotEmpty) {
          _responseController.text = _refund!.instructorResponse;
        }
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['error'] ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _respond(bool agrees) async {
    if (!agrees && _responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please explain why you disagree'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          agrees ? 'Accept Refund?' : 'Dispute Refund?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          agrees
              ? 'You agree to refund this customer in full. '
                  'The refund will be processed immediately. '
                  'This action cannot be undone.'
              : 'You disagree with this refund. '
                  'Admin will review both sides and make a decision.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: agrees ? const Color(0xFF4CAF50) : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              agrees ? 'Accept & Refund' : 'Dispute',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);

    final result = await ApiService.instructorRespondRefund(
      refundId: widget.refundId,
      agrees: agrees,
      response: _responseController.text.trim(),
      image: _image,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            agrees
                ? 'Refund accepted. The customer will be refunded.'
                : 'Refund disputed. Admin will review.',
          ),
          backgroundColor: agrees ? const Color(0xFF4CAF50) : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Refund Request',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B4C2A)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: GoogleFonts.poppins(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(_refund!),
    );
  }

  Widget _buildContent(RefundRequestModel refund) {
    final isPending = refund.status == 'pending_instructor';
    final alreadyResponded = refund.instructorRespondedAt != null;
    final canRespond = isPending && !alreadyResponded;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top summary card ────────────────────────────────
          _buildSummaryCard(refund, canRespond),
          const SizedBox(height: 16),

          // ─── Customer info + reason ──────────────────────────
          _buildCustomerCard(refund),
          const SizedBox(height: 16),

          // ─── Already responded → read-only ───────────────────
          if (alreadyResponded) _buildResponseReadOnly(refund),

          // ─── Response form (only when can respond) ───────────
          if (canRespond) _buildResponseForm(),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Summary card
  // ══════════════════════════════════════════════════════════

  Widget _buildSummaryCard(RefundRequestModel refund, bool canRespond) {
    final info = refund.bookingInfo;
    final className = info['class_title']?.toString() ?? '';
    final currency = info['currency']?.toString() ?? 'RM';
    final pricePerPax = (info['price_per_pax'] ?? 0).toDouble();
    final totalPrice = (info['total_price'] ?? 0).toDouble();
    final quantity = (info['quantity'] ?? 0) as int;
    final dateStr = info['date']?.toString() ?? '';
    final startTime = info['start_time']?.toString() ?? '';
    final endTime = info['end_time']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge (top, most visible)
          _buildStatusBadge(refund.status),
          const SizedBox(height: 12),

          // Class title
          Text(
            className,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 6),

          // Date + time + pax
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: Color(0xFFC9A96E)),
              const SizedBox(width: 6),
              Text(
                '${_formatDate(dateStr)}${startTime.isNotEmpty ? ' · $startTime-$endTime' : ''}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFC9A96E),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.people, size: 14, color: Color(0xFFC9A96E)),
              const SizedBox(width: 4),
              Text(
                '$quantity pax',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFC9A96E),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0E6D2)),
          const SizedBox(height: 14),

          // Amount breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Refund amount requested',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              Text(
                '$currency ${totalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFB347),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$currency ${pricePerPax.toStringAsFixed(2)} × $quantity pax',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFC9A96E),
            ),
          ),

          // Deadline countdown (only if pending + can respond)
          if (canRespond && refund.deadline != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: Color(0xFFFFB347)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _deadlineText(refund.deadline!),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFFB347),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Customer card (who + reason + note + image)
  // ══════════════════════════════════════════════════════════

  Widget _buildCustomerCard(RefundRequestModel refund) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFFFD966),
                backgroundImage: refund.userAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(
                        ApiService.resolveImageUrl(refund.userAvatar))
                    : null,
                child: refund.userAvatar.isEmpty
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                refund.username,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0E6D2)),
          const SizedBox(height: 14),

          // Reason chip
          Text(
            'Reason',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              refund.reasonLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ),

          // Customer note
          if (refund.userNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Details',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              refund.userNote,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF6B4C2A).withValues(alpha: 0.85),
              ),
            ),
          ],

          // Customer image (evidence)
          if (refund.userImage.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: ApiService.resolveImageUrl(refund.userImage),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Read-only response (after already responded)
  // ══════════════════════════════════════════════════════════

  Widget _buildResponseReadOnly(RefundRequestModel refund) {
    final agrees = refund.instructorAgrees == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: agrees ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: agrees
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                agrees ? Icons.check_circle : Icons.cancel,
                color: agrees ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  agrees ? 'You accepted this refund' : 'You disputed this refund',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: agrees ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (refund.instructorResponse.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              refund.instructorResponse,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B4C2A),
                height: 1.5,
              ),
            ),
          ],
          if (refund.instructorImage.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: ApiService.resolveImageUrl(refund.instructorImage),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Response form (instructor can act)
  // ══════════════════════════════════════════════════════════

  Widget _buildResponseForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Response',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _responseController,
                maxLines: 4,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Explain your side. Required if you dispute the refund.',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF9E6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFFFFB347), width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Photo Evidence (optional)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _image != null
                          ? const Color(0xFFFFD966)
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                    image: _image != null
                        ? DecorationImage(
                            image: FileImage(_image!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _image == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate,
                                color: Color(0xFFFFB347), size: 40),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to upload',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFC9A96E),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _image = null),
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: Text(
                      'Remove photo',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _respond(false),
                icon: const Icon(Icons.close, size: 18),
                label: Text(
                  'Dispute',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : () => _respond(true),
                icon: const Icon(Icons.check, size: 18),
                label: Text(
                  'Accept & Refund',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: Color(0xFFFFB347)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'If you do not respond within 24 hours, '
                  'a full refund will be issued automatically.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFC9A96E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════════════════════════

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending_instructor':
        color = Colors.orange;
        label = 'Waiting for your response';
        break;
      case 'pending_admin':
        color = Colors.purple;
        label = 'Under admin review';
        break;
      case 'resolved_full':
        color = Colors.green;
        label = 'Full refund approved';
        break;
      case 'resolved_half':
        color = Colors.blue;
        label = 'Half refund approved';
        break;
      case 'resolved_none':
        color = Colors.red;
        label = 'Refund rejected';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} ($weekday)';
  }

  String _deadlineText(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Respond soon';
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Overdue — respond immediately';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return 'Respond within ${h}h ${m}m';
    return 'Respond within ${m}m';
  }
}