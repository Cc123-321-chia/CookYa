// lib/admin/admin_upload_poster.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/admin_api_service.dart';
import '../models/carousel_item.dart';

class AdminUploadPosterScreen extends StatefulWidget {
  const AdminUploadPosterScreen({super.key});

  @override
  State<AdminUploadPosterScreen> createState() => _AdminUploadPosterScreenState();
}

class _AdminUploadPosterScreenState extends State<AdminUploadPosterScreen> {
  List<CarouselItem> _posters = [];
  bool _isLoading = true;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];
  File? _selectedImage;
  Uint8List? _imageBytes;
  String? _imageFilename;
  final ImagePicker _picker = ImagePicker();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _loadPosters();
  }

  Future<void> _loadPosters() async {
    setState(() => _isLoading = true);

    try {
      final items = await AdminApiService.getAllCarouselItems();
      items.sort((a, b) => a.order.compareTo(b.order));
      setState(() {
        _posters = items;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading posters: $e');
      setState(() {
        _posters = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = File(image.path);
        _imageBytes = bytes;
        _imageFilename = image.name;
      });
    }
  }

  Future<void> _uploadPoster() async {
    if (_imageBytes == null || _imageFilename == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image'), backgroundColor: Color(0xFFFFB347)),
      );
      return;
    }

    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title'), backgroundColor: Color(0xFFFFB347)),
      );
      return;
    }

    if (_tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one tag'), backgroundColor: Color(0xFFFFB347)),
      );
      return;
    }

    try {
      final nextOrder = _posters.isEmpty ? 0 : _posters.last.order + 1;

      await AdminApiService.createCarouselItem(
        title: _titleController.text,
        tags: _tags,
        imageBytes: _imageBytes!,
        imageFilename: _imageFilename!,
        order: nextOrder,
        isActive: _isActive,
      );

      _titleController.clear();
      _tagController.clear();
      setState(() {
        _selectedImage = null;
        _imageBytes = null;
        _imageFilename = null;
        _tags.clear();
        _isActive = true;
      });
      _loadPosters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster uploaded successfully!'), backgroundColor: Color(0xFFFFB347)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePosterStatus(CarouselItem poster) async {
    try {
      final newStatus = !poster.isActive;
      await AdminApiService.toggleCarouselItemActive(poster.id, newStatus);

      setState(() {
        final index = _posters.indexWhere((p) => p.id == poster.id);
        if (index != -1) {
          _posters[index] = CarouselItem(
            id: poster.id,
            title: poster.title,
            tags: poster.tags,
            imageUrl: poster.imageUrl,
            keywords: poster.keywords,
            order: poster.order,
            isActive: newStatus,
          );
        }
      });
    } catch (e) {
      print('Error toggling status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deletePoster(CarouselItem poster) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Poster'),
        content: Text('Are you sure you want to delete "${poster.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B4C2A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFFB347))),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AdminApiService.deleteCarouselItem(poster.id);
        setState(() {
          _posters.removeWhere((p) => p.id == poster.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Poster deleted successfully'), backgroundColor: Color(0xFFFFB347)),
          );
        }
      } catch (e) {
        print('Error deleting poster: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _posters.removeAt(oldIndex);
      _posters.insert(newIndex, item);
    });

    final ids = _posters.map((p) => p.id).toList();
    final ok = await AdminApiService.reorderCarouselItems(ids);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save new order'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB347),
        elevation: 0,
        title: Text(
          'Upload Poster / Banner',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildUploadSection(),
            const SizedBox(height: 24),
            _buildPostersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB347).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload New Poster',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          const SizedBox(height: 20),


          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5E6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE0B5), width: 2),
              ),
              child: _imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload, size: 48, color: Color(0xFFFFB347)),
                        const SizedBox(height: 12),
                        Text(
                          'Click to select image',
                          style: GoogleFonts.poppins(color: const Color(0xFFC9A96E)),
                        ),
                        Text(
                          'Recommended: 1200x400px',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFC9A96E)),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              hintText: 'e.g., Chinese New Year, Halloween...',
              labelStyle: const TextStyle(color: Color(0xFF6B4C2A)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFFB347), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _tagController,
            onSubmitted: (value) {
              final tag = value.trim();
              if (tag.isNotEmpty && !_tags.contains(tag)) {
                setState(() {
                  _tags.add(tag);
                  _tagController.clear();
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'Add Tag',
              hintText: 'e.g., Dumplings, Yee Sang',
              helperText: 'Press + or Enter to add',
              helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              labelStyle: const TextStyle(color: Color(0xFF6B4C2A)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, color: Color(0xFFFFB347)),
                onPressed: () {
                  final tag = _tagController.text.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() {
                      _tags.add(tag);
                      _tagController.clear();
                    });
                  }
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFFB347), width: 2),
              ),
            ),
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$tag',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFFFB347),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() => _tags.remove(tag));
                        },
                        child: const Icon(Icons.close, size: 14, color: Color(0xFFFFB347)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),

          // 🔥 删掉 order 输入框

          Row(
            children: [
              const Text(
                'Active',
                style: TextStyle(color: Color(0xFF6B4C2A), fontSize: 16),
              ),
              const Spacer(),
              CupertinoSwitch(
                value: _isActive,
                onChanged: (bool value) {
                  setState(() => _isActive = value);
                },
                activeColor: CupertinoColors.activeGreen,
                trackColor: CupertinoColors.systemGrey3,
                thumbColor: CupertinoColors.white,
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _uploadPoster,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB347),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'Upload Poster',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostersList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB347).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Posters',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B4C2A),
                ),
              ),
              if (_posters.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_posters.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB347),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFFFB347)))
          else if (_posters.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No posters uploaded yet'),
              ),
            )
          else
            // 🔥 改成 ReorderableListView
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _posters.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final poster = _posters[index];
                return _buildPosterItem(poster, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPosterItem(CarouselItem poster, int index) {
    final isActive = poster.isActive;

    return Container(
      key: ValueKey(poster.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFFB347).withOpacity(0.6)
              : const Color(0xFFE8D5B5),
          width: isActive ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFFFFB347).withOpacity(0.25)
                : const Color(0xFFE8D5B5).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 🔥 拖拽手柄（6 点）
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.drag_handle,
                  color: Color(0xFFC9A96E),
                  size: 26,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  poster.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFFFFE4B5),
                      child: const Icon(Icons.image_not_supported, color: Color(0xFFC9A96E), size: 30),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    poster.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5A3E1B),
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    poster.tags.isNotEmpty ? poster.tags.join(' · ') : 'No tags',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF8B7355),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: Color(0xFFB8956A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ID: ${poster.id.length > 6 ? poster.id.substring(0, 6) : poster.id}...',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFB8956A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: () => _deletePoster(poster),
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
              iconSize: 22,
            ),

            CupertinoSwitch(
              value: isActive,
              onChanged: (bool value) {
                _togglePosterStatus(poster);
              },
              activeColor: CupertinoColors.activeGreen,
              trackColor: CupertinoColors.systemGrey3,
              thumbColor: CupertinoColors.white,
            ),
          ],
        ),
      ),
    );
  }
}