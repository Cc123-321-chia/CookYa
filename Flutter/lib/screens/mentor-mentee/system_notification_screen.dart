// lib/screens/mentor-mentee/system_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../booking/refund_response_screen.dart';

class SystemNotificationScreen extends StatefulWidget {
  const SystemNotificationScreen({super.key});

  @override
  State<SystemNotificationScreen> createState() =>
      _SystemNotificationScreenState();
}

class _SystemNotificationScreenState extends State<SystemNotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getSystemNotifications();
    if (result['success'] == true) {
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(result['data']);
      });
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _markRead(String id) async {
    await ApiService.markSystemNotificationRead(id);
    _load();
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour ago';
    return '${diff.inDays} days ago';
  }

  bool _isRefundNotification(Map<String, dynamic> n) {
    final type = n['notification_type']?.toString() ?? '';
    return type == 'refund_request' ||
        type == 'refund_update' ||
        type == 'refund_resolved';
  }

  /// Only refund_request notifications should be actionable by the instructor.
  /// Other refund notifications (update/resolved) are read-only, so tapping
  /// them just marks them as read.
  bool _shouldOpenRefundScreen(Map<String, dynamic> n) {
    final type = n['notification_type']?.toString() ?? '';
    final postType = n['post_type']?.toString() ?? '';
    final postId = n['post_id']?.toString() ?? '';
    return type == 'refund_request' &&
        postType == 'refund' &&
        postId.isNotEmpty;
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'post_rejected':
        return Icons.block;
      case 'account_suspended':
        return Icons.person_off;
      case 'refund_request':
        return Icons.assignment_return;
      case 'refund_update':
        return Icons.update;
      case 'refund_resolved':
        return Icons.check_circle_outline;
      case 'booking_cancelled':
        return Icons.event_busy;
      case 'mentorship_accepted':
        return Icons.school;
      case 'mentorship_declined':
        return Icons.school_outlined;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'post_rejected':
        return Colors.red;
      case 'account_suspended':
        return Colors.deepOrange;
      case 'refund_request':
        return const Color(0xFFFFB347);
      case 'refund_update':
        return Colors.blue;
      case 'refund_resolved':
        return Colors.green;
      case 'booking_cancelled':
        return Colors.redAccent;
      case 'mentorship_accepted':
        return const Color(0xFF00B894);
      case 'mentorship_declined':
        return Colors.grey;
      default:
        return const Color(0xFFFFB347);
    }
  }

  Future<void> _handleTap(Map<String, dynamic> n) async {
    final isRead = n['is_read'] == true;

    // Mark as read if not already
    if (!isRead) {
      await _markRead(n['id'].toString());
    }

    // Only actionable refund_request notifications open the response screen
    if (_shouldOpenRefundScreen(n)) {
      final refundId = n['post_id'].toString();
      if (!mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RefundResponseScreen(refundId: refundId),
        ),
      );
      if (result == true) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'CookYa System',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: () async {
                await ApiService.markAllSystemNotificationsRead();
                _load();
              },
              child: Text(
                'Mark all read',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFFFB347),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No system notifications',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFFFB347),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _buildNotificationCard(n);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final isRead = n['is_read'] == true;
    final type = n['notification_type']?.toString() ?? 'general';
    final iconColor = _getIconColor(type);
    final isRefund = _isRefundNotification(n);
    final shouldOpenRefund = _shouldOpenRefundScreen(n);

    return GestureDetector(
      onTap: () => _handleTap(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFFF5E6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : const Color(0xFFFFD966),
            width: isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIcon(type),
                    size: 18,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    n['title'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                          isRead ? FontWeight.w500 : FontWeight.w700,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              n['content'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color:
                    const Color(0xFF4A3728).withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),

            // Only refund_request notifications get the action button
            if (isRefund && shouldOpenRefund) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleTap(n),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    'Respond to Refund',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB347),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 12, color: Color(0xFFC9A96E)),
                  const SizedBox(width: 4),
                  Text(
                    'Please respond within 24 hours',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFFC9A96E),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
            Text(
              _formatDate(n['created_at']?.toString()),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}