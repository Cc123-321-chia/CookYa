// screens/ingredient/add_ingredient_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../utils/url_helper.dart';
import 'models.dart';

class AddIngredientPostScreen extends StatefulWidget {
  final String? editPostId;

  const AddIngredientPostScreen({super.key, this.editPostId});

  @override
  State<AddIngredientPostScreen> createState() => _AddIngredientPostScreenState();
}

class _AddIngredientPostScreenState extends State<AddIngredientPostScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.editPostId != null;

  // Form fields
  String _title = '';
  String _content = '';
  List<String> _tags = [];

  List<dynamic> _photos = [];
  dynamic _video;
  dynamic _videoCustomCover;
  String? _videoThumbnailPath;

  // Controllers
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _videoController;

  bool _isLoadingPost = false;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadPostForEdit();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _tagController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ============================================================
  // Edit Mode: Load post data
  // ============================================================
  Future<void> _loadPostForEdit() async {
    setState(() {
      _isLoadingPost = true;
    });

    try {
      final result = await ApiService.getIngredientPost(widget.editPostId!);

      if (result['success'] == true) {
        final post = IngredientPost.fromJson(result['data']);

        setState(() {
          _title = post.title;
          _titleController.text = post.title;

          _content = post.content;
          _contentController.text = post.content;

          _tags = List<String>.from(post.tags);

          // 旧照片 URL 放进去
          _photos = List<dynamic>.from(post.photoUrls);

          // 视频
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
            _video = post.videoUrl;
          }
          if (post.videoCoverUrl != null && post.videoCoverUrl!.isNotEmpty) {
            _videoCustomCover = post.videoCoverUrl;
          }
        });

        if (_video is String) {
          _initNetworkVideoPlayer(_video as String);
        }
      } else {
        if (mounted) {
          _showSnackBar(result['error'] ?? 'Failed to load post');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e');
        Navigator.pop(context);
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingPost = false;
      });
    }
  }

  Future<void> _initNetworkVideoPlayer(String url) async {
    try {
      String fullUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        fullUrl = '${UrlHelper.baseUrl}$url';
      }
      _videoController?.dispose();
      _videoController = VideoPlayerController.network(fullUrl);
      await _videoController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Init network video error: $e');
    }
  }

  // ============================================================
  // Photo Methods
  // ============================================================
  Future<void> _pickPhotos() async {
    if (_photos.length >= 9) {
      _showSnackBar('Maximum 9 photos reached');
      return;
    }

    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        for (XFile image in images) {
          if (_photos.length < 9) {
            _photos.add(File(image.path));
          }
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_video != null) {
      _showSnackBar('You can only upload 1 video. Delete current video first.');
      return;
    }

    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _video = File(video.path);
        _videoThumbnailPath = null;
        _videoCustomCover = null;
      });
      _generateVideoThumbnail();
      _initVideoPlayer();
    }
  }

  Future<void> _generateVideoThumbnail() async {
    if (_video is! File) return;

    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: (_video as File).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );

      if (uint8list != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/video_thumb.jpg').create();
        await file.writeAsBytes(uint8list);
        setState(() {
          _videoThumbnailPath = file.path;
        });
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
    }
  }

  Future<void> _initVideoPlayer() async {
    if (_video is! File) return;
    _videoController?.dispose();
    _videoController = VideoPlayerController.file(_video as File)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  Future<void> _pickVideoCustomCover() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _videoCustomCover = File(image.path);
      });
    }
  }

  void _deletePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _deleteVideo() {
    setState(() {
      _video = null;
      _videoCustomCover = null;
      _videoThumbnailPath = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  void _setAsCover(int index) {
    setState(() {
      final photo = _photos.removeAt(index);
      _photos.insert(0, photo);
    });
    _showSnackBar('Cover photo updated');
  }

  ImageProvider _getImageProvider(dynamic item) {
    if (item is File) {
      return FileImage(item);
    } else if (item is String) {
      return CachedNetworkImageProvider(item);
    }
    return const AssetImage('assets/placeholder.png');
  }

  void _showPhotoFullscreen(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _photos.removeAt(startIndex);
                  });
                  Navigator.pop(context);
                  _showSnackBar('Photo deleted');
                },
              ),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: ElevatedButton(
                  onPressed: () {
                    _setAsCover(startIndex);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB347),
                    foregroundColor: const Color(0xFF6B4C2A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Set as Cover',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          body: PhotoViewGallery.builder(
            itemCount: _photos.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: _getImageProvider(_photos[index]),
                initialScale: PhotoViewComputedScale.contained,
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

  void _showVideoPreview() {
    if (_videoController == null) {
      _showSnackBar('Video preview not ready');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  void _showMediaPickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFFB347)),
              title: const Text('Select Photos'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos();
              },
            ),
            if (_video == null)
              ListTile(
                leading: const Icon(Icons.video_library, color: Color(0xFFFFB347)),
                title: const Text('Select Video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo();
                },
              ),
            if (_video != null)
              ListTile(
                leading: const Icon(Icons.photo, color: Color(0xFFFFB347)),
                title: const Text('Change Video Cover'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoCustomCover();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ============================================================
  // Submit
  // ============================================================
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    if (_title.isEmpty) {
      _showSnackBar('Please enter title');
      return;
    }
    if (_content.isEmpty) {
      _showSnackBar('Please enter content');
      return;
    }
    if (_photos.isEmpty) {
      _showSnackBar('Please add at least one photo');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB347)),
      ),
    );

    try {
      final token = ApiService.authToken;
      if (token == null) {
        if (mounted) Navigator.pop(context);
        _showSnackBar('Please login first');
        return;
      }

      Map<String, dynamic> result;

      if (_isEditMode) {
        final existingPhotoUrls = <String>[];
        final newPhotos = <File>[];
        for (final p in _photos) {
          if (p is String) {
            existingPhotoUrls.add(p);
          } else if (p is File) {
            newPhotos.add(p);
          }
        }

        File? newVideo;
        String? existingVideoUrl;
        bool removeVideo = false;
        if (_video == null) {
          removeVideo = true;
        } else if (_video is File) {
          newVideo = _video as File;
        } else if (_video is String) {
          existingVideoUrl = _video as String;
        }

        File? newVideoCover;
        String? existingVideoCoverUrl;
        bool removeVideoCover = false;
        if (_videoCustomCover == null) {
          if (_video == null) {
            removeVideoCover = true;
          }
        } else if (_videoCustomCover is File) {
          newVideoCover = _videoCustomCover as File;
        } else if (_videoCustomCover is String) {
          existingVideoCoverUrl = _videoCustomCover as String;
        }

        result = await ApiService.updateIngredientPost(
          postId: widget.editPostId!,
          title: _title,
          content: _content,
          tags: _tags,
          existingPhotoUrls: existingPhotoUrls,
          newPhotos: newPhotos,
          existingVideoUrl: existingVideoUrl,
          newVideo: newVideo,
          existingVideoCoverUrl: existingVideoCoverUrl,
          newVideoCover: newVideoCover,
          removeVideo: removeVideo,
          removeVideoCover: removeVideoCover,
        );
      } else {
        final filePhotos = _photos.whereType<File>().toList();
        result = await ApiService.createIngredientPost(
          title: _title,
          content: _content,
          tags: _tags,
          photos: filePhotos,
          video: _video is File ? _video as File : null,
          videoCover: _videoCustomCover is File ? _videoCustomCover as File : null,
        );
      }

      if (mounted) Navigator.pop(context);

      if (result['success'] == true || result['id'] != null) {
        _showSnackBar(_isEditMode
            ? 'Post updated successfully!'
            : 'Post published successfully!');
        if (mounted) Navigator.pop(context, true);
      } else {
        String errorMsg = result['error'] ?? 'Failed to save post';
        _showSnackBar('❌ $errorMsg');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error: ${e.toString()}');
      print('Unexpected error: $e');
    }
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingPost) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFF9E6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Loading...',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF6B4C2A),
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEditMode ? 'Edit Ingredients Guide' : 'Add Ingredients Guide',
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
              _buildMediaSection(),
              const SizedBox(height: 24),
              _buildTitleSection(),
              const SizedBox(height: 16),
              _buildContentSection(),
              const SizedBox(height: 16),
              _buildTagsSection(),
              const SizedBox(height: 32),
              _buildButtonsSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Media Section
  // ============================================================
  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + (_video != null ? 1 : 0) + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == (_photos.length + (_video != null ? 1 : 0))) {
                return _buildAddMediaButton();
              }
              if (_video != null && index == _photos.length) {
                return _buildVideoItem();
              }
              return _buildPhotoItem(index);
            },
          ),
        ),
        if (_photos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Please add at least 1 photo (video optional)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddMediaButton() {
    return GestureDetector(
      onTap: _showMediaPickerDialog,
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
            Text('Add Media', style: TextStyle(fontSize: 12, color: Color(0xFFC9A96E))),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(int index) {
    final isCover = index == 0;
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showPhotoFullscreen(index),
          onLongPress: () => _setAsCover(index),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: _getImageProvider(_photos[index]),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        if (isCover)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COVER',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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

  Widget _buildVideoItem() {
    ImageProvider? thumbProvider;
    if (_videoCustomCover is File) {
      thumbProvider = FileImage(_videoCustomCover as File);
    } else if (_videoCustomCover is String) {
      thumbProvider = CachedNetworkImageProvider(_videoCustomCover as String);
    } else if (_videoThumbnailPath != null) {
      thumbProvider = FileImage(File(_videoThumbnailPath!));
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: _showVideoPreview,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: thumbProvider != null
                  ? DecorationImage(image: thumbProvider, fit: BoxFit.cover)
                  : null,
              color: Colors.grey.shade300,
            ),
            child: const Center(
              child: Icon(Icons.play_circle_filled, size: 40, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'VIDEO',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _deleteVideo,
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

  // ============================================================
  // Title Section
  // ============================================================
  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          onChanged: (value) => _title = value,
          decoration: InputDecoration(
            hintText: 'e.g., How to Choose Fresh Vegetables',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) => value?.isEmpty == true ? 'Please enter title' : null,
        ),
      ],
    );
  }

  // ============================================================
  // Content Section
  // ============================================================
  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _contentController,
          onChanged: (value) => _content = value,
          maxLines: 15,
          decoration: InputDecoration(
            hintText: 'Write your guide here... (max 1000 words)',
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
              borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) => value?.isEmpty == true ? 'Please enter content' : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_content.length}/1000 words',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: _content.length > 1000 ? Colors.red : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Tags Section
  // ============================================================
  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Add a tag (e.g., Vegetable, Fruit)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _tags.add(value);
                      _tagController.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (_tagController.text.isNotEmpty) {
                  setState(() {
                    _tags.add(_tagController.text);
                    _tagController.clear();
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD966),
                foregroundColor: const Color(0xFF6B4C2A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0D6),
                border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tag, style: const TextStyle(color: Color(0xFF6B4C2A))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _tags.remove(tag);
                      });
                    },
                    child: const Icon(Icons.close, size: 16, color: Color(0xFFFFB347)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // Buttons Section
  // ============================================================
  Widget _buildButtonsSection() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
            onPressed: _submitPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD966),
              foregroundColor: const Color(0xFF6B4C2A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 2,
            ),
            child: Text(
              _isEditMode ? 'Save' : 'Publish',
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