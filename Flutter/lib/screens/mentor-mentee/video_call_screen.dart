// lib/screens/mentor-mentee/video_call_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:peer_rtc/peer_rtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_service.dart';
import 'call_recipe_panel.dart';

class VideoCallScreen extends StatefulWidget {
  final String contactName;
  final String contactAvatar;
  final bool isMentor;
  final String? roomId;
  final bool isCaller;
  final String? callReceiverId;
  final String callType;

  const VideoCallScreen({
    super.key,
    required this.contactName,
    required this.contactAvatar,
    required this.isMentor,
    this.roomId,
    this.isCaller = false,
    this.callReceiverId,
    this.callType = 'video',
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // ========== UI State ==========
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOn = true;
  bool _showTutorial = false;
  bool _showRecipeSelector = false;
  bool _recipeDetailLoading = false;
  Map<String, dynamic>? _selectedRecipe;
  int _currentStep = 0;
  int _timerSeconds = 0;
  bool _recipesLoading = false;

  // ========== WebRTC ==========
  Peer? _peer;
  MediaConnection? _call;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _isConnected = false;
  bool _isCalling = false;
  String? _myPeerId;
  final TextEditingController _peerIdController = TextEditingController();
  StreamSubscription? _streamSubscription;
  StreamSubscription? _callSubscription;
  bool _isDisposed = false;
  bool _isFrontCamera = true;
  bool _remoteCallStarted = false;
  Timer? _peerIdPollTimer;
  Timer? _roomStatusPollTimer;
  Timer? _timerTick;

  // ========== Audio ==========
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // ========== SFX WS ==========
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  // ========== Recipes ==========
  List<Map<String, dynamic>> _availableRecipes = [];

  @override
  void initState() {
    super.initState();
    _initWebRTC();
    _startRoomStatusPolling();
    _startSfxWebSocket();
  }

  void _startTimer() {
    _timerTick?.cancel();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isDisposed) return;
      setState(() => _timerSeconds++);
    });
  }

  // ==================== WebRTC ====================
  Future<void> _initWebRTC() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();

      _peer = Peer();

      _peer!.onOpen.listen((id) async {
        if (id == null || id.isEmpty) return;
        if (mounted) setState(() => _myPeerId = id);
        if (widget.isCaller) {
          if (widget.roomId != null) {
            await ApiService.updateCallRoomPeerId(
              roomId: widget.roomId!,
              peerId: id,
            );
          }
        } else {
          _startPollingCallerPeerId();
        }
      });
    } catch (e) {
      debugPrint('Error creating Peer: $e');
    }

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': widget.callType == 'video'
            ? {
                'facingMode': 'user',
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }
            : false,
      });
      _localRenderer.srcObject = _localStream;
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('getUserMedia failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot access camera: $e')),
        );
      }
      return;
    }

    _callSubscription = _peer!.onCall.listen((call) {
      if (_isDisposed) return;
      _call = call;
      _isCalling = false;

      if (_localStream == null) {
        call.close();
        return;
      }
      call.answer(_localStream!);

      _streamSubscription = call.onStream.listen((remoteStream) {
        if (_isDisposed) return;
        _remoteRenderer.srcObject = remoteStream;
        if (mounted) {
          setState(() => _isConnected = true);
          _startTimer();
        }
      });
    });
  }

  void _startPollingCallerPeerId() {
    if (widget.roomId == null) return;
    _peerIdPollTimer?.cancel();
    _peerIdPollTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_isDisposed || _remoteCallStarted) {
        timer.cancel();
        return;
      }
      final res = await ApiService.getCallRoom(widget.roomId!);
      if (res['success'] != true) return;
      final callerPeerId = res['data']?['caller_peer_id']?.toString() ?? '';
      if (callerPeerId.isNotEmpty) {
        timer.cancel();
        _remoteCallStarted = true;
        await _makeCallTo(callerPeerId);
      }
    });
  }

  void _startRoomStatusPolling() {
    if (widget.roomId == null) return;
    _roomStatusPollTimer?.cancel();
    _roomStatusPollTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      final res = await ApiService.getCallRoom(widget.roomId!);
      if (res['success'] != true) return;
      final isActive = res['data']?['is_active'] == true;
      if (!isActive) {
        timer.cancel();
        if (mounted) _endCall(notifyServer: false);
      }
    });
  }

  Future<void> _makeCallTo(String remoteId) async {
    if (_localStream == null) return;
    setState(() => _isCalling = true);
    _call = _peer!.call(remoteId, _localStream!);
    _streamSubscription = _call!.onStream.listen((remoteStream) {
      if (_isDisposed) return;
      _remoteRenderer.srcObject = remoteStream;
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isCalling = false;
        });
        _startTimer();
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    try {
      await Helper.switchCamera(videoTracks.first);
      setState(() => _isFrontCamera = !_isFrontCamera);
    } catch (e) {
      debugPrint('switchCamera failed: $e');
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleCamera() {
    setState(() => _isCameraOn = !_isCameraOn);
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isCameraOn;
    });
  }

  Future<void> _toggleSpeaker() async {
    final turnOn = !_isSpeakerOn;
    setState(() => _isSpeakerOn = turnOn);
    try {
      await Helper.setSpeakerphoneOn(turnOn);
    } catch (e) {
      debugPrint('setSpeakerphoneOn failed: $e');
    }
  }

  Future<void> _endCall({bool notifyServer = true}) async {
    if (notifyServer && widget.roomId != null) {
      await ApiService.endCallRoom(widget.roomId!, _timerSeconds);
    }
    _timerTick?.cancel();
    _call?.close();
    _streamSubscription?.cancel();
    _callSubscription?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _peerIdPollTimer?.cancel();
    _roomStatusPollTimer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peer?.dispose();
    if (mounted) Navigator.pop(context);
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // ==================== SFX ====================
  void _startSfxWebSocket() {
    if (widget.roomId == null) return;
    final myUserId = ApiService.currentUserId;
    if (myUserId == null) return;

    final wsUrl = ApiService.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api', '');
    final uri = Uri.parse('$wsUrl/ws/call/$myUserId/');

    try {
      _wsChannel = WebSocketChannel.connect(uri);
      _wsSubscription = _wsChannel!.stream.listen((event) {
        try {
          final data = jsonDecode(event);
          if (data['type'] == 'call_sfx') {
            final sfx = data['sfx']?.toString();
            if (sfx != null) _playSfxLocal(sfx);
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('ws sfx failed: $e');
    }
  }

  Future<void> _playSfxLocal(String name) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('sounds/$name.mp3'));
    } catch (e) {
      debugPrint('play sfx failed: $e');
    }
  }

  Future<void> _triggerSfx(String name) async {
    await _playSfxLocal(name);
    if (widget.roomId != null) {
      await ApiService.sendSfx(widget.roomId!, name);
    }
  }

  void _showSoundEffectsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sound Effects',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSoundEffectItem(Icons.celebration, 'Cheer', () {
                    Navigator.pop(context);
                    _triggerSfx('cheer');
                  }),
                  _buildSoundEffectItem(Icons.emoji_emotions, 'Applause', () {
                    Navigator.pop(context);
                    _triggerSfx('applause');
                  }),
                  _buildSoundEffectItem(Icons.music_note, 'Cook', () {
                    Navigator.pop(context);
                    _triggerSfx('cook');
                  }),
                  _buildSoundEffectItem(Icons.celebration, 'Confetti', () {
                    Navigator.pop(context);
                    _triggerSfx('confetti');
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSoundEffectItem(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB347).withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFFB347), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ==================== Recipe ====================
  Future<void> _loadLikedRecipes() async {
    setState(() => _recipesLoading = true);
    try {
      final token = ApiService.authToken;
      if (token == null) {
        setState(() => _recipesLoading = false);
        return;
      }
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/recipes/liked/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _availableRecipes = data.map((json) {
            final r = json as Map<String, dynamic>;
            return {
              'id': r['id']?.toString() ?? '',
              'title': r['title']?.toString() ?? '',
              'duration': r['duration_minutes'] != null
                  ? '${r['duration_minutes']} mins'
                  : '',
              'difficulty': r['difficulty']?.toString() ?? '',
              'steps': <String>[],
              'ingredients': <Map<String, String>>[],
            };
          }).toList();
          _recipesLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('load liked recipes error: $e');
    }
    if (mounted) setState(() => _recipesLoading = false);
  }

  void _showRecipeSelection() async {
    await _loadLikedRecipes();
    if (!mounted) return;
    setState(() => _showRecipeSelector = true);
  }

  void _closeRecipeSelector() => setState(() => _showRecipeSelector = false);

  Future<void> _selectRecipe(Map<String, dynamic> recipe) async {
    final recipeId = recipe['id']?.toString() ?? '';
    setState(() {
      _selectedRecipe = {
        ...recipe,
        'steps': <String>[],
        'ingredients': <Map<String, String>>[],
      };
      _currentStep = 0;
      _showTutorial = true;
      _showRecipeSelector = false;
      _recipeDetailLoading = true;
    });

    if (recipeId.isEmpty) {
      if (mounted) setState(() => _recipeDetailLoading = false);
      return;
    }

    try {
      final token = ApiService.authToken;
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/recipes/$recipeId/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (!mounted || response.statusCode != 200) {
        if (mounted) setState(() => _recipeDetailLoading = false);
        return;
      }
      final detail = jsonDecode(response.body) as Map<String, dynamic>;
      final steps = _extractSteps(detail);
      final ingredients = _extractIngredientsDetailed(detail);

      setState(() {
        _selectedRecipe = {
          ...recipe,
          'title': detail['title']?.toString() ?? recipe['title'],
          'steps': steps,
          'ingredients': ingredients,
        };
        _recipeDetailLoading = false;
      });
    } catch (e) {
      debugPrint('load recipe detail error: $e');
      if (mounted) setState(() => _recipeDetailLoading = false);
    }
  }

  List<String> _extractSteps(Map<String, dynamic> r) {
    final raw = r['steps'] ?? r['instructions'];
    if (raw is List) {
      return raw.map((e) {
        if (e is String) return e;
        if (e is Map) {
          return e['instruction']?.toString() ??
              e['text']?.toString() ??
              e['description']?.toString() ??
              e['content']?.toString() ??
              e.toString();
        }
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  List<Map<String, String>> _extractIngredientsDetailed(
      Map<String, dynamic> r) {
    final raw = r['ingredients'];
    if (raw is List) {
      return raw.map((e) {
        if (e is String) return {'name': e, 'amount': ''};
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          final qty =
              e['quantity']?.toString() ?? e['amount']?.toString() ?? '';
          final unit = e['unit']?.toString() ?? '';
          final amount = [qty, unit].where((x) => x.isNotEmpty).join(' ');
          return {'name': name, 'amount': amount};
        }
        return {'name': e.toString(), 'amount': ''};
      }).where((m) => (m['name'] ?? '').isNotEmpty).toList();
    }
    return [];
  }

  void _nextStep() {
    if (_selectedRecipe == null) return;
    final raw = _selectedRecipe!['steps'];
    final steps = raw is List ? raw : const [];
    final totalSteps = steps.length;

    if (_currentStep < totalSteps) {
      setState(() => _currentStep++);
    } else {
      setState(() {
        _showTutorial = false;
        _selectedRecipe = null;
        _currentStep = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tutorial completed! Great job!'),
          backgroundColor: Color(0xFFFFB347),
        ),
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _exitTutorial() {
    setState(() {
      _showTutorial = false;
      _selectedRecipe = null;
      _currentStep = 0;
    });
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _timerTick?.cancel();
    _peerIdPollTimer?.cancel();
    _roomStatusPollTimer?.cancel();
    _streamSubscription?.cancel();
    _callSubscription?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _call?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    _peer?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _peerIdController.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video
          Positioned.fill(
            child: _isConnected && _remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _remoteRenderer,
                    mirror: false,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: Colors.grey.shade900,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: widget.contactAvatar.isNotEmpty
                                ? NetworkImage(widget.contactAvatar)
                                : null,
                            child: widget.contactAvatar.isEmpty
                                ? const Icon(Icons.person,
                                    size: 60, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.contactName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (_isConnected
                                      ? Colors.green
                                      : _isCalling
                                          ? Colors.blue
                                          : Colors.orange)
                                  .withAlpha(51),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isConnected
                                  ? 'Connected'
                                  : _isCalling
                                      ? 'Calling...'
                                      : 'Waiting...',
                              style: TextStyle(
                                color: _isConnected
                                    ? Colors.green
                                    : _isCalling
                                        ? Colors.blue
                                        : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Local video
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB347), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _isCameraOn && _localRenderer.srcObject != null
                    ? RTCVideoView(
                        _localRenderer,
                        mirror: _isFrontCamera,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.videocam_off,
                            color: Colors.white54, size: 40),
                      ),
              ),
            ),
          ),

          // Call duration
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_timerSeconds),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // 控制按钮
          Positioned(
            left: 16,
            bottom: _showTutorial ? 120 : 40,
            child: Column(
              children: [
                _buildControlButton(
                  icon: _isSpeakerOn
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  label: 'Speaker',
                  onTap: _toggleSpeaker,
                ),
                const SizedBox(height: 20),
                _buildControlButton(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: 'Mute',
                  onTap: _toggleMute,
                ),
                const SizedBox(height: 20),
                _buildControlButton(
                  icon: _isCameraOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  label: 'Camera',
                  onTap: _toggleCamera,
                ),
                const SizedBox(height: 20),
                _buildControlButton(
                  icon: Icons.cameraswitch_rounded,
                  label: 'Flip',
                  onTap: _switchCamera,
                ),
                const SizedBox(height: 20),
                _buildControlButton(
                  icon: Icons.music_note_rounded,
                  label: 'Sounds',
                  onTap: _showSoundEffectsMenu,
                ),
                const SizedBox(height: 20),
                _buildControlButton(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Recipe',
                  onTap: _showRecipeSelection,
                ),
                const SizedBox(height: 20),
                _buildControlButton(
                  icon: Icons.call_end_rounded,
                  label: 'End',
                  color: Colors.red,
                  onTap: () => _endCall(notifyServer: true),
                ),
              ],
            ),
          ),

          // Recipe selector
          if (_showRecipeSelector)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Liked Recipes',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6B4C2A),
                              ),
                            ),
                            GestureDetector(
                              onTap: _closeRecipeSelector,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFF3E0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Color(0xFFFFB347),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 320,
                        child: _recipesLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFFFFB347)),
                              )
                            : _availableRecipes.isEmpty
                                ? Center(
                                    child: Text(
                                      'No liked recipes yet',
                                      style: GoogleFonts.poppins(
                                          color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    itemCount: _availableRecipes.length,
                                    itemBuilder: (context, index) {
                                      final recipe = _availableRecipes[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color:
                                                    const Color(0xFFFFF3E0),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.food_bank,
                                                color: Color(0xFFFFB347),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    recipe['title']
                                                            ?.toString() ??
                                                        '',
                                                    style: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: const Color(
                                                          0xFF6B4C2A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${recipe['duration'] ?? ''} - ${recipe['difficulty'] ?? ''}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: const Color(
                                                          0xFFC9A96E),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _selectRecipe(recipe),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFFFB347),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(25),
                                                ),
                                              ),
                                              child: const Text(
                                                'Cook',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

          // Tutorial panel（拆分到 CallRecipePanel）
          if (_showTutorial && _selectedRecipe != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.48,
              child: CallRecipePanel(
                recipe: _selectedRecipe!,
                currentStep: _currentStep,
                loading: _recipeDetailLoading,
                onPrev: _prevStep,
                onNext: _nextStep,
                onClose: _exitTutorial,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}