// lib/screens/mentor-mentee/chat_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import '../../models/chat_message_model.dart';
import '../../services/api_service.dart';
import '../../utils/sticker_assets.dart';
import '../profile/user_profile_screen.dart';
import 'video_call_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String otherUserId;
  final String contactName;
  final String contactAvatar;
  final bool isMentor;
  final Map<String, dynamic>? initialMessage;

  const ChatDetailScreen({
    super.key,
    required this.otherUserId,
    required this.contactName,
    required this.contactAvatar,
    this.isMentor = false,
    this.initialMessage,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessageModel> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _showMorePanel = false;
  bool _showStickerPanel = false;
  bool _isLoading = true;
  bool _isStartingCall = false;
  Timer? _pollTimer;
  DateTime? _lastMessageTime;
  String? _myUserId;

  final Map<String, bool> _roomActiveMap = {};

  bool _isMyMentor = false;
  bool _isMyMentee = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      try {
        _messages.add(ChatMessageModel.fromJson(widget.initialMessage!));
        _lastMessageTime = _messages.last.createdAt;
      } catch (_) {}
    }
    _loadMyUserId();
    _loadMentorshipStatus();
    _loadMessages().then((_) async {
      await ApiService.markMessagesRead(widget.otherUserId);
    });
    _startPolling();
    // 不自动弹键盘
  }

  Future<void> _loadMyUserId() async {
    final result = await ApiService.getCurrentUserId();
    if (result['success'] == true && mounted) {
      setState(() => _myUserId = result['user_id']?.toString());
    }
  }

  Future<void> _loadMentorshipStatus() async {
    final res = await ApiService.checkMentorshipStatus(widget.otherUserId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _isMyMentor = res['is_my_mentor'] == true;
        _isMyMentee = res['is_my_mentee'] == true;
      });
    }
  }

  Future<void> _loadMessages() async {
    final result =
        await ApiService.getMessages(otherUserId: widget.otherUserId);
    if (!mounted) return;
    if (result['success'] == true) {
      final List<dynamic> raw = result['data'];
      final messages = raw
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isLoading = false;
        if (messages.isNotEmpty) _lastMessageTime = messages.last.createdAt;
      });
      _scrollToBottom();
      _refreshRoomStatuses(messages);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshRoomStatuses(List<ChatMessageModel> messages) async {
    final roomIds = messages
        .where((m) => m.messageType == 'call_invite')
        .map((m) => m.callRoomId)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet();
    if (roomIds.isEmpty) return;

    final updates = <String, bool>{};
    for (final rid in roomIds) {
      final res = await ApiService.getCallRoom(rid);
      if (res['success'] == true) {
        updates[rid] = res['data']?['is_active'] == true;
      } else {
        updates[rid] = false;
      }
    }
    if (mounted) {
      setState(() => _roomActiveMap.addAll(updates));
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollNewMessages();
    });
  }

  Future<void> _pollNewMessages() async {
    if (_lastMessageTime == null) return;
    final result = await ApiService.getMessages(
      otherUserId: widget.otherUserId,
      since: _lastMessageTime!.toIso8601String(),
    );
    if (!mounted || result['success'] != true) return;
    final List<dynamic> raw = result['data'];
    if (raw.isEmpty) return;
    final newMessages = raw
        .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() {
      _messages.addAll(newMessages);
      _lastMessageTime = newMessages.last.createdAt;
    });
    _scrollToBottom();
    _refreshRoomStatuses(newMessages);
    ApiService.markMessagesRead(widget.otherUserId);

    final hasMentorshipUpdate =
        newMessages.any((m) => m.messageType == 'mentorship_request');
    if (hasMentorshipUpdate) _loadMentorshipStatus();
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempMsg = ChatMessageModel(
      id: -1,
      senderId: _myUserId ?? '',
      receiverId: widget.otherUserId,
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMsg);
      _messageController.clear();
      _showMorePanel = false;
      _showStickerPanel = false;
    });
    _scrollToBottom();

    final result = await ApiService.sendMessage(
      receiverId: widget.otherUserId,
      text: text,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      final real = ChatMessageModel.fromJson(result['data']);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == -1);
        if (idx != -1) _messages[idx] = real;
        _lastMessageTime = real.createdAt;
      });
    } else {
      setState(() => _messages.removeWhere((m) => m.id == -1));
    }
  }

  // ==================== Image / Video pick ====================

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (photo == null) return;
    setState(() => _showMorePanel = false);
    await _sendMedia(File(photo.path), 'image');
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia();
    if (picked == null) return;
    setState(() => _showMorePanel = false);

    final isVideo = _isVideoPath(picked.path);

    if (isVideo) {
      final file = File(picked.path);
      final bytes = await file.length();
      const maxBytes = 20 * 1024 * 1024;
      if (bytes > maxBytes) {
        if (!mounted) return;
        _showDialog(
          title: 'Video too large',
          message: 'Videos must be 20MB or smaller.',
        );
        return;
      }
      final durationOk = await _checkVideoDuration(file);
      if (!durationOk) {
        if (!mounted) return;
        _showDialog(
          title: 'Video too long',
          message: 'Videos must be 1 minute or shorter.',
        );
        return;
      }
    }

    await _sendMedia(File(picked.path), isVideo ? 'video' : 'image');
  }

  Future<bool> _checkVideoDuration(File file) async {
    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final ok = controller.value.duration.inSeconds <= 60;
      await controller.dispose();
      return ok;
    } catch (e) {
      debugPrint('Duration check failed: $e');
      return false;
    }
  }

  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv') ||
        p.endsWith('.3gp') ||
        p.endsWith('.webm');
  }

  void _showDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFFB347),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMedia(File file, String type) async {
    final temp = ChatMessageModel(
      id: -1,
      senderId: _myUserId ?? '',
      receiverId: widget.otherUserId,
      text: '',
      messageType: type,
      mediaUrl: file.path,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(temp));
    _scrollToBottom();

    final res = await ApiService.sendMediaMessage(
      receiverId: widget.otherUserId,
      messageType: type,
      file: file,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      final real = ChatMessageModel.fromJson(res['data']);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == -1);
        if (idx != -1) _messages[idx] = real;
        _lastMessageTime = real.createdAt;
      });
    } else {
      setState(() => _messages.removeWhere((m) => m.id == -1));
      _showDialog(
        title: 'Send failed',
        message: res['error']?.toString() ?? 'Unknown error',
      );
    }
  }

  // ==================== Stickers ====================

  Future<void> _sendSticker(StickerAsset sticker) async {
    final marker = 'sticker:${sticker.id}';

    final temp = ChatMessageModel(
      id: -1,
      senderId: _myUserId ?? '',
      receiverId: widget.otherUserId,
      text: marker,
      messageType: 'text',
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.add(temp);
      _showStickerPanel = false;
    });
    _scrollToBottom();

    final res = await ApiService.sendMessage(
      receiverId: widget.otherUserId,
      text: marker,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      final real = ChatMessageModel.fromJson(res['data']);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == -1);
        if (idx != -1) _messages[idx] = real;
        _lastMessageTime = real.createdAt;
      });
    } else {
      setState(() => _messages.removeWhere((m) => m.id == -1));
    }
  }

  // ==================== Calls ====================

  Future<void> _startVideoCall() async {
    if (_isStartingCall) return;
    setState(() => _isStartingCall = true);

    final res = await ApiService.createCallRoom(
      receiverId: widget.otherUserId,
      callType: 'video',
    );

    if (!mounted) return;
    setState(() => _isStartingCall = false);

    if (res['success'] != true) {
      _showDialog(
        title: 'Call failed',
        message: res['error']?.toString() ?? 'Unknown error',
      );
      return;
    }

    final data = res['data'] as Map<String, dynamic>;
    final roomId = data['room_id'].toString();

    if (data['message'] is Map<String, dynamic>) {
      final msg = ChatMessageModel.fromJson(
        data['message'] as Map<String, dynamic>,
      );
      setState(() {
        _messages.add(msg);
        _roomActiveMap[roomId] = true;
      });
      _lastMessageTime = msg.createdAt;
      _scrollToBottom();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          contactName: widget.contactName,
          contactAvatar: widget.contactAvatar,
          isMentor: widget.isMentor,
          roomId: roomId,
          callReceiverId: widget.otherUserId,
          isCaller: true,
        ),
      ),
    );
    if (mounted) {
      setState(() => _roomActiveMap[roomId] = false);
      _loadMessages();
    }
  }

  void _joinCallFromInvite(String roomId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          contactName: widget.contactName,
          contactAvatar: widget.contactAvatar,
          isMentor: widget.isMentor,
          roomId: roomId,
          callReceiverId: widget.otherUserId,
          isCaller: false,
        ),
      ),
    );
    if (mounted) {
      setState(() => _roomActiveMap[roomId] = false);
      _loadMessages();
    }
  }

  // ==================== Chat menu (Clear Chat History) ====================

  void _showChatMenu() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.cleaning_services_outlined,
                color: Colors.red,
              ),
              title: Text(
                'Clear Chat History',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              subtitle: Text(
                'Only for you. The other person can still see the messages.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmClearChat();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Clear Chat History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Text(
          'This will clear the chat history on your side only. '
          'The other person will still be able to see all messages. '
          'This action cannot be undone.',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await ApiService.clearChatHistory(
      otherUserId: widget.otherUserId,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _messages.clear();
        _lastMessageTime = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat history cleared'),
          backgroundColor: Color(0xFF00B894),
        ),
      );
      // Go back to the conversation list so the cleared state is visible.
      Navigator.pop(context);
    } else {
      _showDialog(
        title: 'Failed',
        message: res['error']?.toString() ?? 'Unknown error',
      );
    }
  }

  // ==================== Helpers ====================

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int? _findCallEndSeconds(DateTime inviteTime) {
    for (final m in _messages) {
      if (m.messageType == 'call_end' && m.createdAt.isAfter(inviteTime)) {
        final parts = m.text.split(':');
        if (parts.length == 2) {
          return int.tryParse(parts[1].trim());
        }
      }
    }
    return null;
  }

  String _fmtDuration(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateSeparator(DateTime d) {
    // Convert UTC → local so "today" boundaries match the user's clock
    final local = d.isUtc ? d.toLocal() : d;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  // ==================== Panel toggles ====================

  void _toggleMorePanel() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showMorePanel = !_showMorePanel;
      _showStickerPanel = false;
    });
  }

  void _toggleStickerPanel() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showStickerPanel = !_showStickerPanel;
      _showMorePanel = false;
    });
  }

  void _onTextFieldTap() {
    if (_showMorePanel || _showStickerPanel) {
      setState(() {
        _showMorePanel = false;
        _showStickerPanel = false;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final visibleMessages =
        _messages.where((m) => m.messageType != 'call_end').toList();

    final List<Widget> children = [];
    for (int i = 0; i < visibleMessages.length; i++) {
      final msg = visibleMessages[i];
      if (i == 0) {
        children.add(_buildDateSeparator(msg.createdAt));
      } else if (!_isSameDay(visibleMessages[i - 1].createdAt, msg.createdAt)) {
        children.add(_buildDateSeparator(msg.createdAt));
      }
      children.add(_buildMessageBubble(msg));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: widget.otherUserId,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundImage: widget.contactAvatar.isNotEmpty
                    ? NetworkImage(ApiService.resolveImageUrl(widget.contactAvatar))
                    : null,
                child: widget.contactAvatar.isEmpty
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.contactName,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: const Color(0xFF1A1A1A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isMyMentor) ...[
                    const SizedBox(width: 6),
                    _barTag('Your Mentor'),
                  ] else if (_isMyMentee) ...[
                    const SizedBox(width: 6),
                    _barTag('Your Mentee'),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
                actions: [
          IconButton(
            onPressed: _isStartingCall ? null : _startVideoCall,
            icon: _isStartingCall
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6B4C2A),
                    ),
                  )
                : const Icon(
                    Icons.videocam_outlined,
                    color: Color(0xFF6B4C2A),
                  ),
          ),
          IconButton(
            onPressed: _showChatMenu,
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF6B4C2A),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB347)),
                  )
                : visibleMessages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hi to start chatting!',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.white,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          children: children,
                        ),
                      ),
          ),
          _buildExpandablePanel(
            visible: _showMorePanel,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMoreAction(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: _pickImageFromCamera,
                ),
                _buildMoreAction(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: _pickFromGallery,
                ),
              ],
            ),
          ),
          _buildExpandablePanel(
            visible: _showStickerPanel,
            child: _buildStickerGrid(),
            height: 240,
          ),
          Container(
            padding:
                const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleMorePanel,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _showMorePanel
                          ? Colors.white
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: _showMorePanel
                          ? Border.all(color: const Color(0xFFFFB347), width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.add,
                      color: _showMorePanel
                          ? const Color(0xFFFFB347)
                          : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 16),
                    onTap: _onTextFieldTap,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      hintStyle:
                          TextStyle(fontSize: 16, color: Color(0xFF999999)),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleStickerPanel,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _showStickerPanel
                          ? Colors.white
                          : const Color(0xFFF5F5F5),
                      shape: BoxShape.circle,
                      border: _showStickerPanel
                          ? Border.all(color: const Color(0xFFFFB347), width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      color: _showStickerPanel
                          ? const Color(0xFFFFB347)
                          : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendText,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB347),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00B894).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF00B894),
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDateSeparator(date),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandablePanel({
    required bool visible,
    required Widget child,
    double height = 100,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      height: visible ? height : 0,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: height,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: kStickerAssets.length,
      itemBuilder: (context, i) {
        final s = kStickerAssets[i];
        return GestureDetector(
          onTap: () => _sendSticker(s),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              s.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                color: Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== Message bubbles ====================

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isMe = message.senderId == _myUserId;

    if (message.messageType == 'text' &&
        message.text.startsWith('sticker:')) {
      return _buildStickerFromText(message, isMe: isMe);
    }

    if (message.messageType == 'mentorship_request') {
      return _buildMentorshipRequestCard(message);
    }
    if (message.messageType == 'call_invite') {
      return _buildCallInviteCard(message, isMe: isMe);
    }
    if (message.messageType == 'sticker') {
      return _buildStickerBubble(message, isMe: isMe);
    }
    if (message.messageType == 'image' || message.messageType == 'video') {
      return _buildMediaBubble(message, isMe: isMe);
    }
    return _buildTextBubble(message, isMe: isMe);
  }

  Widget _buildStickerFromText(ChatMessageModel message, {required bool isMe}) {
    final id = message.text.substring('sticker:'.length);
    final sticker = stickerById(id);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: sticker != null
                  ? Image.asset(
                      sticker.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.emoji_emotions,
                        size: 80,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(
                      Icons.emoji_emotions,
                      size: 80,
                      color: Colors.grey,
                    ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentorshipRequestCard(ChatMessageModel message) {
    final isMe = message.senderId == _myUserId;
    final requestId = int.tryParse(message.relatedId) ?? 0;
    final isAccepted = message.text.toLowerCase().contains('accepted');
    final isDeclined = message.text.toLowerCase().contains('declined');

    if (isAccepted || isDeclined) {
      final color = Colors.grey.shade600;
      final icon = isAccepted ? Icons.check_circle : Icons.cancel;
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAccepted ? 'Mentorship accepted' : 'Mentorship declined',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (isAccepted)
                    Text(
                      isMe
                          ? '${widget.contactName} is now your mentor'
                          : 'You are now ${widget.contactName}\'s mentor',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    )
                  else
                    Text(
                      'Maybe next time',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final showActions = !isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(
                      userId: isMe ? message.receiverId : message.senderId,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFFFD966),
                    backgroundImage: widget.contactAvatar.isNotEmpty
                        ? NetworkImage(ApiService.resolveImageUrl(widget.contactAvatar))
                        : null,
                    child: widget.contactAvatar.isEmpty
                        ? const Icon(Icons.person,
                            size: 22, color: Color(0xFF6B4C2A))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contactName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B4C2A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'View profile',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFFFFB347),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFFFB347)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFFFF0B5), height: 1),
            const SizedBox(height: 12),
            Text(
              isMe
                  ? 'You asked ${widget.contactName} to be your mentor.'
                  : '${widget.contactName} wants you to be their mentor',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF6B4C2A),
                height: 1.4,
              ),
            ),
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _respondMentorship(
                        requestId: requestId,
                        accept: false,
                        messageIndex: _messages.indexOf(message),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Decline',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _respondMentorship(
                        requestId: requestId,
                        accept: true,
                        messageIndex: _messages.indexOf(message),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            'Accept',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.hourglass_top,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Waiting for response...',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _respondMentorship({
    required int requestId,
    required bool accept,
    required int messageIndex,
  }) async {
    if (requestId <= 0) return;

    final result = accept
        ? await ApiService.acceptMentorshipRequest(requestId)
        : await ApiService.declineMentorshipRequest(requestId);

    if (!mounted) return;

    if (result['success'] == true) {
      if (messageIndex >= 0 && messageIndex < _messages.length) {
        final old = _messages[messageIndex];
        setState(() {
          _messages[messageIndex] = ChatMessageModel(
            id: old.id,
            senderId: old.senderId,
            receiverId: old.receiverId,
            text: accept ? 'Mentorship accepted' : 'Mentorship declined',
            messageType: 'mentorship_request',
            relatedId: old.relatedId,
            createdAt: old.createdAt,
          );
        });
      }
      await _loadMentorshipStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'You accepted the mentorship request'
              : 'You declined the mentorship request'),
          backgroundColor: accept ? const Color(0xFF00B894) : Colors.grey,
        ),
      );
    } else {
      _showDialog(
        title: 'Failed',
        message: result['error']?.toString() ?? 'Unknown error',
      );
    }
  }

  Widget _buildCallInviteCard(ChatMessageModel message, {required bool isMe}) {
    final roomId = message.callRoomId;

    if (roomId == null || roomId.isEmpty) {
      return const SizedBox.shrink();
    }

    final isActive = _roomActiveMap[roomId] ?? true;

    if (!isActive) {
      final secs = _findCallEndSeconds(message.createdAt);
      final durationText = secs != null ? ' · ${_fmtDuration(secs)}' : '';
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off,
                  color: Colors.grey.shade500, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Call',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Ended$durationText',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _joinCallFromInvite(roomId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB347), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam,
                  color: Color(0xFFFFB347), size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Video Call',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isMe ? 'Tap to rejoin' : 'Tap to join',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickerBubble(ChatMessageModel message,
      {required bool isMe}) {
    final media = message.mediaUrl ?? '';
    Widget image;
    if (media.startsWith('asset:')) {
      final id = media.substring('asset:'.length);
      final sticker = stickerById(id);
      image = sticker != null
          ? Image.asset(sticker.assetPath, fit: BoxFit.contain)
          : const Icon(Icons.emoji_emotions, size: 60);
    } else if (media.isNotEmpty) {
      image = Image.network(
        ApiService.resolveImageUrl(media),
        fit: BoxFit.contain,
      );
    } else {
      image = const Icon(Icons.emoji_emotions, size: 60);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, height: 140, child: image),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaBubble(ChatMessageModel message, {required bool isMe}) {
    final rawUrl = message.mediaUrl ?? '';
    final isLocal = rawUrl.startsWith('/') || rawUrl.startsWith('file:');
    final resolvedUrl =
        isLocal ? rawUrl : ApiService.resolveImageUrl(rawUrl);

    if (message.messageType == 'image') {
      Widget img;
      if (isLocal) {
        img = Image.file(
          File(rawUrl.replaceFirst('file:', '')),
          fit: BoxFit.cover,
          width: 220,
          height: 220,
          cacheWidth: 500,
        );
      } else {
        img = Image.network(
          resolvedUrl,
          fit: BoxFit.cover,
          width: 220,
          height: 220,
          cacheWidth: 500,
          errorBuilder: (_, __, ___) => Container(
            width: 220,
            height: 220,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image),
          ),
        );
      }

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _openImageFullscreen(resolvedUrl, isLocal: isLocal),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  img,
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTime(message.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _VideoMessageBubble(
          url: resolvedUrl,
          isLocal: isLocal,
          timeLabel: _formatTime(message.createdAt),
          onFullscreen: () =>
              _openVideoFullscreen(resolvedUrl, isLocal: isLocal),
        ),
      ),
    );
  }

  Widget _buildTextBubble(ChatMessageModel message, {required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFFFB347) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isMe ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageFullscreen(String url, {required bool isLocal}) {
    final ImageProvider<Object> provider = isLocal
        ? FileImage(File(url.replaceFirst('file:', ''))) as ImageProvider<Object>
        : NetworkImage(url) as ImageProvider<Object>;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: PhotoView(
              imageProvider: provider,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  void _openVideoFullscreen(String url, {required bool isLocal}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(url: url, isLocal: isLocal),
      ),
    );
  }
}

// ============================================================
// Video message bubble
// ============================================================
class _VideoMessageBubble extends StatefulWidget {
  final String url;
  final bool isLocal;
  final String timeLabel;
  final VoidCallback onFullscreen;

  const _VideoMessageBubble({
    required this.url,
    required this.isLocal,
    required this.timeLabel,
    required this.onFullscreen,
  });

  @override
  State<_VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<_VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      VideoPlayerController c;
      if (widget.isLocal) {
        c = VideoPlayerController.file(
            File(widget.url.replaceFirst('file:', '')));
      } else {
        c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _initialized = true;
      });
      c.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB347)),
        ),
      );
    }

    final c = _controller!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 240,
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () async {
                      if (c.value.isPlaying) {
                        await c.pause();
                      } else {
                        if (c.value.position >= c.value.duration) {
                          await c.seekTo(Duration.zero);
                        }
                        await c.play();
                      }
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: c.value.isPlaying
                          ? const SizedBox.shrink()
                          : Container(
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(10),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: widget.onFullscreen,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFFFB347),
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: Colors.black.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(c.value.position),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.timeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white70,
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
}

// ============================================================
// Fullscreen video page
// ============================================================
class _FullscreenVideoPage extends StatefulWidget {
  final String url;
  final bool isLocal;
  const _FullscreenVideoPage({required this.url, required this.isLocal});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      VideoPlayerController c;
      if (widget.isLocal) {
        c = VideoPlayerController.file(
            File(widget.url.replaceFirst('file:', '')));
      } else {
        c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _initialized = true;
      });
      c.play();
      c.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Fullscreen video error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
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
      ),
      body: _initialized && _controller != null
          ? Column(
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () async {
                        final c = _controller!;
                        if (c.value.isPlaying) {
                          await c.pause();
                        } else {
                          await c.play();
                        }
                        if (mounted) setState(() {});
                      },
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller!),
                            if (!_controller!.value.isPlaying)
                              const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 64,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        _controller!,
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
                            _fmt(_controller!.value.position),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _fmt(_controller!.value.duration),
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
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB347)),
            ),
    );
  }
}