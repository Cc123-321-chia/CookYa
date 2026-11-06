// screens/booking/saved_bookings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import '../../widgets/soft_button.dart';
import 'booking_detail_screen.dart';
import 'booking_order_detail_screen.dart';

class SavedBookingsScreen extends StatefulWidget {
  const SavedBookingsScreen({super.key});

  @override
  State<SavedBookingsScreen> createState() => _SavedBookingsScreenState();
}

class _SavedBookingsScreenState extends State<SavedBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<CookingClassModel> _savedClasses = [];
  List<BookingModel> _bookedClasses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final savedRes = await ApiService.getMySavedClasses();
    final bookedRes = await ApiService.getMyBookings();

    if (!mounted) return;

    setState(() {
      if (savedRes['success'] == true) {
        _savedClasses = (savedRes['data'] as List)
            .map((e) => CookingClassModel.fromJson(e))
            .toList();
      }
      if (bookedRes['success'] == true) {
        _bookedClasses = (bookedRes['data'] as List)
            .map((e) => BookingModel.fromJson(e))
            .toList();
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'My Bookings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite,
                      size: 18, color: Color(0xFFFFB347)),
                  const SizedBox(width: 8),
                  Text(
                    'Saved (${_savedClasses.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available,
                      size: 18, color: Color(0xFFFFB347)),
                  const SizedBox(width: 8),
                  Text(
                    'Booked (${_bookedClasses.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          indicatorColor: const Color(0xFFFFB347),
          labelColor: const Color(0xFF6B4C2A),
          unselectedLabelColor: const Color(0xFFC9A96E),
          dividerColor: Colors.transparent,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSavedList(),
                _buildBookedList(),
              ],
            ),
    );
  }

  // ==================== SAVED TAB ====================

  Widget _buildSavedList() {
    if (_savedClasses.isEmpty) {
      return _buildEmpty(
        icon: Icons.favorite_border,
        title: 'No saved classes yet',
        subtitle: 'Start exploring and save your favorites!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedClasses.length,
      itemBuilder: (context, index) {
        final classItem = _savedClasses[index];
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailScreen(
                  classItem: classItem,
                  isOwnClass:
                      ApiService.isMyClass(classItem.instructor.userId),
                ),
              ),
            );
            _load();
          },
          child: _buildSavedCard(classItem),
        );
      },
    );
  }

  Widget _buildSavedCard(CookingClassModel classItem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: ApiService.resolveImageUrl(classItem.image),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 80,
                height: 80,
                color: const Color(0xFFFFF0B5),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 80,
                height: 80,
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
                  classItem.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  classItem.instructor.shopName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 12, color: Color(0xFFFFB347)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        classItem.location,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFC9A96E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      classItem.priceDisplay,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFFB347),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.favorite, size: 12, color: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'Saved',
                      style: TextStyle(fontSize: 11, color: Colors.red),
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

  // ==================== BOOKED TAB ====================

  Widget _buildBookedList() {
    if (_bookedClasses.isEmpty) {
      return _buildEmpty(
        icon: Icons.event_busy,
        title: 'No bookings yet',
        subtitle: 'Book your first cooking class today!',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFFB347),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookedClasses.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(_bookedClasses[index]);
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingModel booking) {
    final cls = booking.cookingClass;
    final total = cls.price * booking.quantity;

    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BookingOrderDetailScreen(booking: booking),
          ),
        );
        if (changed == true) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: ApiService.resolveImageUrl(cls.image),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFFFF0B5),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFFFD966),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                cls.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B4C2A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusChip(booking.displayStatus),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cls.instructor.shopName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFFC9A96E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _metaRow(
                          Icons.calendar_today,
                          _formatDate(booking.date) +
                              (booking.startTime != null
                                  ? ' · ${booking.startTime}'
                                  : ''),
                        ),
                        const SizedBox(height: 2),
                        _metaRow(
                          Icons.people,
                          '${booking.quantity} pax · RM ${total.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF9E6),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'View detail',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB347),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Color(0xFFFFB347),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SHARED ====================

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: const Color(0xFFFFB347)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFC9A96E),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    final label = _statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'reviewed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'reviewed':
        return 'Reviewed';
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: const Color(0xFFFFB347).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFFC9A96E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFFC9A96E).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Browse Classes'),
          ),
        ],
      ),
    );
  }
}