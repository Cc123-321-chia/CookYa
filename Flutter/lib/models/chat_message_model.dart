// lib/models/chat_message_model.dart

class ChatMessageModel {
  final int id;
  final String senderId;
  final String receiverId;
  final String text;
  final String messageType; // 'text' | 'image' | 'video' | 'sticker' | 'call_invite' | 'call_end' | 'mentorship_request'
  final String? mediaUrl;
  final int? stickerId;
  final String relatedId; // MentorshipRequest id for 'mentorship_request'
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.messageType = 'text',
    this.mediaUrl,
    this.stickerId,
    this.relatedId = '',
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> j) {
    return ChatMessageModel(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? -1,
      senderId: j['sender_id']?.toString() ?? '',
      receiverId: j['receiver_id']?.toString() ?? '',
      text: j['text']?.toString() ?? '',
      messageType: j['message_type']?.toString() ?? 'text',
      mediaUrl: j['media_url']?.toString(),
      stickerId: j['sticker_id'] is int
          ? j['sticker_id'] as int
          : int.tryParse('${j['sticker_id']}'),
      relatedId: j['related_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  /// call_invite message: extract room_id from text.
  /// Format: "Video call invite: <room_id>"
  String? get callRoomId {
    if (messageType != 'call_invite') return null;
    final idx = text.lastIndexOf(':');
    if (idx == -1) return null;
    final rid = text.substring(idx + 1).trim();
    return rid.isEmpty ? null : rid;
  }
}