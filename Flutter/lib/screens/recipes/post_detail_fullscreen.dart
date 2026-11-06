// screens/recipes/post_detail_fullscreen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullscreenMediaItem {
  final bool isVideo;
  final String url;

  const FullscreenMediaItem({required this.isVideo, required this.url});
}

class FullscreenMediaScreen extends StatefulWidget {
  final List<FullscreenMediaItem> items;
  final int startIndex;

  const FullscreenMediaScreen({
    super.key,
    required this.items,
    required this.startIndex,
  });

  @override
  State<FullscreenMediaScreen> createState() => _FullscreenMediaScreenState();
}

class _FullscreenMediaScreenState extends State<FullscreenMediaScreen> {
  late final PageController _pageController;
  late int _index;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    _pageController = PageController(initialPage: _index);
    _loadVideoForIndex(_index);
  }

  Future<void> _loadVideoForIndex(int i) async {
    _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;

    if (i < 0 || i >= widget.items.length) return;
    final item = widget.items[i];
    if (!item.isVideo) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(item.url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      _videoController = controller;
      _videoInitialized = true;
      controller.play();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {});
    } catch (e) {
      debugPrint('Fullscreen video error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _formatVideoTime(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_index + 1}/${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) {
          setState(() => _index = i);
          _loadVideoForIndex(i);
        },
        itemBuilder: (context, i) {
          final item = widget.items[i];
          if (item.isVideo) {
          if (i != _index) return const SizedBox.shrink();
          if (_videoController == null || !_videoInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            );
          }

          final video = _videoController!;
          final aspect = video.value.aspectRatio;

          return Column(
            children: [
              // Video (centered, natural aspect)
              Expanded(
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      if (video.value.isPlaying) {
                        await video.pause();
                      } else {
                        if (video.value.position >= video.value.duration) {
                          await video.seekTo(Duration.zero);
                        }
                        await video.play();
                      }
                      if (mounted) setState(() {});
                    },
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(video),
                          if (!video.value.isPlaying)
                            IgnorePointer(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(16),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Progress bar below video
              Container(
                color: Colors.black,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        video,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFFFFB347),
                          bufferedColor: Colors.white54,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatVideoTime(video.value.position),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _formatVideoTime(video.value.duration),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
          return PhotoView(
            imageProvider: CachedNetworkImageProvider(item.url),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            initialScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            enableRotation: false,
          );
        },
      ),
    );
  }
}