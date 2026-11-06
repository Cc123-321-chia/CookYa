// screens/add_dish_post_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../services/api_service.dart';

class AddDishPostScreen extends StatefulWidget {
  final String recipeId;
  final String recipeTitle;
  final String? existingHomeworkId;
  final String? existingReview;
  final String? existingRating;
  final String? existingImageUrl;

  const AddDishPostScreen({
    super.key,
    required this.recipeId,
    required this.recipeTitle,
    this.existingHomeworkId,
    this.existingReview,
    this.existingRating,
    this.existingImageUrl,
  });

  bool get isEditing => existingHomeworkId != null;

  @override
  State<AddDishPostScreen> createState() => _AddDishPostScreenState();
}

class _AddDishPostScreenState extends State<AddDishPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _comment = '';
  String _rating = 'good';
  List<File> _photos = [];
  bool _isSubmitting = false;
  String? _existingImageUrl;

  final List<Map<String, dynamic>> _ratings = [
    {
      'icon': Icons.sentiment_very_dissatisfied,
      'label': 'Bad',
      'value': 'bad',
      'color': const Color(0xFFF44336),
    },
    {
      'icon': Icons.sentiment_neutral,
      'label': 'Normal',
      'value': 'ok',
      'color': const Color(0xFFFF9800),
    },
    {
      'icon': Icons.sentiment_very_satisfied,
      'label': 'Good',
      'value': 'good',
      'color': const Color(0xFF4CAF50),
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _commentController.text = widget.existingReview ?? '';
      _comment = widget.existingReview ?? '';
      _rating = widget.existingRating ?? 'good';
      _existingImageUrl = widget.existingImageUrl;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ==================== 选图 ====================
  Future<void> _pickPhotos() async {
    if (_photos.length >= 1) {
      _showSnackBar('Only one photo allowed');
      return;
    }
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _photos.add(File(image.path)));
    }
  }

  void _deletePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _showPhotoFullscreen(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '${startIndex + 1}/${_photos.length}',
              style: const TextStyle(color: Colors.white),
            ),
            centerTitle: true,
          ),
          body: PhotoViewGallery.builder(
            itemCount: _photos.length,
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: FileImage(_photos[i]),
              initialScale: PhotoViewComputedScale.contained,
            ),
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: startIndex),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_comment.isEmpty) {
      _showSnackBar('Please write a comment', isError: true);
      return;
    }
    if (_photos.isEmpty &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      _showSnackBar('Please add a photo', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // 转 base64
    String? imageBase64;
    if (_photos.isNotEmpty) {
      final bytes = await _photos.first.readAsBytes();
      imageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    Map<String, dynamic> result;

    if (widget.isEditing) {
      result = await ApiService.updateHomework(
        homeworkId: widget.existingHomeworkId!,
        review: _comment,
        rating: _rating,
        imageBase64: imageBase64,
      );
    } else {
      result = await ApiService.submitHomework(
        recipeId: widget.recipeId,
        review: _comment,
        rating: _rating,
        imageBase64: imageBase64,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      _showSnackBar(widget.isEditing ? 'Dish updated!' : 'Dish shared!');
      Navigator.pop(context, true);
    } else {
      _showSnackBar(result['error'] ?? 'Failed to submit', isError: true);
    }
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Edit Dish' : 'Share Your Dish',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          color: const Color(0xFF6B4C2A),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD966).withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recipe',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: const Color(0xFFC9A96E))),
                    const SizedBox(height: 4),
                    Text(
                      widget.recipeTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B4C2A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildMediaSection(),
              const SizedBox(height: 24),
              _buildRatingSection(),
              const SizedBox(height: 24),
              _buildCommentSection(),
              const SizedBox(height: 32),
              _buildButtonsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Dish Photo',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (_photos.isEmpty && _existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _existingImageUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ..._photos.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildPhotoItem(e.key),
                  )),
              if (_photos.isEmpty && (_existingImageUrl == null || _existingImageUrl!.isEmpty))
                _buildAddPhotoButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    return GestureDetector(
      onTap: _pickPhotos,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD966), width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 40, color: Color(0xFFFFB347)),
            SizedBox(height: 4),
            Text('Add Photo',
                style: TextStyle(fontSize: 12, color: Color(0xFFC9A96E))),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(int index) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showPhotoFullscreen(index),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(_photos[index]),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _deletePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How was your dish?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _ratings.map((r) {
            final isSelected = _rating == r['value'];
            final color = r['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _rating = r['value'] as String),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: color, width: 2.5)
                          : null,
                    ),
                    child: Icon(
                      r['icon'] as IconData,
                      size: isSelected ? 40 : 32,
                      color: isSelected ? color : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isSelected ? color : const Color(0xFFC9A96E),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Comment',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _commentController,
          onChanged: (v) => _comment = v,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Share your experience with this dish...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (v) =>
              v?.isEmpty == true ? 'Please write a comment' : null,
        ),
      ],
    );
  }

  Widget _buildButtonsSection() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC9A96E),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD966),
              foregroundColor: const Color(0xFF6B4C2A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 2,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF6B4C2A)),
                  )
                : Text(
                    widget.isEditing ? 'Update' : 'Share',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}