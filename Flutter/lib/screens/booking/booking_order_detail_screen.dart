// screens/booking/booking_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import '../../widgets/soft_button.dart';
import 'review_booking_screen.dart';
import 'refund_request_screen.dart';
import 'refund_response_screen.dart';

class BookingOrderDetailScreen extends StatefulWidget {
  final BookingModel booking;
  final bool isInstructorView;

  const BookingOrderDetailScreen({
    super.key,
    required this.booking,
    this.isInstructorView = false,
  });

  @override
  State<BookingOrderDetailScreen> createState() =>
      _BookingOrderDetailScreenState();
}

class _BookingOrderDetailScreenState extends State<BookingOrderDetailScreen> {
  late BookingModel _booking;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _cancelBooking() async {
    final ok = await _confirm(
      title: 'Cancel booking?',
      message:
          'This booking will be cancelled and a full refund will be issued.',
      confirmLabel: 'Cancel booking',
      confirmColor: Colors.red,
    );
    if (!ok) return;

    setState(() => _busy = true);
    final result = widget.isInstructorView
        ? await ApiService.instructorCancelBooking(_booking.id)
        : await ApiService.cancelBooking(_booking.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      _showSnack('Booking cancelled');
      Navigator.pop(context, true);
    } else {
      _showSnack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _markCompleted() async {
    final ok = await _confirm(
      title: 'Confirm class completed?',
      message:
          'Confirm that you have finished attending this class. '
          'You can then write a review or request a refund.',
      confirmLabel: 'Yes, I completed it',
      confirmColor: const Color(0xFF4CAF50),
    );
    if (!ok) return;

    setState(() => _busy = true);
    final result = await ApiService.completeBooking(_booking.id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result['success'] == true) {
      _showSnack('Class marked as completed');
      Navigator.pop(context, true);
    } else {
      _showSnack(result['error']?.toString() ?? 'Failed');
    }
  }

  Future<void> _openReview() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewBookingScreen(
          bookingId: _booking.id,
          classTitle: _booking.cookingClass.title,
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _openRefundRequest() async {
    if (!_booking.canRefund) {
      _showSnack('Refund is not available for this booking.');
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RefundRequestScreen(booking: _booking),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _openRefundResponse() async {
    final refundId = _booking.latestRefund?['id'];
    if (refundId == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RefundResponseScreen(refundId: refundId.toString()),
      ),
    );
    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              confirmLabel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cls = _booking.cookingClass;
    final totalPrice = cls.price * _booking.quantity;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B4C2A)),
        ),
        title: Text(
          widget.isInstructorView ? 'Order Detail' : 'Booking Detail',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(cls),
                const SizedBox(height: 16),
                _buildStatusSection(),
                const SizedBox(height: 16),
                _buildClassInfo(cls),
                const SizedBox(height: 16),
                if (cls.dishes.isNotEmpty) _buildDishesSection(cls),
                if (cls.certificates.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCertificatesSection(cls),
                ],
                const SizedBox(height: 16),
                _buildPaymentSummary(cls, totalPrice),
                const SizedBox(height: 16),
                if (_booking.latestRefund != null) _buildRefundSection(),
                const SizedBox(height: 24),
                _buildActionButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB347)),
              ),
            ),
        ],
      ),
    );
  }

  // ============ Action buttons (unified, no bottom bar) ============

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    if (widget.isInstructorView) {
      // Instructor: only Cancel (before cutoff)
      if (_booking.canCancel) {
        buttons.add(SoftButton(
          label: 'Cancel Booking',
          onPressed: _busy ? null : _cancelBooking,
          textColor: Colors.red,
          icon: Icons.cancel_outlined,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: 14),
          fontSize: 14,
        ));
      }
    } else {
      // Customer: Cancel / Complete / Refund / Review (mutually exclusive phases)
      if (_booking.canCancel) {
        buttons.add(SoftButton(
          label: 'Cancel Booking',
          onPressed: _busy ? null : _cancelBooking,
          textColor: Colors.red,
          icon: Icons.cancel_outlined,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: 14),
          fontSize: 14,
        ));
      }
      if (_booking.canComplete) {
        buttons.add(SoftButton(
          label: 'Confirm Completed',
          onPressed: _busy ? null : _markCompleted,
          textColor: const Color(0xFF4CAF50),
          icon: Icons.done_all,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: 14),
          fontSize: 14,
        ));
      }
      if (_booking.canRefund) {
        buttons.add(SoftButton(
          label: 'Request Refund',
          onPressed: _busy ? null : _openRefundRequest,
          textColor: const Color(0xFFFFB347),
          icon: Icons.assignment_return_outlined,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: 14),
          fontSize: 14,
        ));
      }
      if (_booking.canReview) {
        buttons.add(SoftButton(
          label: 'Write a Review',
          onPressed: _busy ? null : _openReview,
          textColor: const Color(0xFFFFB347),
          icon: Icons.star_outline,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: 14),
          fontSize: 14,
        ));
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: buttons
          .map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: b,
              ))
          .toList(),
    );
  }

  // ============ Sections ============

  Widget _buildHeader(CookingClassModel cls) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: ApiService.resolveImageUrl(cls.image),
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 90,
                height: 90,
                color: const Color(0xFFFFF0B5),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: const Color(0xFFFFD966),
                child: const Icon(Icons.restaurant, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isInstructorView
                      ? 'Customer: ${_booking.username}'
                      : cls.instructor.shopName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Booking #${_booking.id}',
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
    );
  }

  Widget _buildStatusSection() {
    final status = widget.isInstructorView
        ? _booking.displayStatusForInstructor
        : _booking.displayStatus;
    final color = _statusColor(status);
    final label = _statusLabel(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(status), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _statusHint(status),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassInfo(CookingClassModel cls) {
    return _card(
      title: 'Class Information',
      children: [
        _infoRow(Icons.calendar_today, 'Date', _formatDate(_booking.date)),
        if (_booking.startTime != null)
          _infoRow(
              Icons.access_time,
              'Time',
              '${_booking.startTime}'
                  '${_booking.endTime != null ? ' - ${_booking.endTime}' : ''}'),
        _infoRow(Icons.people, 'People', '${_booking.quantity} pax'),
        if (cls.location.isNotEmpty)
          _infoRow(Icons.location_on, 'Location', cls.location),
        if (cls.schedule.isNotEmpty)
          _infoRow(Icons.schedule, 'Schedule', cls.schedule),
        _infoRow(Icons.local_offer, 'Instructor', cls.instructor.shopName),
        if (cls.tags.isNotEmpty)
          _infoRow(Icons.label, 'Tags', cls.tags.join(', ')),
        if (cls.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            cls.description,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF6B4C2A).withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDishesSection(CookingClassModel cls) {
    return _card(
      title: "What You'll Learn",
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cls.dishes.map((dish) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: Color(0xFFFFB347)),
                  const SizedBox(width: 6),
                  Text(dish, style: GoogleFonts.poppins(fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCertificatesSection(CookingClassModel cls) {
    return _card(
      title: "What You'll Get",
      children: cls.certificates.map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 8),
                child: Icon(Icons.emoji_events,
                    size: 16, color: Color(0xFFFFB347)),
              ),
              Expanded(
                child: Text(c, style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentSummary(CookingClassModel cls, double totalPrice) {
    final paid = _booking.paymentStatus == 'paid';
    final refunded = _booking.paymentStatus == 'refunded';
    return _card(
      title: 'Payment Summary',
      children: [
        _kvRow('Price per pax', 'RM ${cls.price.toStringAsFixed(2)}'),
        _kvRow('Quantity', '× ${_booking.quantity}'),
        const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFFFFF0B5)),
        const SizedBox(height: 8),
        _kvRow(
          'Total',
          'RM ${totalPrice.toStringAsFixed(2)}',
          valueBold: true,
          valueColor: const Color(0xFFFFB347),
        ),
        const SizedBox(height: 8),
        _kvRow(
          'Payment status',
          refunded
              ? 'Refunded'
              : (paid ? 'Paid' : 'Unpaid'),
          valueColor: refunded
              ? Colors.blue
              : (paid ? Colors.green : Colors.orange),
        ),
        if (_booking.paymentCard != null)
          _kvRow(
            'Payment method',
            '${_booking.paymentCard!.brandDisplay} ****${_booking.paymentCard!.last4}',
          ),
      ],
    );
  }

  Widget _buildRefundSection() {
    final refund = _booking.latestRefund!;
    final status = refund['status']?.toString() ?? '';
    final refundAmount = refund['refund_amount'];
    final canInstructorRespond = refund['can_instructor_respond'] == true;

    return _card(
      title: 'Refund',
      children: [
        _kvRow('Status', _refundStatusLabel(status)),
        if (refundAmount != null)
          _kvRow(
            'Refund amount',
            'RM ${double.tryParse('$refundAmount')?.toStringAsFixed(2) ?? '0.00'}',
            valueColor: const Color(0xFFFFB347),
            valueBold: true,
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: SoftButton(
            label: widget.isInstructorView
                ? (canInstructorRespond
                    ? 'Respond to Refund'
                    : 'View refund details')
                : 'View refund details',
            onPressed: _openRefundResponse,
            textColor: const Color(0xFFFFB347),
            icon: Icons.receipt_long,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ============ Small widgets ============

  Widget _card({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFFB347)),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
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
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(
    String key,
    String value, {
    bool valueBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFC9A96E),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? const Color(0xFF6B4C2A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year} '
        '(${weekdays[d.weekday - 1]})';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'pending_refund':
        return Colors.purple;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'refunded':
        return Colors.blueGrey;
      case 'reviewed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'pending_refund':
        return Icons.assignment_return;
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'refunded':
        return Icons.assignment_return_outlined;
      case 'reviewed':
        return Icons.star;
      default:
        return Icons.info_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return widget.isInstructorView
            ? 'Awaiting Your Confirmation'
            : 'Awaiting Confirmation';
      case 'pending_refund':
        return 'Refund In Progress';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'refunded':
        return 'Refunded';
      case 'reviewed':
        return 'Reviewed';
      default:
        return status;
    }
  }

  String _statusHint(String status) {
    switch (status) {
      case 'pending':
        return widget.isInstructorView
            ? 'Accept or cancel this booking'
            : 'The instructor will confirm your booking shortly';
      case 'pending_refund':
        return 'Waiting for the instructor to respond';
      case 'confirmed':
        return 'Please confirm your attendance after the class ends';
      case 'completed':
        return 'Thank you for attending!';
      case 'cancelled':
        return 'This booking has been cancelled';
      case 'refunded':
        return 'This booking has been refunded';
      case 'reviewed':
        return 'Thank you for your review';
      default:
        return '';
    }
  }

  String _refundStatusLabel(String status) {
    const map = {
      'pending_instructor': 'Waiting for instructor',
      'pending_admin': 'Waiting for admin review',
      'resolved_full': 'Full refund approved',
      'resolved_half': 'Half refund approved',
      'resolved_none': 'Refund rejected',
    };
    return map[status] ?? status;
  }
}