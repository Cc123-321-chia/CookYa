// widgets/ingredient_comment_item.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../models/ingredient_post.dart';  // 添加这一行导入模型

class IngredientCommentItem extends StatefulWidget {
  final CommentData comment;
  final bool isOwnComment;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const IngredientCommentItem({
    super.key,
    required this.comment,
    this.isOwnComment = false,
    this.onLike,
    this.onReply,
    this.onDelete,
  });

  @override
  State<IngredientCommentItem> createState() => _IngredientCommentItemState();
}

class _IngredientCommentItemState extends State<IngredientCommentItem> {
  bool isLiked = false;
  late int likeCount;
  bool showReplies = false;

  @override
  void initState() {
    super.initState();
    likeCount = widget.comment.likes;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主评论
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户头像
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFFB347),
              backgroundImage: widget.comment.userAvatar.isNotEmpty
                  ? NetworkImage(widget.comment.userAvatar)
                  : null,
              child: widget.comment.userAvatar.isEmpty
                  ? Text(
                      widget.comment.userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // 评论内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户名和操作按钮行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.comment.userName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B4C2A),
                          ),
                        ),
                      ),
                      if (widget.isOwnComment)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, size: 16, color: Color(0xFFC9A96E)),
                          onSelected: (value) {
                            if (value == 'delete' && widget.onDelete != null) {
                              widget.onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 评论文本
                  Text(
                    widget.comment.text,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF6B4C2A).withValues(alpha: 0.8),
                    ),
                  ),

                  // 评论图片（如果有）
                  if (widget.comment.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(widget.comment.imageUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.comment.imageUrl!.startsWith('http')
                              ? Image.network(
                                  widget.comment.imageUrl!,
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(widget.comment.imageUrl!),
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),

                  // 操作按钮行（时间、点赞、回复）
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(widget.comment.timestamp),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isLiked = !isLiked;
                            if (isLiked) {
                              likeCount++;
                            } else {
                              likeCount--;
                            }
                          });
                          if (widget.onLike != null) widget.onLike!();
                        },
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: isLiked ? const Color(0xFFFF6B6B) : const Color(0xFFC9A96E),
                            ),
                            const SizedBox(width: 4),
                            if (likeCount > 0)
                              Text(
                                '$likeCount',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: isLiked ? const Color(0xFFFF6B6B) : Colors.grey.shade500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: widget.onReply,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.reply_outlined,
                              size: 14,
                              color: Color(0xFFC9A96E),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFFC9A96E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // 回复列表
        if (widget.comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 56, top: 8),
            child: Column(
              children: [
                // 展开/收起按钮
                GestureDetector(
                  onTap: () => setState(() => showReplies = !showReplies),
                  child: Row(
                    children: [
                      Icon(
                        showReplies ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: const Color(0xFFC9A96E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showReplies ? 'Hide replies' : 'View ${widget.comment.replies.length} replies',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFC9A96E),
                        ),
                      ),
                    ],
                  ),
                ),

                if (showReplies)
                  ...widget.comment.replies.map((reply) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildReplyItem(reply),
                  )),
              ],
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildReplyItem(ReplyData reply) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xFFFFB347).withValues(alpha: 0.5),
          backgroundImage: reply.userAvatar.isNotEmpty
              ? NetworkImage(reply.userAvatar)
              : null,
          child: reply.userAvatar.isEmpty
              ? Text(
                  reply.userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reply.userName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B4C2A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimestamp(reply.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                reply.text,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B4C2A).withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3.0,
                  child: imagePath.startsWith('http')
                      ? Image.network(imagePath, fit: BoxFit.contain)
                      : Image.file(File(imagePath), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}