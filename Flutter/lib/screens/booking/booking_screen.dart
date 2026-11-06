// screens/booking/booking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import 'booking_detail_screen.dart';
import 'saved_bookings_screen.dart';
import 'instructor_orders_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCountry = 'All Locations';
  String _selectedCity = 'All Cities';
  DateTime? _selectedDate;

  List<CookingClassModel> _allClasses = [];
  List<CookingClassModel> _filteredClasses = [];
  bool _isCulinaryInstructor = false;
  bool _loading = true;

  final List<String> _countries = [
    'All Locations', 'Thailand', 'Malaysia', 'Singapore', 'Indonesia',
    'Vietnam', 'Japan', 'China', 'Italy', 'France', 'South Korea', 'India',
  ];

  final Map<String, List<String>> _cities = {
    'All Locations': ['All Cities'],
    'Thailand': ['All Cities', 'Bangkok', 'Chiang Mai', 'Phuket', 'Pattaya'],
    'Malaysia': ['All Cities', 'Penang', 'Kuala Lumpur', 'Johor Bahru', 'Kedah', 'Malacca', 'Sabah', 'Sarawak'],
    'Singapore': ['All Cities', 'Singapore'],
    'Indonesia': ['All Cities', 'Bali', 'Jakarta', 'Yogyakarta'],
    'Vietnam': ['All Cities', 'Hanoi', 'Ho Chi Minh City', 'Da Nang'],
    'Japan': ['All Cities', 'Tokyo', 'Osaka', 'Kyoto', 'Fukuoka'],
    'China': ['All Cities', 'Hong Kong', 'Beijing', 'Shanghai', 'Guangzhou'],
    'Italy': ['All Cities', 'Rome', 'Milan', 'Florence', 'Venice'],
    'France': ['All Cities', 'Paris', 'Lyon', 'Marseille'],
    'South Korea': ['All Cities', 'Seoul', 'Busan', 'Jeju'],
    'India': ['All Cities', 'Mumbai', 'Delhi', 'Kerala', 'Goa'],
  };

  @override
  void initState() {
    super.initState();
    _isCulinaryInstructor = ApiService.currentUserIsCulinaryInstructor;
    _loadClasses();
    _refreshUserRole();
  }

  Future<void> _refreshUserRole() async {
    final result = await ApiService.getProfile();
    if (result['success'] == true) {
      ApiService.setCurrentUser(result['user']);
      if (!mounted) return;
      setState(() {
        _isCulinaryInstructor = result['user']['is_culinary_instructor'] == true;
      });
    }
  }

  Future<void> _loadClasses() async {
    setState(() => _loading = true);
    final result = await ApiService.getCookingClasses();
    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => CookingClassModel.fromJson(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _allClasses = list;
        _filteredClasses = list;
      });
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _filterClasses() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredClasses = _allClasses.where((classItem) {
        bool matchesSearch = true;
        if (query.isNotEmpty) {
          matchesSearch =
              classItem.title.toLowerCase().contains(query) ||
              classItem.description.toLowerCase().contains(query) ||
              classItem.location.toLowerCase().contains(query) ||
              classItem.instructor.shopName.toLowerCase().contains(query) ||
              classItem.tags.any((t) => t.toLowerCase().contains(query)) ||
              classItem.dishes.any((d) => d.toLowerCase().contains(query)) ||
              classItem.certificates.any((c) => c.toLowerCase().contains(query));
        }

        final matchesCountry = _selectedCountry == 'All Locations' ||
            classItem.location.contains(_selectedCountry);

        final matchesCity = _selectedCity == 'All Cities' ||
            classItem.location.contains(_selectedCity);

        return matchesSearch && matchesCountry && matchesCity;
      }).toList();
    });
  }

  void _goToMyBookings() {
    if (_isCulinaryInstructor) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InstructorOrdersScreen()),
      ).then((_) => _loadClasses());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SavedBookingsScreen()),
      ).then((_) => _loadClasses());
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> getCities() => _cities[_selectedCountry] ?? ['All Cities'];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Cooking Classes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _goToMyBookings,
            icon: Icon(_isCulinaryInstructor
                ? Icons.receipt_long
                : Icons.event_available),
            color: const Color(0xFFC9A96E),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFFFD966).withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _filterClasses(),
                    decoration: InputDecoration(
                      hintText: 'Search classes...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFFFB347)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFD966).withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountry,
                            isExpanded: true,
                            icon: const Icon(Icons.public, color: Color(0xFFFFB347), size: 18),
                            items: _countries.map((String location) {
                              return DropdownMenuItem<String>(
                                value: location,
                                child: Text(
                                  location,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedCountry = value!;
                                _selectedCity = 'All Cities';
                                _filterClasses();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFD966).withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCity,
                            isExpanded: true,
                            icon: const Icon(Icons.location_city, color: Color(0xFFFFB347), size: 18),
                            items: getCities().map((String city) {
                              return DropdownMenuItem<String>(
                                value: city,
                                child: Text(
                                  city,
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedCity = value!;
                                _filterClasses();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDate = date;
                            });
                          }
                        },
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFFD966).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFFFFB347), size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedDate == null
                                      ? 'Select Date'
                                      : '${_selectedDate!.day}/${_selectedDate!.month}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: _selectedDate == null
                                        ? Colors.grey.shade400
                                        : const Color(0xFF6B4C2A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB347)),
                  )
                : _filteredClasses.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Color(0xFFFFB347)),
                            SizedBox(height: 16),
                            Text(
                              'No classes found',
                              style: TextStyle(fontSize: 16, color: Color(0xFFC9A96E)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadClasses,
                        color: const Color(0xFFFFB347),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredClasses.length,
                          itemBuilder: (context, index) {
                            return _buildClassCard(_filteredClasses[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(CookingClassModel classItem) {
    Color getTagColor(String tag) {
      switch (tag) {
        case 'In-Person':
          return const Color(0xFF6C5CE7);
        case 'Home Visit':
          return const Color(0xFFFFB347);
        default:
          return const Color(0xFFC9A96E);
      }
    }

    final isOwnClass = ApiService.isMyClass(classItem.instructor.userId);
    final imageUrl = ApiService.resolveImageUrl(classItem.image);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              classItem: classItem,
              isOwnClass: isOwnClass,
            ),
          ),
        );
        // 🔥 返回后刷新，star / rating 更新
        _loadClasses();
      },
      // 🔥 卡片内左右两栏高度一致
      child: IntrinsicHeight(
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,  // 🔥 关键：两栏拉伸同高
            children: [
              // 🔥 图片：宽度固定 120，高度自动撑满 Row
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: SizedBox(
                  width: 120,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,   // 🔥 用 cover 撑满，不留白
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFFFF0B5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFB347),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFFFD966),
                      child: const Icon(Icons.restaurant, color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              classItem.title,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 12, color: Color(0xFFFFB347)),
                                const SizedBox(width: 2),
                                Text(
                                  classItem.location.split(',').first,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(0xFFC9A96E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classItem.instructor.shopName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFC9A96E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (classItem.tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: classItem.tags.take(2).map((tag) {
                            final color = getTagColor(tag);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: GoogleFonts.poppins(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: classItem.dishes.take(3).map((dish) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              dish,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                color: const Color(0xFFC9A96E),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      if (classItem.schedule.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Color(0xFFC9A96E)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                classItem.schedule,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF6B4C2A).withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          if (!classItem.isAvailable) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB347).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Booked',
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFFB347),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 12, color: Color(0xFFFFB347)),
                              const SizedBox(width: 2),
                              Text(
                                classItem.rating.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6B4C2A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}