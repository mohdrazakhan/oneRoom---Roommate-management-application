// lib/Models/chat_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType { text, image, video, audio, poll, reminder, link }

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final ChatMessageType type;
  final String? text;
  final String? mediaUrl; // image/video/audio URL
  final String? mediaMime;
  final DateTime createdAt;

  // Edit tracking
  final bool edited;
  final DateTime? editedAt;

  // Soft delete tracking
  final bool deleted;
  final DateTime? deletedAt;
  final String? deletedBy;

  // Poll payload
  final String? pollQuestion;
  final List<Map<String, dynamic>>?
  pollOptions; // [{text: 'Yes', votes:['uid1']}]

  // Reminder payload
  final String? remindToUid;
  final double? remindAmount;
  final String? remindExpenseId;

  // Link payload (expense/task)
  final String? linkType; // 'expense' | 'task'
  final String? linkId;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.mediaMime,
    required this.createdAt,
    this.edited = false,
    this.editedAt,
    this.deleted = false,
    this.deletedAt,
    this.deletedBy,
    this.pollQuestion,
    this.pollOptions,
    this.remindToUid,
    this.remindAmount,
    this.remindExpenseId,
    this.linkType,
    this.linkId,
  });

  factory ChatMessage.fromDoc(String id, Map<String, dynamic> data) {
    ChatMessageType parseType(String? s) {
      switch (s) {
        case 'image':
          return ChatMessageType.image;
        case 'video':
          return ChatMessageType.video;
        case 'audio':
          return ChatMessageType.audio;
        case 'poll':
          return ChatMessageType.poll;
        case 'reminder':
          return ChatMessageType.reminder;
        case 'link':
          return ChatMessageType.link;
        case 'text':
        default:
          return ChatMessageType.text;
      }
    }

    return ChatMessage(
      id: id,
      roomId: data['roomId'] ?? '',
      senderId: data['senderId'] ?? '',
      type: parseType(data['type'] as String?),
      text: data['text'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      mediaMime: data['mediaMime'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      edited: data['edited'] as bool? ?? false,
      editedAt: data['editedAt'] is Timestamp
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      deleted: data['deleted'] as bool? ?? false,
      deletedAt: data['deletedAt'] is Timestamp
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
      deletedBy: data['deletedBy'] as String?,
      pollQuestion: data['pollQuestion'] as String?,
      pollOptions: (data['pollOptions'] as List?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      remindToUid: data['remindToUid'] as String?,
      remindAmount: (data['remindAmount'] is int)
          ? (data['remindAmount'] as int).toDouble()
          : data['remindAmount'] as double?,
      remindExpenseId: data['remindExpenseId'] as String?,
      linkType: data['linkType'] as String?,
      linkId: data['linkId'] as String?,
    );
  }
}
