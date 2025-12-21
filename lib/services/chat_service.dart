// ignore_for_file: avoid_print
// lib/services/chat_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Models/chat_message.dart';
import '../Models/room_notification.dart';
import 'notification_helper.dart';
import 'firestore_service.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference _roomChatRef(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('chats');

  Stream<List<ChatMessage>> streamMessages(String roomId) {
    return _roomChatRef(roomId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    ChatMessage.fromDoc(d.id, d.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  Stream<ChatMessage> streamSingleMessage(String roomId, String messageId) {
    return _roomChatRef(roomId)
        .doc(messageId)
        .snapshots()
        .map(
          (d) => ChatMessage.fromDoc(d.id, d.data() as Map<String, dynamic>),
        );
  }

  Future<void> sendText({
    required String roomId,
    required String text,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': 'text',
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
    });

    // Send notification to room members
    try {
      final roomDoc = await _db.collection('rooms').doc(roomId).get();
      final roomName = roomDoc.data()?['name'] as String? ?? 'Room';
      final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;

      await NotificationHelper.notifyChatMessage(
        roomId: roomId,
        roomName: roomName,
        messagePreview: preview,
      );

      // Create in-app notifications for all room members except sender
      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        final members = List<String>.from(roomData['members'] ?? []);
        final senderProfile = await FirestoreService().getUserProfile(uid);
        final senderName = senderProfile?['displayName'] ?? 'Someone';

        for (final memberId in members) {
          if (memberId != uid) {
            await FirestoreService().createNotification(
              roomId: roomId,
              userId: memberId,
              type: NotificationType.chatMessage,
              title: 'New Message',
              message: '$senderName: $preview',
              actorId: uid,
              actorName: senderName,
            );
          }
        }
      }
    } catch (e) {
      // Don't block message send if notification fails
      print('sendText: notification failed -> $e');
    }
  }

  Future<String> _uploadFile(
    String roomId,
    File file,
    String ext,
    String contentType,
  ) async {
    final id = _db.collection('_ids').doc().id;
    final ref = _storage.ref().child('rooms/$roomId/chat/$id.$ext');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> sendMedia({
    required String roomId,
    required File file,
    required String ext,
    required String contentType,
    required String kind, // 'image' | 'video' | 'audio'
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final url = await _uploadFile(roomId, file, ext, contentType);
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': kind,
      'mediaUrl': url,
      'mediaMime': contentType,
      'createdAt': FieldValue.serverTimestamp(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
    });
  }

  /// Send a sticker message
  Future<void> sendSticker({
    required String roomId,
    required String stickerCode,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': 'sticker',
      'stickerCode': stickerCode,
      'createdAt': FieldValue.serverTimestamp(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
    });
  }

  /// Send a GIF URL (from Giphy)
  Future<void> sendGif({
    required String roomId,
    required String gifUrl,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': 'image', // Treat GIF as image
      'mediaUrl': gifUrl,
      'mediaMime': 'image/gif',
      'createdAt': FieldValue.serverTimestamp(),
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
    });
  }

  Future<void> sendPoll({
    required String roomId,
    required String question,
    required List<String> options,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final pollOptions = options
        .where((o) => o.trim().isNotEmpty)
        .map((o) => {'text': o.trim(), 'votes': <String>[]})
        .toList();
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': 'poll',
      'pollQuestion': question.trim(),
      'pollOptions': pollOptions,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> votePoll({
    required String roomId,
    required String messageId,
    required int optionIndex,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final msgRef = _roomChatRef(roomId).doc(messageId);
    final snap = await msgRef.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final List options = List.from(data['pollOptions'] ?? []);
    if (optionIndex < 0 || optionIndex >= options.length) return;

    // Remove vote from all options first (single-choice)
    for (int i = 0; i < options.length; i++) {
      final opt = Map<String, dynamic>.from(options[i] as Map);
      final votes = List<String>.from(opt['votes'] ?? []);
      votes.removeWhere((e) => e == uid);
      options[i] = {...opt, 'votes': votes};
    }
    // Add vote to chosen option
    final chosen = Map<String, dynamic>.from(options[optionIndex] as Map);
    final chosenVotes = List<String>.from(chosen['votes'] ?? []);
    if (!chosenVotes.contains(uid)) chosenVotes.add(uid);
    options[optionIndex] = {...chosen, 'votes': chosenVotes};

    await msgRef.update({'pollOptions': options});
  }

  Future<void> sendReminder({
    required String roomId,
    required String toUid,
    required double amount,
    String? expenseId,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final text = note?.trim();
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': 'reminder',
      if (text != null && text.isNotEmpty) 'text': text,
      'remindToUid': toUid,
      'remindAmount': amount,
      if (expenseId != null) 'remindExpenseId': expenseId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendLinkToItem({
    required String roomId,
    required String linkType, // 'expense' | 'task'
    required String linkId,
    String? previewText,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _roomChatRef(roomId).add({
      'roomId': roomId,
      'senderId': uid,
      'type': 'link',
      'linkType': linkType,
      'linkId': linkId,
      if (previewText != null && previewText.isNotEmpty) 'text': previewText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edit a text message (only by the sender)
  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String newText,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final msgRef = _roomChatRef(roomId).doc(messageId);
    final snap = await msgRef.get();

    if (!snap.exists) throw Exception('Message not found');

    final data = snap.data() as Map<String, dynamic>;
    if (data['senderId'] != uid) {
      throw Exception('You can only edit your own messages');
    }

    if (data['type'] != 'text') {
      throw Exception('Only text messages can be edited');
    }

    await msgRef.update({
      'text': newText.trim(),
      'edited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a message (only by the sender)
  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    final msgRef = _roomChatRef(roomId).doc(messageId);
    final snap = await msgRef.get();

    if (!snap.exists) throw Exception('Message not found');

    final data = snap.data() as Map<String, dynamic>;
    if (data['senderId'] != uid) {
      throw Exception('You can only delete your own messages');
    }
    // Hard delete as requested
    // 1. Delete associated media if legacy
    final mediaUrl = data['mediaUrl'] as String?;
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
      } catch (e) {
        // Ignore storage delete errors (file might be missing)
        print('Storage delete error: $e');
      }
    }

    // 2. Delete the document
    await msgRef.delete();
  }

  /// Hide a message for the current user only
  Future<void> deleteMessageForMe({
    required String roomId,
    required String messageId,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    await _roomChatRef(roomId).doc(messageId).update({
      'hiddenBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> markMessageAsRead(String roomId, String messageId) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    try {
      // Use arrayUnion to add uid to readBy list
      await _roomChatRef(roomId).doc(messageId).update({
        'readBy': FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      // Silently fail if permission denied or other errors
      // This is not critical - just a read receipt feature
      print('markMessageAsRead failed: $e');
    }
  }
}
