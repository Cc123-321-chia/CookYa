// screens/booking/add_edit_class_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/booking_models.dart';

class AddEditClassScreen extends StatefulWidget {
  final CookingClassModel? existingClass;

  const AddEditClassScreen({super.key, this.existingClass});

  bool get isEditing => existingClass != null;

  @override
  State<AddEditClassScreen> createState() => _AddEditClassScreenState();
}

class _AddEditClassScreenState extends State<AddEditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();

  String _classType = 'in_person';
  List<String> _tags = [];
  List<String> _dishes = [];
  List<String> _certificates = [];

  String _selectedCurrency = 'RM';
  final List<String> _currencies = [
    'RM', '฿', '¥', '€', '₫', 'HK\$', '₩', 'S\$', '₹', '₱', '₴', '₦',
    'R\$', '£', 'CHF', 'kr', 'zł', 'Kč', 'Ft', 'lei', '₺', '₪', '﷼', 'Rs',
  ];

  File? _newImage;
  File? _newCoverVideo;
  String? _existingImageUrl;
  String? _existingCoverVideoUrl;
  String? _coverVideoThumbnailPath;

  final List<_GalleryItem> _galleryImages = [];
  final List<_GalleryItem> _galleryVideos = [];

  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

  final _availableTags = ['In-Person', 'Home Visit', 'Certificate'];
  final _tagCtrl = TextEditingController();
  final _dishCtrl = TextEditingController();
  final _certCtrl = TextEditingController();

  VideoPlayerController? _videoPreviewController;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final c = widget.existingClass!;
      _titleCtrl.text = c.title;
      _descCtrl.text = c.description;
      _locationCtrl.text = c.location;
      _priceCtrl.text = _formatPriceForEdit(c.price);
      _scheduleCtrl.text = c.schedule;
      _classType = c.classType;
      _tags = List.from(c.tags);
      _dishes = List.from(c.dishes);
      _certificates = List.from(c.certificates);

      if (c.image.isNotEmpty) _existingImageUrl = c.image;
      if (c.coverVideo.isNotEmpty) _existingCoverVideoUrl = c.coverVideo;

      for (final img in c.images) {
        _galleryImages.add(_GalleryItem(url: img));
      }
      for (final v in c.videos) {
        _galleryVideos.add(_GalleryItem(url: v.video));
      }

      if (_existingCoverVideoUrl != null &&
          _existingCoverVideoUrl!.isNotEmpty) {
        _initVideoPreviewFromUrl(
            ApiService.resolveImageUrl(_existingCoverVideoUrl!));
        _generateThumbnailFromUrl(
            ApiService.resolveImageUrl(_existingCoverVideoUrl!));
      }
    }
  }

  String _formatPriceForEdit(double price) {
    if (price == price.roundToDouble()) return price.toInt().toString();
    return price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _scheduleCtrl.dispose();
    _tagCtrl.dispose();
    _dishCtrl.dispose();
    _certCtrl.dispose();
    _videoPreviewController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(File) onPicked) async {
    final x =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) onPicked(File(x.path));
  }

  Future<void> _pickVideo(Function(File) onPicked) async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x != null) onPicked(File(x.path));
  }

  Future<void> _pickMultiImages() async {
    final list = await _picker.pickMultiImage(imageQuality: 80);
    if (list.isNotEmpty) {
      setState(() {
        for (final f in list) {
          if (_galleryImages.length < 9) {
            _galleryImages.add(_GalleryItem(file: File(f.path)));
          } else {
            break;
          }
        }
      });
      if (_galleryImages.length >= 9 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 9 images allowed')),
        );
      }
    }
  }

  Future<void> _initVideoPreviewFromFile(File file) async {
    _videoPreviewController?.dispose();
    _videoPreviewController = VideoPlayerController.file(file);
    await _videoPreviewController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _initVideoPreviewFromUrl(String url) async {
    _videoPreviewController?.dispose();
    _videoPreviewController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoPreviewController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _generateThumbnailFromFile(File file) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 0,
      );
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/cover_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _coverVideoThumbnailPath = out.path);
    } catch (e) {
      debugPrint('Thumbnail from file error: $e');
    }
  }

  Future<void> _generateThumbnailFromUrl(String url) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 0,
      );
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/cover_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(bytes);
      if (!mounted) return;
      setState(() => _coverVideoThumbnailPath = out.path);
    } catch (e) {
      debugPrint('Thumbnail from url error: $e');
    }
  }

  Future<void> _generateGalleryThumbnail(int index, File file) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        quality: 70,
        timeMs: 0,
      );
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final out = File(
          '${dir.path}/gallery_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await out.writeAsBytes(bytes);
      if (!mounted) return;
      if (index < _galleryVideos.length) {
        setState(() {
          _galleryVideos[index] = _GalleryItem(
            file: _galleryVideos[index].file,
            url: _galleryVideos[index].url,
            thumbnailPath: out.path,
          );
        });
      }
    } catch (e) {
      debugPrint('Gallery thumbnail error: $e');
    }
  }

  void _showVideoPreviewDialog() {
    if (_videoPreviewController == null ||
        !_videoPreviewController!.value.isInitialized) {
      _showSnack('Video preview not ready');
      return;
    }
    _videoPreviewController!.play();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: AspectRatio(
          aspectRatio: _videoPreviewController!.value.aspectRatio,
          child: VideoPlayer(_videoPreviewController!),
        ),
      ),
    ).then((_) {
      _videoPreviewController?.pause();
    });
  }

  void _showImagePreviewDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: ApiService.resolveImageUrl(url),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  void _showLocalImageDialog(File file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.file(file, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _showGalleryVideoDialog(_GalleryItem item) {
    VideoPlayerController? ctrl;
    if (item.file != null) {
      ctrl = VideoPlayerController.file(item.file!);
    } else if (item.url != null) {
      ctrl = VideoPlayerController.networkUrl(
          Uri.parse(ApiService.resolveImageUrl(item.url!)));
    } else {
      return;
    }
    ctrl.initialize().then((_) {
      ctrl!.play();
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          child: AspectRatio(
            aspectRatio: ctrl!.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
        ),
      ).then((_) => ctrl!.dispose());
    }).catchError((_) {
      ctrl?.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;

    final newGalleryImages =
        _galleryImages.where((g) => g.file != null).map((g) => g.file!).toList();
    final newGalleryVideos =
        _galleryVideos.where((g) => g.file != null).map((g) => g.file!).toList();

    Map<String, dynamic> result;
    if (widget.isEditing) {
      result = await ApiService.updateClass(
        classId: widget.existingClass!.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        price: price,
        classType: _classType,
        schedule: _scheduleCtrl.text.trim(),
        tags: _tags,
        dishes: _dishes,
        certificates: _certificates,
        image: _newImage,
        coverVideo: _newCoverVideo,
        newImages: newGalleryImages,
        newVideos: newGalleryVideos,
      );
    } else {
      result = await ApiService.createClass(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        price: price,
        classType: _classType,
        schedule: _scheduleCtrl.text.trim(),
        tags: _tags,
        dishes: _dishes,
        certificates: _certificates,
        image: _newImage,
        coverVideo: _newCoverVideo,
        images: newGalleryImages,
        videos: newGalleryVideos,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      final err = result['error'];
      _showSnack(err is String ? err : 'Failed to save class');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Edit Class' : 'Add New Class',
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
            icon: const Icon(Icons.close),
            color: const Color(0xFF6B4C2A),
          ),
        ),
        body: _saving
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFB347)),
              )
            : SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Basic Information', Icons.restaurant_menu),
                      const SizedBox(height: 12),
                      _buildTextField(_titleCtrl, 'Class Title',
                          'e.g., Authentic Thai Cooking Class'),
                      const SizedBox(height: 12),
                      _buildTextField(_descCtrl, 'Description',
                          'Describe your class...',
                          maxLines: 4),
                      const SizedBox(height: 12),
                      _buildTextField(
                          _locationCtrl, 'Location', 'e.g., Bangkok, Thailand'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Price',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF6B4C2A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCurrency,
                                          items: _currencies.map((c) {
                                            return DropdownMenuItem(
                                              value: c,
                                              child: Text(c),
                                            );
                                          }).toList(),
                                          onChanged: (v) => setState(
                                              () => _selectedCurrency =
                                                  v ?? 'RM'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: 'e.g., 120',
                                          hintStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 13),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            borderSide: BorderSide.none,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            borderSide: BorderSide.none,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            borderSide: const BorderSide(
                                                color: Color(0xFFFFD966),
                                                width: 2),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12),
                                        ),
                                        validator: (v) =>
                                            v?.trim().isEmpty == true
                                                ? 'Required'
                                                : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Class Type',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF6B4C2A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _classType,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFFFD966), width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'in_person',
                                        child: Text('In-Person')),
                                    DropdownMenuItem(
                                        value: 'home_visit',
                                        child: Text('Home Visit')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _classType = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_scheduleCtrl, 'Schedule Note',
                          'e.g., Mon-Fri morning'),

                      const SizedBox(height: 24),
                      _sectionTitle('Tags', Icons.local_offer),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final selected = _tags.contains(tag);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _tags.remove(tag);
                                } else {
                                  _tags.add(tag);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFFFD966)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFFFD966)
                                      : const Color(0xFFFFB347),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected) ...[
                                    const Icon(Icons.check,
                                        size: 14, color: Color(0xFF6B4C2A)),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    tag,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: const Color(0xFF6B4C2A),
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),
                      _listSection('Dishes', _dishes, _dishCtrl,
                          'e.g., Pad Thai', 'Add Dish'),
                      const SizedBox(height: 24),
                      _listSection('Certificates', _certificates, _certCtrl,
                          'e.g., Certificate', 'Add Certificate'),

                      if (widget.isEditing &&
                          widget.existingClass!.instructor.complianceDocuments
                              .isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionTitle('Verified Certificates (Read-only)',
                            Icons.verified),
                        const SizedBox(height: 12),
                        _buildReadOnlyCertificates(),
                      ],

                      const SizedBox(height: 24),
                      _sectionTitle('Cover Image', Icons.image),
                      const SizedBox(height: 12),
                      _buildCoverImageTile(),

                      const SizedBox(height: 24),
                      _sectionTitle('Cover Video (optional)', Icons.videocam),
                      const SizedBox(height: 12),
                      _buildCoverVideoTile(),

                      const SizedBox(height: 24),
                      _sectionTitle('Gallery Images', Icons.photo_library),
                      const SizedBox(height: 12),
                      _buildGalleryImagesSection(),

                      const SizedBox(height: 24),
                      _sectionTitle(
                          'Gallery Videos (max 3)', Icons.video_library),
                      const SizedBox(height: 12),
                      _buildGalleryVideosSection(),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB347),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            widget.isEditing ? 'Save Changes' : 'Create Class',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildReadOnlyCertificates() {
    final docs = widget.existingClass!.instructor.complianceDocuments;
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final doc = docs[i];
          return GestureDetector(
            onTap: () => _showImagePreviewDialog(doc.value),
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFFFD966), width: 1.5),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: CachedNetworkImage(
                        imageUrl: ApiService.resolveImageUrl(doc.value),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFFFF0B5),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFFFF0B5),
                          child: const Icon(Icons.description,
                              color: Color(0xFFFFB347)),
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
    );
  }

  Widget _buildCoverImageTile() {
    final hasNewFile = _newImage != null;
    final hasExisting =
        _existingImageUrl != null && _existingImageUrl!.isNotEmpty;

    if (hasNewFile) {
      return _imagePreviewTile(
        file: _newImage!,
        label: 'Cover Image',
        onRemove: () => setState(() => _newImage = null),
      );
    }
    if (hasExisting) {
      return _networkImagePreviewTile(
        url: _existingImageUrl!,
        label: 'Cover Image',
        onReplace: () => _pickImage((f) {
          setState(() => _newImage = f);
        }),
      );
    }
    return _uploadButton(
      icon: Icons.cloud_upload,
      label: 'Upload Cover Image',
      onTap: () => _pickImage((f) {
        setState(() => _newImage = f);
      }),
    );
  }

  Widget _buildCoverVideoTile() {
    final hasNewFile = _newCoverVideo != null;
    final hasExisting =
        _existingCoverVideoUrl != null && _existingCoverVideoUrl!.isNotEmpty;

    if (hasNewFile) {
      return _videoPreviewTile(
        // Tap the card body to re-pick a new video
        onTapBody: () => _pickVideo((f) {
          setState(() {
            _newCoverVideo = f;
            _existingCoverVideoUrl = null;
            _coverVideoThumbnailPath = null;
          });
          _initVideoPreviewFromFile(f);
          _generateThumbnailFromFile(f);
        }),
        // Tap the X to remove the current video
        onRemove: () {
          setState(() {
            _newCoverVideo = null;
            _coverVideoThumbnailPath = null;
            _videoPreviewController?.dispose();
            _videoPreviewController = null;
          });
        },
      );
    }

    if (hasExisting) {
      return _videoPreviewTile(
        onTapBody: () => _pickVideo((f) {
          setState(() {
            _newCoverVideo = f;
            _coverVideoThumbnailPath = null;
          });
          _initVideoPreviewFromFile(f);
          _generateThumbnailFromFile(f);
        }),
        onRemove: () {
          setState(() {
            _existingCoverVideoUrl = null;
            _coverVideoThumbnailPath = null;
            _videoPreviewController?.dispose();
            _videoPreviewController = null;
          });
        },
      );
    }

    return _uploadButton(
      icon: Icons.videocam,
      label: 'Upload Cover Video',
      onTap: () => _pickVideo((f) {
        setState(() => _newCoverVideo = f);
        _initVideoPreviewFromFile(f);
        _generateThumbnailFromFile(f);
      }),
    );
  }

  Widget _buildGalleryImagesSection() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _galleryImages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _galleryImages.length) {
            return GestureDetector(
              onTap: _pickMultiImages,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFFFD966), width: 2),
                ),
                child: const Icon(Icons.add,
                    size: 32, color: Color(0xFFFFB347)),
              ),
            );
          }
          final item = _galleryImages[index];
          return Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (item.file != null) {
                    _showLocalImageDialog(item.file!);
                  } else if (item.url != null) {
                    _showImagePreviewDialog(item.url!);
                  }
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: _providerFor(item),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (item.file != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _galleryImages.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGalleryVideosSection() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _galleryVideos.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _galleryVideos.length) {
            if (_galleryVideos.length >= 3) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => _pickVideo((f) async {
                setState(() {
                  _galleryVideos.add(_GalleryItem(file: f));
                });
                await _generateGalleryThumbnail(_galleryVideos.length - 1, f);
              }),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFFFD966), width: 2),
                ),
                child: const Icon(Icons.videocam,
                    size: 32, color: Color(0xFFFFB347)),
              ),
            );
          }
          final item = _galleryVideos[index];
          return Stack(
            children: [
              GestureDetector(
                onTap: () => _showGalleryVideoDialog(item),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0B5),
                    borderRadius: BorderRadius.circular(12),
                    image: item.thumbnailPath != null
                        ? DecorationImage(
                            image: FileImage(File(item.thumbnailPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: item.thumbnailPath == null
                      ? const Icon(Icons.videocam,
                          size: 40, color: Color(0xFFFFB347))
                      : Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                size: 20, color: Color(0xFF6B4C2A)),
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _galleryVideos.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _imagePreviewTile({
    required File file,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showLocalImageDialog(file),
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD966), width: 2),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _networkImagePreviewTile({
    required String url,
    required String label,
    required VoidCallback onReplace,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showImagePreviewDialog(url),
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD966), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: ApiService.resolveImageUrl(url),
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFFFFB347)),
                ),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.image_not_supported,
                    color: Color(0xFFFFD966),
                    size: 40),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onReplace,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoPreviewTile({
    required VoidCallback onTapBody,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        // Card body — tap to play preview (long-press or tap opens picker)
        GestureDetector(
          onTap: _showVideoPreviewDialog,
          onLongPress: onTapBody,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD966), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (_coverVideoThumbnailPath != null)
                    Image.file(
                      File(_coverVideoThumbnailPath!),
                      fit: BoxFit.cover,
                    )
                  else
                    const ColoredBox(color: Color(0xFF1A1A1A)),
                  Container(color: Colors.black.withValues(alpha: 0.25)),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
          ),
        ),
        // X button — remove video
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ),
        // Bottom label
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Cover Video',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _networkVideoPreviewTile({
    required String url,
    required VoidCallback onReplace,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: _showVideoPreviewDialog,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD966), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (_coverVideoThumbnailPath != null)
                    Image.file(
                      File(_coverVideoThumbnailPath!),
                      fit: BoxFit.cover,
                    )
                  else
                    const ColoredBox(color: Color(0xFF1A1A1A)),
                  Container(color: Colors.black.withValues(alpha: 0.25)),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onReplace,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Cover Video',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _uploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: const Color(0xFFFFB347)),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFC9A96E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _providerFor(_GalleryItem item) {
    if (item.file != null) return FileImage(item.file!);
    if (item.url != null) {
      return CachedNetworkImageProvider(
          ApiService.resolveImageUrl(item.url!));
    }
    return const AssetImage('assets/placeholder.png');
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFFB347)),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _listSection(
    String title,
    List<String> items,
    TextEditingController ctrl,
    String hint,
    String addLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title, Icons.list),
        const SizedBox(height: 8),
        if (items.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.asMap().entries.map((e) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD966),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.value,
                        style: GoogleFonts.poppins(fontSize: 12)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => items.removeAt(e.key)),
                      child: const Icon(Icons.close, size: 14),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        if (items.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                        color: Color(0xFFFFD966), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (v.isNotEmpty) {
                  setState(() => items.add(v));
                  ctrl.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD966),
                foregroundColor: const Color(0xFF6B4C2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _GalleryItem {
  final File? file;
  final String? url;
  final String? thumbnailPath;

  _GalleryItem({this.file, this.url, this.thumbnailPath});
}