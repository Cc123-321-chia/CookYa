// lib/admin/admin_refunds_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/admin_api_service.dart';
import '../services/api_service.dart';

class AdminRefundsScreen extends StatefulWidget {
  const AdminRefundsScreen({super.key});

  @override
  State<AdminRefundsScreen> createState() => _AdminRefundsScreenState();
}

class _AdminRefundsScreenState extends State<AdminRefundsScreen> {
  String _filter = 'pending_admin';
  List<Map<String, dynamic>> _refunds = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AdminApiService.getRefunds(status: _filter);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _refunds = List<Map<String, dynamic>>.from(result['data']);
        _loading = false;
      });
    } else {
      setState(() {
        _error = result['error'] ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  Future<void> _resolve(Map<String, dynamic> refund, String decision) async {
    final noteController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9E6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          decision == 'full'
              ? 'Approve Full Refund?'
              : decision == 'half'
                  ? 'Approve Half Refund?'
                  : 'Reject Refund?',
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
              decision == 'full'
                  ? 'Customer will receive 100% refund to their card.'
                  : decision == 'half'
                      ? 'Customer will receive 50% refund.'
                      : 'Customer will receive no refund.',
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
                hintText: 'Admin note (sent to customer)',
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFFC9A96E))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: decision == 'none'
                  ? Colors.red
                  : decision == 'half'
                      ? Colors.orange
                      : const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              decision == 'none'
                  ? 'Reject'
                  : decision == 'half'
                      ? 'Approve 50%'
                      : 'Approve 100%',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await AdminApiService.resolveRefund(
      refundId: refund['id'].toString(),
      decision: decision,
      adminNote: noteController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refund resolved: ${decision.toUpperCase()}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _reasonLabel(String reason) {
    const map = {
      'not_as_described': 'Class not as described',
      'instructor_no_show': 'Instructor did not show up',
      'quality_issue': 'Poor quality',
      'personal_emergency': 'Personal emergency',
      'other': 'Other',
    };
    return map[reason] ?? reason;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending_instructor':
        return Colors.orange;
      case 'pending_admin':
        return const Color(0xFFFFB347);
      case 'resolved_full':
        return Colors.green;
      case 'resolved_half':
        return Colors.blue;
      case 'resolved_none':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    const map = {
      'pending_instructor': 'PENDING INSTRUCTOR',
      'pending_admin': 'PENDING ADMIN',
      'resolved_full': 'FULL REFUND',
      'resolved_half': 'HALF REFUND',
      'resolved_none': 'REJECTED',
    };
    return map[status] ?? status.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('Pending', 'pending_admin'),
                const SizedBox(width: 8),
                _filterChip('All', 'all'),
                const Spacer(),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh,
                      color: Color(0xFF6B4C2A)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFFB347)),
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
                                style: GoogleFonts.poppins(
                                    color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _refunds.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('No refund requests',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: const Color(0xFFFFB347),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _refunds.length,
                              itemBuilder: (context, index) =>
                                  _buildRefundCard(_refunds[index]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFB347) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFB347)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B4C2A),
          ),
        ),
      ),
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> r) {
    final status = r['status'] as String? ?? 'pending_admin';
    final isPendingAdmin = status == 'pending_admin';
    final bookingInfo = r['booking_info'] ?? {};
    final userAvatar = ApiService.resolveImageUrl(r['user_avatar']);
    final userImage = ApiService.resolveImageUrl(r['user_image']);
    final instructorImage = ApiService.resolveImageUrl(r['instructor_image']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPendingAdmin
              ? const Color(0xFFFFD966)
              : Colors.grey.shade200,
          width: isPendingAdmin ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusLabel(status),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'REFUND',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6C5CE7),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'RM ${(bookingInfo['total_price'] ?? 0).toString()}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFB347),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Class info
          Text(
            bookingInfo['class_title'] ?? 'Class',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${bookingInfo['date']} • ${bookingInfo['quantity']} pax',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFC9A96E),
            ),
          ),
          const SizedBox(height: 12),

          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFFD966),
                backgroundImage:
                    userAvatar.isNotEmpty ? CachedNetworkImageProvider(userAvatar) : null,
                child: userAvatar.isEmpty
                    ? const Icon(Icons.person,
                        size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'From: ${r['username'] ?? 'Unknown'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // User reason
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag,
                        size: 14, color: Color(0xFFFFB347)),
                    const SizedBox(width: 6),
                    Text(
                      'User\'s Reason: ${_reasonLabel(r['user_reason'] ?? '')}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ],
                ),
                if ((r['user_note'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    r['user_note'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                ],
                if (userImage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: userImage,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Instructor response
          if (r['instructor_responded_at'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: r['instructor_agrees'] == true
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        r['instructor_agrees'] == true
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 14,
                        color: r['instructor_agrees'] == true
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r['instructor_agrees'] == true
                            ? 'Instructor Accepted'
                            : 'Instructor Disputed',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: r['instructor_agrees'] == true
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  if ((r['instructor_response'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      r['instructor_response'],
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ],
                  if (instructorImage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: instructorImage,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Already resolved: show decision
          if (!isPendingAdmin && (r['admin_note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Admin note: ${r['admin_note']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],

          // Action buttons (only if pending_admin)
          if (isPendingAdmin) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _resolve(r, 'none'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolve(r, 'half'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '50%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _resolve(r, 'full'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '100%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}