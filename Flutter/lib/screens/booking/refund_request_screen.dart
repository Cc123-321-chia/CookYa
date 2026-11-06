// screens/booking/refund_request_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import '../../widgets/soft_button.dart';

class RefundRequestScreen extends StatefulWidget {
  final BookingModel booking;

  const RefundRequestScreen({super.key, required this.booking});

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  final _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedReason;
  File? _image;
  bool _submitting = false;

  final _reasons = <Map<String, String>>[
    {'value': 'not_as_described', 'label': 'Class not as described'},
    {'value': 'instructor_no_show', 'label': 'Instructor did not show up'},
    {'value': 'quality_issue', 'label': 'Poor quality / not satisfied'},
    {'value': 'personal_emergency', 'label': 'Personal emergency'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a reason'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final result = await ApiService.requestRefund(
      bookingId: widget.booking.id,
      reason: _selectedReason!,
      note: _noteController.text.trim(),
      image: _image,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Refund request submitted. The instructor will respond within 24 hours.'),
          backgroundColor: Color(0xFF4CAF50),
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
    final cls = widget.booking.cookingClass;
    final totalPrice = cls.price * widget.booking.quantity;

    // Guard: show blocked state if refund is not allowed
    if (!widget.booking.canRefund) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          title: Text(
            'Request Refund',
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
            icon: const Icon(Icons.close, color: Color(0xFF6B4C2A)),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 64,
                  color: Color(0xFFFFB347),
                ),
                const SizedBox(height: 16),
                Text(
                  'Refund not available',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.booking.hasActiveRefund
                      ? 'A refund request is already in progress for this booking.'
                      : widget.booking.hasResolvedRefund
                          ? 'This booking already has a refund on record.'
                          : 'You can request a refund only after the class has ended and you have marked it as completed.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFFC9A96E),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Request Refund',
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
          icon: const Icon(Icons.close, color: Color(0xFF6B4C2A)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: ApiService.resolveImageUrl(cls.image),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 64,
                        height: 64,
                        color: const Color(0xFFFFF0B5),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
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
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF6B4C2A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cls.instructor.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFC9A96E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 12, color: Color(0xFFFFB347)),
                            const SizedBox(width: 4),
                            Text(
                              widget.booking.date,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFFC9A96E),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.people,
                                size: 12, color: Color(0xFFFFB347)),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.booking.quantity} pax',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
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
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD966).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Refund Amount',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  Text(
                    'RM ${totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFB347),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reason selection
            Text(
              'Reason for Refund',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 8),
            ..._reasons.map((r) {
              final selected = _selectedReason == r['value'];
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = r['value']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF5E6) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFB347)
                          : Colors.grey.shade200,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: selected
                            ? const Color(0xFFFFB347)
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r['label']!,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF6B4C2A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
            Text(
              'Description (optional)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 4,
              style: GoogleFonts.poppins(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Explain the issue in detail...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white,
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
                  borderSide:
                      const BorderSide(color: Color(0xFFFFB347), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Photo Evidence (optional)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
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
                  color: Colors.white,
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

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB347),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Submit Refund Request',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Once submitted, this request cannot be edited or re-submitted. '
              'The instructor will respond within 24 hours.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFC9A96E),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}