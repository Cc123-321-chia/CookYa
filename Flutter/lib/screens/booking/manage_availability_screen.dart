// screens/booking/manage_availability_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import 'add_availability_screen.dart';

class ManageAvailabilityScreen extends StatefulWidget {
  final CookingClassModel cookingClass;

  const ManageAvailabilityScreen({super.key, required this.cookingClass});

  @override
  State<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends State<ManageAvailabilityScreen> {
  List<ClassAvailability> _avails = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.getAvailabilities(widget.cookingClass.id);
    if (!mounted) return;
    if (result['success'] == true) {
      final list = (result['data'] as List)
          .map((e) => ClassAvailability.fromJson(e))
          .toList();
      setState(() {
        _avails = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteAvailability(ClassAvailability avail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Availability?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'Delete ${avail.startDate} ~ ${avail.endDate}?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await ApiService.deleteAvailability(
      availabilityId: avail.id,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      _load();
    } else if (result['bookings_count'] != null) {
      final force = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Upcoming Bookings',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text(
            '${result['bookings_count']} upcoming booking(s) will be cancelled '
            'and refunded.\n\nThis may cause bad reviews. Continue?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete Anyway',
                  style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        ),
      );
      if (force == true) {
        final forceResult = await ApiService.deleteAvailability(
          availabilityId: avail.id,
          force: true,
        );
        if (forceResult['success'] == true) _load();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed')),
      );
    }
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAvailabilityScreen(
          cookingClass: widget.cookingClass,
        ),
      ),
    );
    if (added == true) _load();
  }

  Future<void> _openEdit(ClassAvailability avail) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAvailabilityScreen(
          cookingClass: widget.cookingClass,
          existingAvailability: avail,
        ),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Availability',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)))
          : _avails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 64, color: Color(0xFFFFD966)),
                      const SizedBox(height: 16),
                      Text('No availability set',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFFC9A96E))),
                      const SizedBox(height: 8),
                      Text('Add availability so customers can book',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: const Color(0xFFC9A96E))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _avails.length,
                  itemBuilder: (context, index) {
                    return _buildAvailCard(_avails[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: const Color(0xFFFFB347),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add Availability',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAvailCard(ClassAvailability avail) {
    return GestureDetector(
      onTap: () => _openEdit(avail),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${avail.startDate} ~ ${avail.endDate}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C2A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        avail.isDailySame
                            ? 'Same every day'
                            : 'Different by day',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: const Color(0xFFC9A96E)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openEdit(avail),
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFFFFB347)),
                ),
                IconButton(
                  onPressed: () => _deleteAvailability(avail),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...avail.slots.map((slot) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: Color(0xFFFFB347)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slot.dayOfWeek != null
                            ? '${_dayName(slot.dayOfWeek!)} ${slot.timeRange}'
                            : slot.timeRange,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: const Color(0xFF6B4C2A)),
                      ),
                    ),
                    Text(
                      '${slot.maxSlots} slots',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFFC9A96E)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _dayName(int dow) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (dow >= 0 && dow < 7) return names[dow];
    return '';
  }
}