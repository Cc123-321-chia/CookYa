// screens/booking/manage_classes_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import 'add_edit_class_screen.dart';
import 'manage_availability_screen.dart';

class ManageClassesScreen extends StatefulWidget {
  const ManageClassesScreen({super.key});

  @override
  State<ManageClassesScreen> createState() => _ManageClassesScreenState();
}

class _ManageClassesScreenState extends State<ManageClassesScreen> {
  List<CookingClassModel> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profileRes = await ApiService.getMyInstructorProfile();
    if (profileRes['success'] == true) {
      final profileId = profileRes['data']['id'].toString();
      final classRes = await ApiService.getInstructorProfileDetail(profileId);
      if (classRes['success'] == true) {
        final list = (classRes['data']['classes'] as List)
            .map((e) => CookingClassModel.fromJson(e))
            .toList();
        if (!mounted) return;
        setState(() {
          _classes = list;
          _loading = false;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _deleteClass(CookingClassModel cls) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Class?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${cls.title}"?',
          style: GoogleFonts.poppins(),
        ),
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

    final result = await ApiService.deleteClass(classId: cls.id);
    if (!mounted) return;

    if (result['success'] == true) {
      _load();
    } else if (result['bookings_count'] != null) {
      final force = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Upcoming Bookings',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            '${result['bookings_count']} upcoming booking(s) will be cancelled and refunded.\n\n'
            'This may cause bad reviews. Continue?',
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
        final forceResult = await ApiService.deleteClass(
          classId: cls.id,
          force: true,
        );
        if (forceResult['success'] == true) _load();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Manage Classes',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
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
          : _classes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu,
                          size: 64, color: Color(0xFFFFD966)),
                      const SizedBox(height: 16),
                      Text(
                        'No classes yet',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFC9A96E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first class to start accepting bookings',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFC9A96E),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _classes.length,
                  itemBuilder: (context, index) {
                    final cls = _classes[index];
                    return _buildClassCard(cls);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditClassScreen(),
            ),
          );
          if (created == true) _load();
        },
        backgroundColor: const Color(0xFFFFB347),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Add Class',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildClassCard(CookingClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: CachedNetworkImage(
              imageUrl: cls.image,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 140,
                color: const Color(0xFFFFF0B5),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB347)),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                height: 140,
                color: const Color(0xFFFFD966),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B4C2A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cls.priceDisplay,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFB347),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${cls.availabilities.length} availability group(s)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFC9A96E),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageAvailabilityScreen(
                                cookingClass: cls,
                              ),
                            ),
                          );
                          if (changed == true) _load();
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          'Availability',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFB347),
                          side: const BorderSide(color: Color(0xFFFFB347)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditClassScreen(
                                existingClass: cls,
                              ),
                            ),
                          );
                          if (updated == true) _load();
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(
                          'Edit',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B4C2A),
                          side: const BorderSide(color: Color(0xFFC9A96E)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _deleteClass(cls),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
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
}