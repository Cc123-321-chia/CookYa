// screens/booking/provider_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import 'booking_detail_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  final String? instructorId;

  const ProviderProfileScreen({super.key, this.instructorId});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  InstructorProfile? _profile;
  List<CookingClassModel> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Map<String, dynamic> result;

    if (widget.instructorId != null) {
      result = await ApiService.getInstructorProfileDetail(widget.instructorId!);
      if (result['success'] == true) {
        final data = result['data'];
        _profile = InstructorProfile.fromJson(data['profile']);
        _classes = (data['classes'] as List)
            .map((e) => CookingClassModel.fromJson(e))
            .toList();
      }
    } else {
      result = await ApiService.getMyInstructorProfile();
      if (result['success'] == true) {
        _profile = InstructorProfile.fromJson(result['data']);
        final detail = await ApiService.getInstructorProfileDetail(
          _profile!.id,
        );
        if (detail['success'] == true) {
          _classes = (detail['data']['classes'] as List)
              .map((e) => CookingClassModel.fromJson(e))
              .toList();
        }
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF9E6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            'Shop',
            style: GoogleFonts.poppins(color: const Color(0xFF6B4C2A)),
          ),
        ),
        body: Center(
          child: Text(
            'No profile',
            style: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6B4C2A)),
        title: Text(
          _profile!.shopName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar section — no cover banner, centered layout
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: const Color(0xFFFFD966),
                    backgroundImage: _profile!.avatar.isNotEmpty
                        ? CachedNetworkImageProvider(
                            ApiService.resolveImageUrl(_profile!.avatar),
                          )
                        : null,
                    child: _profile!.avatar.isEmpty
                        ? const Icon(Icons.store,
                            color: Colors.white, size: 48)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profile!.shopName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _profile!.isApproved
                            ? Icons.verified
                            : Icons.hourglass_top,
                        size: 16,
                        color: _profile!.isApproved
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _profile!.isApproved ? 'Verified' : 'Pending',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _profile!.isApproved
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_profile!.description.isNotEmpty) ...[
                    Text(
                      _profile!.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF6B4C2A).withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _infoRow(Icons.location_on, _profile!.address),
                  const SizedBox(height: 8),
                  _infoRow(Icons.phone, _profile!.phone),
                  const SizedBox(height: 8),
                  _infoRow(Icons.email, _profile!.email),
                  const SizedBox(height: 24),

                  if (_profile!.complianceDocuments.isNotEmpty) ...[
                    _sectionTitle('Compliance Documents'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _profile!.complianceDocuments.length,
                        itemBuilder: (context, i) {
                          final doc = _profile!.complianceDocuments[i];
                          return GestureDetector(
                            onTap: () => _showDocument(doc.key, doc.value),
                            child: Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          const BorderRadius.vertical(
                                              top: Radius.circular(12)),
                                      child: CachedNetworkImage(
                                        imageUrl: ApiService.resolveImageUrl(
                                            doc.value),
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: const Color(0xFFFFF0B5),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: const Color(0xFFFFF0B5),
                                          child: const Icon(
                                            Icons.description,
                                            color: Color(0xFFFFB347),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      doc.key,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  _sectionTitle('Classes (${_classes.length})'),
                  const SizedBox(height: 12),
                  if (_classes.isEmpty)
                    Text(
                      'No classes yet',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFC9A96E),
                        fontSize: 13,
                      ),
                    )
                  else
                    ..._classes.map((c) => _buildClassCard(c)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF6B4C2A),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFFB347)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF6B4C2A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(CookingClassModel c) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              classItem: c,
              isOwnClass: widget.instructorId == null,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ApiService.resolveImageUrl(c.image),
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.priceDisplay,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFB347),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocument(String label, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                  imageUrl: ApiService.resolveImageUrl(url),
                  fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}