// screens/add_post/add_post_screen.dart
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
import 'dart:typed_data';

import '../../../models/recipe.dart';
import '../../../services/api_service.dart';
import '../../../services/recipe_service.dart';

class AddPostScreen extends StatefulWidget {
  final String? editRecipeId;

  const AddPostScreen({super.key, this.editRecipeId});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEditMode => widget.editRecipeId != null;

  // Form fields
  String _title = '';
  String _description = '';
  List<String> _tags = [];
  String _cuisineType = '';
  int _durationMinutes = 30;
  int _difficultyLevel = 5;
  List<String> _cookingTools = [];
  List<IngredientItem> _ingredients = [];
  List<StepItem> _steps = [];

  List<dynamic> _photos = [];
  dynamic _video;              // File? / String? / null
  dynamic _videoCustomCover;   // File? / String? / null
  String? _videoThumbnailPath;
  VideoPlayerController? _videoController;

  bool _isLoadingRecipe = false;

  // Controllers
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _toolController = TextEditingController();
  final TextEditingController _ingredientNameController = TextEditingController();
  final TextEditingController _ingredientAmountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _cuisineController = TextEditingController();

  // Step editing
  final TextEditingController _stepInstructionController = TextEditingController();
  final TextEditingController _stepNoteController = TextEditingController();
  bool _showNoteField = false;
  int? _editingStepIndex;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadRecipeForEdit();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _cuisineController.dispose();
    _tagController.dispose();
    _toolController.dispose();
    _ingredientNameController.dispose();
    _ingredientAmountController.dispose();
    _stepInstructionController.dispose();
    _stepNoteController.dispose();
    super.dispose();
  }

  // ============================================================
  //  Edit Mode: Load recipe data
  // ============================================================
  Future<void> _loadRecipeForEdit() async {
    setState(() {
      _isLoadingRecipe = true;
    });

    try {
      final result = await ApiService.getRecipeDetails(widget.editRecipeId!);

      if (result['success'] == true) {
        final recipe = Recipe.fromJson(result['data']);

        setState(() {
          _title = recipe.title;
          _titleController.text = recipe.title;

          _description = recipe.description;
          _descriptionController.text = recipe.description;

          _cuisineType = recipe.cuisineType;
          if (recipe.cuisineType.isNotEmpty) {
            _cuisineController.text = recipe.cuisineType;
          }

          _durationMinutes = recipe.durationMinutes;
          _difficultyLevel = recipe.difficultyLevel;

          _tags = List<String>.from(recipe.tags);
          _cookingTools = List<String>.from(recipe.cookingTools);
          _ingredients = List<IngredientItem>.from(recipe.ingredients);
          _steps = List<StepItem>.from(recipe.steps);

          _photos = List<dynamic>.from(recipe.photoUrls);

          if (recipe.videoUrl != null && recipe.videoUrl!.isNotEmpty) {
            _video = recipe.videoUrl;
          }
          if (recipe.videoCoverUrl != null && recipe.videoCoverUrl!.isNotEmpty) {
            _videoCustomCover = recipe.videoCoverUrl;
          }
        });

        if (_video is String) {
          _initNetworkVideoPlayer(_video as String);
        }
      } else {
        if (mounted) {
          _showSnackBar(result['error'] ?? 'Failed to load recipe');
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
        _isLoadingRecipe = false;
      });
    }
  }

  Future<void> _initNetworkVideoPlayer(String url) async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
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

  // ============================================================
  // Steps Methods
  // ============================================================
  void _addOrUpdateStep() {
    if (_stepInstructionController.text.isEmpty) {
      _showSnackBar('Please enter step instruction');
      return;
    }

    setState(() {
      final step = StepItem(
        instruction: _stepInstructionController.text,
        note: _stepNoteController.text.isNotEmpty ? _stepNoteController.text : null,
      );

      if (_editingStepIndex != null) {
        _steps[_editingStepIndex!] = step;
        _editingStepIndex = null;
      } else {
        _steps.add(step);
      }

      _stepInstructionController.clear();
      _stepNoteController.clear();
      _showNoteField = false;
    });
  }

  void _editStep(int index) {
    setState(() {
      _editingStepIndex = index;
      _stepInstructionController.text = _steps[index].instruction;
      if (_steps[index].note != null && _steps[index].note!.isNotEmpty) {
        _stepNoteController.text = _steps[index].note!;
        _showNoteField = true;
      } else {
        _stepNoteController.clear();
        _showNoteField = false;
      }
    });
  }

  void _deleteStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  // ============================================================
  // Helper Methods
  // ============================================================
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _isFile(dynamic item) => item is File;

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
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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

  // ============================================================
  // Submit Form
  // ============================================================
  Future<void> _submitRecipe() async {
    final token = ApiService.authToken;
    if (token == null || token.isEmpty) {
      _showSnackBar('Please login first');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_title.isEmpty) {
      _showSnackBar('Please enter title');
      return;
    }
    if (_description.isEmpty) {
      _showSnackBar('Please enter description');
      return;
    }
    if (_steps.isEmpty) {
      _showSnackBar('Please add at least one step');
      return;
    }
    if (_photos.isEmpty && _video == null) {
      _showSnackBar('Please add at least one photo or video');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
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

        // Video 处理
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
          // 如果 video 存在但 cover 为空，不主动删（保守）
          if (_video == null) {
            removeVideoCover = true;
          }
        } else if (_videoCustomCover is File) {
          newVideoCover = _videoCustomCover as File;
        } else if (_videoCustomCover is String) {
          existingVideoCoverUrl = _videoCustomCover as String;
        }

        result = await RecipeService.updateRecipe(
          recipeId: widget.editRecipeId!,
          title: _title,
          description: _description,
          cuisineType: _cuisineType,
          durationMinutes: _durationMinutes,
          difficultyLevel: _difficultyLevel,
          tags: _tags,
          cookingTools: _cookingTools,
          ingredients: _ingredients,
          steps: _steps,
          existingPhotoUrls: existingPhotoUrls,
          newPhotos: newPhotos,
          existingVideoUrl: existingVideoUrl,
          newVideo: newVideo,
          existingVideoCoverUrl: existingVideoCoverUrl,
          newVideoCover: newVideoCover,
          removeVideo: removeVideo,
          removeVideoCover: removeVideoCover,
          token: token,
        );
      } else {
        // Create 模式
        final filePhotos = _photos.whereType<File>().toList();
        result = await RecipeService.createRecipe(
          title: _title,
          description: _description,
          cuisineType: _cuisineType,
          durationMinutes: _durationMinutes,
          difficultyLevel: _difficultyLevel,
          tags: _tags,
          cookingTools: _cookingTools,
          ingredients: _ingredients,
          steps: _steps,
          photos: filePhotos,
          video: _video is File ? _video as File : null,
          videoCover: _videoCustomCover is File ? _videoCustomCover as File : null,
          token: token,
        );
      }

      if (mounted) Navigator.pop(context); // 关 loading

      if (result['success'] == true || result['id'] != null) {
        _showSnackBar(_isEditMode
            ? 'Recipe updated successfully!'
            : 'Recipe posted successfully!');
        if (mounted) Navigator.pop(context, true); // 带刷新标记
      } else {
        _showSnackBar(result['error'] ?? 'Failed to save recipe');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error: $e');
    }
  }

  // ============================================================
  // Build UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingRecipe) {
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
          _isEditMode ? 'Edit Recipe' : 'Add New Recipe',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        centerTitle: true,
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
              _buildDescriptionSection(),
              const SizedBox(height: 16),
              _buildTagsSection(),
              const SizedBox(height: 16),
              _buildCuisineSection(),
              const SizedBox(height: 16),
              _buildDurationSection(),
              const SizedBox(height: 16),
              _buildDifficultySection(),
              const SizedBox(height: 16),
              _buildCookingToolsSection(),
              const SizedBox(height: 16),
              _buildIngredientsSection(),
              const SizedBox(height: 16),
              _buildStepsSection(),
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
  // UI Sections
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
    final photo = _photos[index];
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
                image: _getImageProvider(photo),
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
            hintText: 'e.g., Fluffy Japanese Pancakes',
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

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        _buildWordCounterTextField(),
      ],
    );
  }

  Widget _buildWordCounterTextField() {
    int wordCount = _description.trim().isEmpty
        ? 0
        : _description.trim().split(RegExp(r'\s+')).length;
    bool isExceeded = wordCount > 200;

    return StatefulBuilder(
      builder: (context, setStateInner) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _descriptionController,
              onChanged: (text) {
                final words = text.trim().isEmpty ? [] : text.trim().split(RegExp(r'\s+'));
                setStateInner(() {
                  wordCount = words.length;
                  isExceeded = wordCount > 200;
                });
                if (!isExceeded) {
                  _description = text;
                }
              },
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your recipe (max 200 words)...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: isExceeded ? Colors.red : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: isExceeded ? Colors.red : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFFFFD966), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$wordCount/200 words',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isExceeded ? Colors.red : Colors.grey.shade600,
                  fontWeight: isExceeded ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isExceeded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Maximum 200 words allowed',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

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
                  hintText: 'Add a tag (e.g., Breakfast)',
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

  Widget _buildCuisineSection() {
    final List<String> cuisineOptions = [
      'Japanese', 'Italian', 'Korean', 'French',
      'Chinese', 'Thai', 'Indian', 'American',
      'Mexican', 'Vietnamese', 'Greek', 'Spanish'
    ];

    return StatefulBuilder(
      builder: (context, setStateInner) {
        bool isAddingOtherCuisine = false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuisine Type',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF6B4C2A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...cuisineOptions.map((cuisine) {
                  final isSelected = _cuisineType == cuisine;
                  return GestureDetector(
                    onTap: () {
                      setStateInner(() {
                        _cuisineType = isSelected ? '' : cuisine;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFD966) : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFD966) : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check, size: 16, color: Color(0xFF6B4C2A)),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            cuisine,
                            style: TextStyle(
                              color: const Color(0xFF6B4C2A),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (!isAddingOtherCuisine)
                  GestureDetector(
                    onTap: () {
                      setStateInner(() {
                        isAddingOtherCuisine = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add, size: 18, color: Color(0xFFFFB347)),
                          SizedBox(width: 4),
                          Text('Other', style: TextStyle(color: Color(0xFFFFB347))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (isAddingOtherCuisine)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cuisineController,
                        decoration: InputDecoration(
                          hintText: 'Enter custom cuisine...',
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
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (_cuisineController.text.isNotEmpty) {
                          setStateInner(() {
                            _cuisineType = _cuisineController.text;
                            _cuisineController.clear();
                            isAddingOtherCuisine = false;
                          });
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Color(0xFFFFB347)),
                    ),
                    IconButton(
                      onPressed: () {
                        setStateInner(() {
                          isAddingOtherCuisine = false;
                          _cuisineController.clear();
                        });
                      },
                      icon: const Icon(Icons.cancel, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            if (_cuisineType.isNotEmpty && !cuisineOptions.contains(_cuisineType))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD966),
                    border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_cuisineType, style: const TextStyle(color: Color(0xFF6B4C2A))),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setStateInner(() {
                            _cuisineType = '';
                          });
                        },
                        child: const Icon(Icons.close, size: 16, color: Color(0xFFFFB347)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        _buildDurationSlider(),
      ],
    );
  }

  Widget _buildDurationSlider() {
    double sliderValue = _durationMinutes <= 60
        ? _durationMinutes / 60
        : 1 + (_durationMinutes - 60) / 240;
    if (_durationMinutes >= 300) sliderValue = 2.0;

    return Column(
      children: [
        Slider(
          value: sliderValue.clamp(0, 2),
          min: 0,
          max: 2.0,
          divisions: 200,
          activeColor: const Color(0xFFFFB347),
          inactiveColor: const Color(0xFFFFD966),
          onChanged: (double newValue) {
            setState(() {
              int minutes;
              if (newValue <= 1.0) {
                minutes = (newValue * 60).round();
              } else if (newValue <= 2.0) {
                minutes = 60 + ((newValue - 1) * 240).round();
              } else {
                minutes = 300;
              }
              _durationMinutes = minutes.clamp(1, 300);
            });
          },
        ),
        Text(
          _getFormattedDuration(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
      ],
    );
  }

  String _getFormattedDuration() {
    if (_durationMinutes >= 300) return '5+ hours';
    if (_durationMinutes >= 60) {
      double hours = _durationMinutes / 60.0;
      return '${hours.toStringAsFixed(1)} hours';
    }
    return '$_durationMinutes min${_durationMinutes == 1 ? '' : 's'}';
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Difficulty Level',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStarButton(1),
            const SizedBox(width: 8),
            _buildStarButton(2),
            const SizedBox(width: 8),
            _buildStarButton(3),
            const SizedBox(width: 8),
            _buildStarButton(4),
            const SizedBox(width: 8),
            _buildStarButton(5),
            const SizedBox(width: 12),
            Text(
              _getDifficultyText(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF6B4C2A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStarButton(int starValue) {
    return IconButton(
      onPressed: () {
        setState(() {
          _difficultyLevel = starValue;
        });
      },
      icon: Icon(
        starValue <= _difficultyLevel ? Icons.star : Icons.star_border,
        color: const Color(0xFFFFB347),
        size: 40,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  String _getDifficultyText() {
    switch (_difficultyLevel) {
      case 1: return 'Very Easy';
      case 2: return 'Easy';
      case 3: return 'Medium';
      case 4: return 'Hard';
      case 5: return 'Very Hard';
      default: return 'Medium';
    }
  }

  Widget _buildCookingToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cooking Tools',
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
                controller: _toolController,
                decoration: InputDecoration(
                  hintText: 'Add a tool (e.g., Pan, Oven)',
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
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                if (_toolController.text.isNotEmpty) {
                  setState(() {
                    _cookingTools.add(_toolController.text);
                    _toolController.clear();
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
          children: _cookingTools.map((tool) {
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
                  Text(tool, style: const TextStyle(color: Color(0xFF6B4C2A))),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _cookingTools.remove(tool);
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

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ingredientNameController,
          decoration: InputDecoration(
            hintText: 'Ingredient name',
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ingredientAmountController,
          decoration: InputDecoration(
            hintText: 'Amount (e.g., 250g)',
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton(
            onPressed: () {
              if (_ingredientNameController.text.isNotEmpty) {
                setState(() {
                  _ingredients.add(IngredientItem(
                    name: _ingredientNameController.text,
                    amount: _ingredientAmountController.text,
                  ));
                  _ingredientNameController.clear();
                  _ingredientAmountController.clear();
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD966),
              foregroundColor: const Color(0xFF6B4C2A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Add Ingredient'),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ingredients.length,
          itemBuilder: (context, index) {
            final ingredient = _ingredients[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0D6),
                border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFFFFB347), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: const TextStyle(
                            color: Color(0xFF6B4C2A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (ingredient.amount.isNotEmpty)
                          Text(
                            ingredient.amount,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _ingredients.removeAt(index);
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFFFD966), width: 1.5),
          ),
          child: Column(
            children: [
              TextField(
                controller: _stepInstructionController,
                decoration: InputDecoration(
                  hintText: 'Step instruction',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFFFB347), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 2,
              ),
              if (_showNoteField) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _stepNoteController,
                  decoration: InputDecoration(
                    hintText: 'Note (optional)',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFFFFD966), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Color(0xFFFFB347), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!_showNoteField)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showNoteField = true;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFB347),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        '+ Add note (optional)',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFB347),
                        ),
                      ),
                    ),
                  if (_showNoteField)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showNoteField = false;
                          _stepNoteController.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFB347),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Hide note',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFB347),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (_editingStepIndex != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingStepIndex = null;
                          _stepInstructionController.clear();
                          _stepNoteController.clear();
                          _showNoteField = false;
                        });
                      },
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addOrUpdateStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD966),
                      foregroundColor: const Color(0xFF6B4C2A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text(_editingStepIndex != null ? 'Update' : 'Add Step'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _steps.length,
          itemBuilder: (context, index) {
            final step = _steps[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFFD966), width: 1.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD966),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF6B4C2A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            color: Color(0xFF6B4C2A),
                          ),
                        ),
                        if (step.note != null && step.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Note: ${step.note}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Color(0xFFFFB347)),
                        onPressed: () => _editStep(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => _deleteStep(index),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildButtonsSection() {
    final isValid = _title.isNotEmpty && _description.isNotEmpty && _steps.isNotEmpty;

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
            onPressed: isValid ? _submitRecipe : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD966),
              foregroundColor: const Color(0xFF6B4C2A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 2,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: Text(
              _isEditMode ? 'Save' : 'Upload',
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