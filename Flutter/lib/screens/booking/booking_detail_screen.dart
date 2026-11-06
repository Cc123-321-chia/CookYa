// screens/booking/booking_detail_screen.dart
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';
import '../mentor-mentee/chat_detail_screen.dart';
import 'add_edit_class_screen.dart';
import 'provider_profile_screen.dart';
import 'booking_reviews_screen.dart';
import 'payment_method_screen.dart';
import 'date_time_picker_sheet.dart';
import 'fullscreen_video_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final CookingClassModel classItem;
  final bool isOwnClass;

  const BookingDetailScreen({
    super.key,
    required this.classItem,
    this.isOwnClass = false,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isSaved = false;
  int _currentMediaIndex = 0;

  List<String> get _allImages {
    final images = <String>[];
    if (widget.classItem.image.isNotEmpty) images.add(widget.classItem.image);
    images.addAll(widget.classItem.images);
    return images;
  }

  bool get _isInstructor => ApiService.currentUserIsCulinaryInstructor;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.classItem.isSaved;
  }

  Future<void> _toggleSave() async {
    final result = await ApiService.toggleSaveClass(widget.classItem.id);
    if (result['success'] == true) {
      setState(() => _isSaved = result['saved'] == true);
    }
  }

  Future<void> _onBookNow() async {
    final result = await showDateTimePickerSheet(
      context: context,
      classItem: widget.classItem,
    );
    if (result == null) return;

    final dateStr =
        '${result.date.year}-${result.date.month.toString().padLeft(2, '0')}-${result.date.day.toString().padLeft(2, '0')}';

    final apiResult = await ApiService.createBooking(
      classId: widget.classItem.id,
      date: dateStr,
      slotId: result.slot.id,
      quantity: result.quantity,
    );

    if (!mounted) return;

    if (apiResult['success'] != true) {
      _showErrorDialog(apiResult['error'] ?? 'Failed to book');
      return;
    }

    final bookingData = apiResult['data'];
    final bookingId = bookingData['id'].toString();

    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          bookingId: bookingId,
          classTitle: widget.classItem.title,
          instructorName: widget.classItem.instructor.shopName,
          pricePerPax: widget.classItem.price,
          quantity: result.quantity,
          dateStr:
              '${result.date.day}/${result.date.month}/${result.date.year}',
          timeRange: result.slot.timeRange,
        ),
      ),
    );

    if (!mounted) return;

    if (paid == true) {
      _showBookingConfirmationDialog(
        date: result.date,
        slot: result.slot,
        quantity: result.quantity,
      );
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Booking Failed',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(msg, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // ---------- Customer service: chat with instructor ----------
  void _openChatWithInstructor() {
    final instructor = widget.classItem.instructor;
    if (instructor.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open chat: instructor not found.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          otherUserId: instructor.userId,
          contactName: instructor.shopName,
          contactAvatar: instructor.avatar,
          isMentor: false,
        ),
      ),
    );
  }

  // ---------- Fullscreen photo viewer ----------
  void _openPhotoViewer({
    required List<String> urls,
    int startIndex = 0,
    String? title,
  }) {
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: title != null
                ? Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            centerTitle: true,
          ),
          body: PhotoViewGallery.builder(
            itemCount: urls.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  ApiService.resolveImageUrl(urls[index]),
                ),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: startIndex),
          ),
        ),
      ),
    );
  }

  Widget _withScrollHint({
    required double height,
    required Widget listView,
    bool hasMore = true,
  }) {
    if (!hasMore) return SizedBox(height: height, child: listView);
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          listView,
          Positioned(
            right: 4,
            child: IgnorePointer(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = _allImages;
    final videos = widget.classItem.videos;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF6B4C2A),
        ),
        title: Text(
          widget.classItem.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.isOwnClass)
            IconButton(
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditClassScreen(
                      existingClass: widget.classItem,
                    ),
                  ),
                );
                if (updated == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: const Icon(Icons.edit_outlined),
              color: const Color(0xFF6B4C2A),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 350,
                        width: double.infinity,
                        child: images.isEmpty
                            ? Container(color: const Color(0xFFFFF0B5))
                            : PageView.builder(
                                onPageChanged: (index) {
                                  setState(() => _currentMediaIndex = index);
                                },
                                itemCount: images.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    onTap: () => _openPhotoViewer(
                                      urls: images,
                                      startIndex: index,
                                      title: widget.classItem.title,
                                    ),
                                    child: CachedNetworkImage(
                                      imageUrl: ApiService.resolveImageUrl(
                                          images[index]),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: const Color(0xFFFFF0B5),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFFFB347),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: const Color(0xFFFFF0B5),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 50,
                                          color: Color(0xFFFFD966),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(images.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentMediaIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentMediaIndex == index
                                      ? const Color(0xFFFFB347)
                                      : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProviderProfileScreen(
                                      instructorId:
                                          widget.classItem.instructor.id,
                                    ),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: widget.classItem.instructor
                                        .avatar.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        ApiService.resolveImageUrl(widget
                                            .classItem.instructor.avatar),
                                      )
                                    : null,
                                backgroundColor: const Color(0xFFFFD966),
                                child: widget.classItem.instructor.avatar
                                        .isEmpty
                                    ? const Icon(Icons.person,
                                        color: Colors.white)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.classItem.instructor.shopName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6B4C2A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.classItem.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFC9A96E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF9E6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star,
                                            size: 14,
                                            color: Color(0xFFFFB347)),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.classItem.rating.toString(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF6B4C2A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (widget.classItem.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.classItem.tags.map((tag) {
                              IconData icon;
                              Color color;
                              switch (tag) {
                                case 'In-Person':
                                  icon = Icons.store;
                                  color = const Color(0xFF6C5CE7);
                                  break;
                                case 'Home Visit':
                                  icon = Icons.home;
                                  color = const Color(0xFFFFB347);
                                  break;
                                default:
                                  icon = Icons.local_offer;
                                  color = const Color(0xFFC9A96E);
                              }
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 14, color: color),
                                    const SizedBox(width: 6),
                                    Text(
                                      tag,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Text(
                          widget.classItem.description,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color:
                                const Color(0xFF6B4C2A).withValues(alpha: 0.8),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (widget.classItem.schedule.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule,
                                    color: Color(0xFFFFB347), size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.classItem.schedule,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF6B4C2A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on,
                                  size: 18, color: Color(0xFFFFB347)),
                              const SizedBox(width: 8),
                              Text(
                                widget.classItem.location,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF6B4C2A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (widget.classItem.dishes.isNotEmpty) ...[
                          _sectionTitle('What You\'ll Learn'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: widget.classItem.dishes.map((dish) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.04),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle,
                                        size: 18, color: Color(0xFFFFB347)),
                                    const SizedBox(width: 10),
                                    Text(
                                      dish,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (widget.classItem.certificates.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                ),
                              ],
                              border: Border.all(
                                color: const Color(0xFFFFD966)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.emoji_events,
                                        color: Color(0xFFFFB347), size: 24),
                                    const SizedBox(width: 10),
                                    Text(
                                      'What You\'ll Get',
                                      style: GoogleFonts.poppins(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF6B4C2A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...widget.classItem.certificates.map((cert) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '•',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFFFB347),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            cert,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: const Color(0xFF6B4C2A)
                                                  .withValues(alpha: 0.85),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (videos.isNotEmpty) ...[
                          _sectionTitle('Videos'),
                          const SizedBox(height: 12),
                          _withScrollHint(
                            height: 140,
                            hasMore: videos.length > 1,
                            listView: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(right: 16),
                              itemCount: videos.length,
                              itemBuilder: (context, i) {
                                final rawUrl = videos[i].video;
                                if (rawUrl.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final videoUrl =
                                    ApiService.resolveImageUrl(rawUrl);
                                return _VideoThumbnailTile(
                                  videoUrl: videoUrl,
                                  title: widget.classItem.title,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FullscreenVideoScreen(
                                          videoUrl: videoUrl,
                                          title: widget.classItem.title,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        if (widget
                            .classItem.instructor.complianceDocuments
                            .isNotEmpty) ...[
                          _sectionTitle('Verified Documents'),
                          const SizedBox(height: 12),
                          _withScrollHint(
                            height: 120,
                            hasMore: widget.classItem.instructor
                                    .complianceDocuments.length >
                                1,
                            listView: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(right: 16),
                              itemCount: widget.classItem.instructor
                                  .complianceDocuments.length,
                              itemBuilder: (context, i) {
                                final doc = widget.classItem.instructor
                                    .complianceDocuments[i];
                                final allDocUrls = widget.classItem.instructor
                                    .complianceDocuments
                                    .map((d) => d.value)
                                    .toList();
                                return GestureDetector(
                                  onTap: () => _openPhotoViewer(
                                    urls: allDocUrls,
                                    startIndex: i,
                                    title: doc.key,
                                  ),
                                  child: Container(
                                    width: 120,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.04),
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
                                                    top:
                                                        Radius.circular(12)),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  ApiService.resolveImageUrl(
                                                      doc.value),
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color:
                                                    const Color(0xFFFFF0B5),
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color:
                                                    const Color(0xFFFFF0B5),
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

                        if (widget.classItem.images.isNotEmpty) ...[
                          _sectionTitle('Shop Gallery'),
                          const SizedBox(height: 12),
                          _withScrollHint(
                            height: 140,
                            hasMore: widget.classItem.images.length > 1,
                            listView: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(right: 16),
                              itemCount: widget.classItem.images.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _openPhotoViewer(
                                    urls: widget.classItem.images,
                                    startIndex: index,
                                    title: widget.classItem.title,
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 180,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.06),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: ApiService.resolveImageUrl(
                                            widget.classItem.images[index]),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: const Color(0xFFFFF0B5),
                                          child: const Icon(
                                            Icons.image,
                                            color: Color(0xFFFFD966),
                                            size: 40,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                          color: const Color(0xFFFFF0B5),
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: Color(0xFFFFD966),
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ============ Bottom bar ============
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: Row(
                children: [
                  // Customer service icon — only for non-owner (regular users)
                  if (!widget.isOwnClass) ...[
                    GestureDetector(
                      onTap: _openChatWithInstructor,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5E6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: Color(0xFFFFB347),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Chat → reviews
                  _iconButton(
                    icon: Icons.chat_bubble_outline,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingReviewsScreen(
                            classId: widget.classItem.id,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),

                  // Save
                  _iconButton(
                    icon: _isSaved ? Icons.favorite : Icons.favorite_border,
                    color: _isSaved ? Colors.red : const Color(0xFFC9A96E),
                    onTap: _toggleSave,
                  ),
                  const Spacer(),

                  // Price
                  Text(
                    widget.classItem.priceDisplay,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFB347),
                    ),
                  ),
                  if (!_isInstructor) ...[
                    const SizedBox(width: 14),
                    _buildBookButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildBookButton() {
    final notAvailable = !widget.classItem.isAvailable;
    final fullyBooked = widget.classItem.isFullyBooked;

    if (notAvailable || fullyBooked) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          fullyBooked ? 'Fully Booked' : 'Not Available',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: _onBookNow,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFB347),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Book Now',
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = const Color(0xFFC9A96E),
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 24),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  void _showBookingConfirmationDialog({
    required DateTime date,
    required DaySlotOption slot,
    required int quantity,
  }) {
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    final total = widget.classItem.price * quantity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check,
                  color: Color(0xFFFFB347), size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'Booking Confirmed',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: const Color(0xFF6B4C2A),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have successfully booked:',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6B4C2A).withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD966).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.classItem.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.classItem.instructor.shopName,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFC9A96E),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Color(0xFFFFB347)),
                      const SizedBox(width: 6),
                      Text(
                        'Date: $formattedDate',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFB347),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Color(0xFFFFB347)),
                      const SizedBox(width: 6),
                      Text(
                        'Time: ${slot.timeRange}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFB347),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people,
                          size: 14, color: Color(0xFFFFB347)),
                      const SizedBox(width: 6),
                      Text(
                        'People: $quantity',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFB347),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6B4C2A),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'RM ${total.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFB347),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: const Color(0xFFFFB347),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbnailTile extends StatefulWidget {
  final String videoUrl;
  final String title;
  final VoidCallback onTap;

  const _VideoThumbnailTile({
    required this.videoUrl,
    required this.title,
    required this.onTap,
  });

  @override
  State<_VideoThumbnailTile> createState() => _VideoThumbnailTileState();
}

class _VideoThumbnailTileState extends State<_VideoThumbnailTile> {
  String? _thumbPath;
  bool _generating = true;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (widget.videoUrl.isEmpty) {
      if (mounted) setState(() => _generating = false);
      return;
    }
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
        timeMs: 0,
      );
      if (bytes == null) {
        if (mounted) setState(() => _generating = false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/bd_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _thumbPath = out.path;
        _generating = false;
      });
    } catch (e) {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_thumbPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(
                  File(_thumbPath!),
                  width: 200,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              )
            else if (_generating)
              const SizedBox(
                width: 200,
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFFB347)),
                ),
              )
            else
              Container(
                width: 200,
                height: 140,
                color: const Color(0xFF1A1A1A),
                child: const Icon(Icons.videocam,
                    color: Colors.white24, size: 48),
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow,
                  color: Color(0xFF6B4C2A), size: 28),
            ),
          ],
        ),
      ),
    );
  }
}