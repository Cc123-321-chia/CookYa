// lib/screens/mentor-mentee/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mentor_screen.dart';
import 'chat_detail_screen.dart';
import 'system_notification_screen.dart';
import '../../services/api_service.dart';

class ChatConversation {
  final String otherUserId;
  final String name;
  final String avatar;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isMentor;
  final bool isMyMentor;
  final bool isMyMentee;

  ChatConversation({
    required this.otherUserId,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
    this.isMentor = false,
    this.isMyMentor = false,
    this.isMyMentee = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<ChatConversation> _chats = [];
  bool _isLoading = true;

  int _systemUnread = 0;
  String _systemLastMessage = 'No notifications';
  String _systemLastTime = '';

  int get totalUnread {
    final chatUnread = _chats.fold<int>(0, (sum, c) => sum + c.unreadCount);
    return _systemUnread + chatUnread;
  }

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final sysRes = await ApiService.getSystemNotifications();
    if (mounted && sysRes['success'] == true) {
      final unread = sysRes['unread_count'];
      final sysList = (sysRes['data'] as List?) ?? [];
      setState(() {
        _systemUnread = (unread is int) ? unread : 0;
        if (sysList.isNotEmpty) {
          _systemLastMessage =
              sysList.first['title']?.toString() ?? 'No notifications';
          _systemLastTime = _formatRelative(
              sysList.first['created_at']?.toString() ?? '');
        } else {
          _systemLastMessage = 'No notifications';
          _systemLastTime = '';
        }
      });
    }

    final result = await ApiService.getConversations();
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() => _isLoading = false);
      return;
    }

    final List<dynamic> raw = result['data'];
    final List<ChatConversation> loaded = [];

    for (final item in raw) {
      final otherId = item['other_user_id']?.toString() ?? '';
      if (otherId.isEmpty) continue;

      final profile = await ApiService.getUserProfileByUserId(otherId);
      final data = profile['success'] == true ? profile['data'] : null;

      loaded.add(ChatConversation(
        otherUserId: otherId,
        name: data?['username']?.toString() ?? 'User',
        avatar: data?['avatar']?.toString() ?? '',
        lastMessage: item['last_message']?.toString() ?? '',
        lastMessageTime:
            _formatRelative(item['last_message_time']?.toString() ?? ''),
        unreadCount: item['unread_count'] is int
            ? item['unread_count'] as int
            : 0,
        isOnline: false,
        isMentor: data?['is_mentor'] == true,
        isMyMentor: item['is_my_mentor'] == true,
        isMyMentee: item['is_my_mentee'] == true,
      ));
    }

    if (!mounted) return;
    setState(() {
      _chats = loaded;
      _isLoading = false;
    });
  }

  String _formatRelative(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour ago';
    return '${diff.inDays} days ago';
  }

  void _openChat(ChatConversation chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          otherUserId: chat.otherUserId,
          contactName: chat.name,
          contactAvatar: chat.avatar,
          isMentor: chat.isMentor,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  void _openSystemNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SystemNotificationScreen(),
      ),
    ).then((_) => _loadConversations());
  }

  void _goToMentorPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MentorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6B4C2A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: GestureDetector(
              onTap: _goToMentorPage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB347), Color(0xFFFFA726)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB347).withAlpha(77),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.explore_outlined,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Find a Mentor / Friend',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_isLoading) _buildSystemChatItem(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB347)),
                  )
                : _chats.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations yet',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          return _buildChatItem(_chats[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemChatItem() {
    return GestureDetector(
      onTap: _openSystemNotifications,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFFFF3E0),
              child: Icon(
                Icons.notifications,
                color: Color(0xFFFFB347),
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'CookYa System',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B4C2A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _systemLastTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _systemLastMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _systemUnread > 0
                                ? const Color(0xFF1A1A1A)
                                : Colors.grey.shade500,
                            fontWeight: _systemUnread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_systemUnread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            _systemUnread > 99 ? '99+' : '$_systemUnread',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(ChatConversation chat) {
    return GestureDetector(
      onTap: () => _openChat(chat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: chat.avatar.isNotEmpty
                      ? NetworkImage(ApiService.resolveImageUrl(chat.avatar))
                      : null,
                  child: chat.avatar.isEmpty
                      ? const Icon(Icons.person, size: 24, color: Colors.grey)
                      : null,
                ),
                if (chat.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                if (chat.isMentor)
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB347),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                chat.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.isMyMentor) ...[
                              const SizedBox(width: 6),
                              _chatTag('Your Mentor'),
                            ] else if (chat.isMyMentee) ...[
                              const SizedBox(width: 6),
                              _chatTag('Your Mentee'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chat.lastMessageTime,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: chat.unreadCount > 0
                                ? const Color(0xFF1A1A1A)
                                : Colors.grey.shade500,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : '${chat.unreadCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00B894).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF00B894),
        ),
      ),
    );
  }
}