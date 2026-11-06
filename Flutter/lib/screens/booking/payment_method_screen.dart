// screens/booking/payment_method_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import 'add_card_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String bookingId;
  final String classTitle;
  final String instructorName;
  final double pricePerPax;
  final int quantity;
  final String dateStr;
  final String timeRange;

  const PaymentMethodScreen({
    super.key,
    required this.bookingId,
    required this.classTitle,
    required this.instructorName,
    required this.pricePerPax,
    required this.quantity,
    required this.dateStr,
    required this.timeRange,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  List<PaymentCard> _cards = [];
  String? _selectedCardId;
  bool _loading = true;
  bool _paying = false;
  bool _paid = false;

  double get _totalPrice => widget.pricePerPax * widget.quantity;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _loading = true);
    final result = await ApiService.getPaymentCards();
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => PaymentCard.fromJson(e))
          .toList();
      setState(() {
        _cards = list;
        _loading = false;
        if (list.isNotEmpty) {
          final def = list.firstWhere(
            (c) => c.isDefault,
            orElse: () => list.first,
          );
          _selectedCardId = def.id;
        } else {
          _selectedCardId = null;
        }
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCard(PaymentCard card) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete card?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Remove ${card.brandDisplay} ****${card.last4}?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await ApiService.deletePaymentCard(card.id);
    if (!mounted) return;
    if (result['success'] == true) {
      _loadCards();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed to delete')),
      );
    }
  }

  Future<void> _addCard() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );
    if (added == true) {
      _loadCards();
    }
  }

  // Called when the user tries to leave without paying.
  Future<void> _handleExit() async {
    if (!_paid) {
      await ApiService.cancelUnpaidBooking(widget.bookingId);
    }
    if (mounted) Navigator.pop(context, _paid);
  }

  Future<void> _pay() async {
    if (_selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a card')),
      );
      return;
    }
    setState(() => _paying = true);

    final result = await ApiService.payBooking(
      bookingId: widget.bookingId,
      cardId: _selectedCardId!,
    );

    if (!mounted) return;
    setState(() => _paying = false);

    if (result['success'] == true) {
      _paid = true;
      Navigator.pop(context, true);
      return;
    }

    final errorMsg = result['error']?.toString() ?? 'Payment failed';

    // Someone else grabbed the last seat.
    if (errorMsg.contains('just taken')) {
      await ApiService.cancelUnpaidBooking(widget.bookingId);
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Slot no longer available',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Another user just took the last seat. '
            'Please pick a different time slot.',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, false);
              },
              child: Text(
                'OK',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFB347),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMsg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: _handleExit,
            icon: const Icon(Icons.arrow_back),
            color: const Color(0xFF6B4C2A),
          ),
          title: Text(
            'Payment Method',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB347)),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Summary',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6B4C2A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.classTitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF6B4C2A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.instructorName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFFC9A96E),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 14,
                                        color: Color(0xFFFFB347)),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.dateStr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 14,
                                        color: Color(0xFFFFB347)),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.timeRange,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.people,
                                        size: 14,
                                        color: Color(0xFFFFB347)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${widget.quantity} pax',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'RM ${widget.pricePerPax.toStringAsFixed(0)} × ${widget.quantity}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFFC9A96E),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                    ),
                                    Text(
                                      'RM ${_totalPrice.toStringAsFixed(0)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFFB347),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Select Card',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6B4C2A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_cards.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.credit_card_off,
                                      size: 40, color: Color(0xFFC9A96E)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No saved card yet',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF6B4C2A),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._cards.map((card) => _buildCardTile(card)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _addCard,
                            icon: const Icon(Icons.add,
                                color: Color(0xFFFFB347)),
                            label: Text(
                              'Add New Card',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFB347),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              side: const BorderSide(
                                  color: Color(0xFFFFB347)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: ElevatedButton(
                        onPressed:
                            (_paying || _cards.isEmpty) ? null : _pay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB347),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _paying
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Pay RM ${_totalPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCardTile(PaymentCard card) {
    final selected = _selectedCardId == card.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCardId = card.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFFFB347) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Radio<String>(
              value: card.id,
              groupValue: _selectedCardId,
              activeColor: const Color(0xFFFFB347),
              onChanged: (v) => setState(() => _selectedCardId = v),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        card.brandDisplay,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C2A),
                        ),
                      ),
                      if (card.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB347)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFFFB347),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.maskedNumber,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A).withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'Expires ${card.expiry}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFC9A96E),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _deleteCard(card),
              icon:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}