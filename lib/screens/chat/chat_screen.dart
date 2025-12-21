// lib/screens/chat/chat_screen.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Models/chat_message.dart';
import '../../Models/expense.dart';
import '../../Models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../expenses/expense_detail_screen.dart';
import '../tasks/category_tasks_screen.dart';

import 'package:record/record.dart'; // record package
import '../../widgets/safe_web_image.dart';
import '../../widgets/read_by_list.dart';
import '../../widgets/audio_player_widget.dart';

import 'package:path_provider/path_provider.dart';
import '../../widgets/video_player_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  const ChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatService _chat;
  late FirestoreService _firestore;
  late final AudioRecorder _audioRecorder;

  bool _sending = false;
  bool _isRecording = false;

  // Reply state
  ChatMessage? _replyingTo;
  String? _replyingToSenderName;

  // Selection state
  final Set<ChatMessage> _selectedMessages = {};

  // Optimistic Read State
  final Set<String> _locallyReadIds = {};

  bool get _isSelectionMode => _selectedMessages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _chat = ChatService();
    _firestore = FirestoreService();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _setReplyTo(ChatMessage message, String senderName) {
    setState(() {
      _replyingTo = message;
      _replyingToSenderName = senderName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToSenderName = null;
    });
  }

  void _toggleSelection(ChatMessage message) {
    setState(() {
      if (_selectedMessages.any((m) => m.id == message.id)) {
        _selectedMessages.removeWhere((m) => m.id == message.id);
      } else {
        _selectedMessages.add(message);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessages.clear());
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    final replyTo = _replyingTo;
    final replyToSenderName = _replyingToSenderName;
    _cancelReply();

    setState(() => _sending = true);
    try {
      await _chat.sendText(
        roomId: widget.roomId,
        text: text,
        replyToId: replyTo?.id,
        replyToText: replyTo?.text ?? _getMessagePreview(replyTo),
        replyToSenderId: replyTo?.senderId,
        replyToSenderName: replyToSenderName,
      );
      _scrollToTop();
    } catch (e) {
      if (!mounted) return;
      _controller.text = text;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String myUid) {
    if (!_isSelectionMode) {
      return AppBar(title: Text('Chat • ${widget.roomName}'));
    }

    final count = _selectedMessages.length;
    final singleMsg = count == 1 ? _selectedMessages.first : null;
    final isMe = singleMsg?.senderId == myUid;
    final isText = singleMsg?.type == ChatMessageType.text;

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('$count'),
      actions: [
        if (count == 1) ...[
          IconButton(
            icon: const Icon(Icons.reply_rounded),
            onPressed: () {
              final m = singleMsg!;
              _setReplyTo(m, '...');
              _clearSelection();
            },
          ),
          if (isMe && isText)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                _clearSelection();
                _editMessage(context, singleMsg!);
              },
            ),
          if (isText)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: singleMsg!.text ?? ''));
                _clearSelection();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied')));
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showMsgInfo(context, singleMsg!),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.delete_rounded),
          onPressed: () => _handleDeleteSelection(context, myUid),
        ),
      ],
    );
  }

  void _handleDeleteSelection(BuildContext context, String myUid) {
    if (_selectedMessages.length == 1) {
      final m = _selectedMessages.first;
      if (m.senderId == myUid) {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(context, forEveryone: true, message: m);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded),
                  title: const Text('Delete for Me'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(context, forEveryone: false, message: m);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      } else {
        _deleteMessage(context, forEveryone: false, message: m);
      }
    } else {
      _batchDeleteForMe(context);
    }
  }

  void _batchDeleteForMe(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected messages?'),
        content: const Text('These messages will be hidden from you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final m in _selectedMessages) {
      ChatService().deleteMessageForMe(roomId: m.roomId, messageId: m.id);
    }
    _clearSelection();
  }

  void _editMessage(BuildContext context, ChatMessage message) async {
    final controller = TextEditingController(text: message.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Enter new message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText == null || newText.trim().isEmpty || !context.mounted) return;

    try {
      await ChatService().editMessage(
        roomId: message.roomId,
        messageId: message.id,
        newText: newText.trim(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
      }
    }
  }

  void _deleteMessage(
    BuildContext context, {
    required bool forEveryone,
    required ChatMessage message,
  }) async {
    try {
      if (forEveryone) {
        await ChatService().deleteMessage(
          roomId: message.roomId,
          messageId: message.id,
        );
      } else {
        await ChatService().deleteMessageForMe(
          roomId: message.roomId,
          messageId: message.id,
        );
      }
      _clearSelection();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _showMsgInfo(BuildContext context, ChatMessage message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message Info'),
        content: StreamBuilder<ChatMessage>(
          stream: ChatService().streamSingleMessage(message.roomId, message.id),
          initialData: message,
          builder: (context, snapshot) {
            final m = snapshot.data ?? message;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sent: ${m.createdAt}'),
                const SizedBox(height: 8),
                ReadByList(userIds: m.readBy),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myUid = auth.firebaseUser?.uid ?? '';
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _clearSelection();
      },
      child: Scaffold(
        appBar: _buildAppBar(context, myUid),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: ChatService().streamMessages(widget.roomId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = (snapshot.data ?? [])
                      .where((m) => !m.hiddenBy.contains(myUid))
                      .toList();
                  if (messages.isEmpty) {
                    return _buildEmpty(context);
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // newest at top
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final isMe = m.senderId == myUid;
                      final isSelected = _selectedMessages.any(
                        (x) => x.id == m.id,
                      );
                      return _ChatMessageTile(
                        message: m,
                        isMe: isMe,
                        isSelected: isSelected,
                        selectionMode: _isSelectionMode,
                        onBind: (msg) {
                          if (!isMe &&
                              !msg.readBy.contains(myUid) &&
                              !_locallyReadIds.contains(msg.id)) {
                            _locallyReadIds.add(msg.id);
                            ChatService().markMessageAsRead(
                              widget.roomId,
                              msg.id,
                            );
                          }
                        },
                        onToggleSelection: () => _toggleSelection(m),
                        onVote: (idx) => _chat.votePoll(
                          roomId: widget.roomId,
                          messageId: m.id,
                          optionIndex: idx,
                        ),
                        onOpenLink: (type, id) => _handleOpenLink(type, id),
                        onReply: (msg, senderName) =>
                            _setReplyTo(msg, senderName),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            if (_replyingTo != null)
              _ReplyPreviewBar(
                replyingToName: _replyingToSenderName ?? 'Unknown',
                replyingToText:
                    _replyingTo!.text ?? _getMessagePreview(_replyingTo),
                onCancel: _cancelReply,
              ),
            _Composer(
              controller: _controller,
              onSend: _sendText,
              sending: _sending,
              isRecording: _isRecording,
              onCamera: _pickFromCamera,
              onMic: _toggleRecording,
              onGallery: _pickGallery,
              onMore: _showMoreActions,
              onSticker: _showStickerPicker,
            ),
          ],
        ),
      ),
    );
  }

  String _getMessagePreview(ChatMessage? message) {
    if (message == null) return '';
    switch (message.type) {
      case ChatMessageType.image:
        return '📷 Photo';
      case ChatMessageType.video:
        return '🎥 Video';
      case ChatMessageType.audio:
        return '🎵 Audio';
      case ChatMessageType.poll:
        return '📊 Poll: ${message.pollQuestion ?? ""}';
      case ChatMessageType.sticker:
        return message.stickerCode ?? '😀';
      case ChatMessageType.link:
        return '🔗 ${message.linkType ?? "Link"}';
      case ChatMessageType.reminder:
        return '💰 Payment reminder';
      default:
        return message.text ?? '';
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    // Camera implies Image for now. User said "camera so user capture image directly".
    // "add image are send in medium quality".
    final x = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1024,
    );
    if (x == null) return;
    _sendMediaFile(File(x.path), 'image');
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);
        if (path != null) {
          _sendMediaFile(File(path), 'audio');
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final path =
              '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

          // Optimize for voice: AAC Low Complexity, 32kbps, 16kHz sample rate
          // This drastically reduces file size (~1MB/min -> ~0.2MB/min) making uploads much faster.
          const config = RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 32000,
            sampleRate: 16000,
          );

          await _audioRecorder.start(config, path: path);
          setState(() => _isRecording = true);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required')),
          );
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error recording: $e')));
      }
    }
  }

  Future<void> _pickGallery() async {
    // Show choice: Photos/Video OR Audio File
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Photos & Videos'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                try {
                  final x = await picker.pickMedia(
                    imageQuality: 50,
                    maxWidth: 1024,
                  );
                  if (x == null) return;
                  final ext = _extFromPath(x.path).toLowerCase();
                  final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
                  _sendMediaFile(File(x.path), isVideo ? 'video' : 'image');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack_rounded),
              title: const Text('Audio File via File Manager'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAudioFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res == null || res.files.single.path == null) return;
    _sendMediaFile(File(res.files.single.path!), 'audio');
  }

  Future<void> _sendMediaFile(File file, String kind) async {
    setState(() => _sending = true);
    try {
      final ext = _extFromPath(file.path);
      String mime;
      if (kind == 'video') {
        mime = ext == 'mov' ? 'video/quicktime' : 'video/$ext';
      } else {
        mime = 'image/$ext';
      }

      await _chat.sendMedia(
        roomId: widget.roomId,
        file: file,
        ext: ext,
        contentType: mime,
        kind: kind,
        replyToId: _replyingTo?.id,
        replyToText: _replyingTo?.text ?? _getMessagePreview(_replyingTo),
        replyToSenderId: _replyingTo?.senderId,
        replyToSenderName: _replyingToSenderName,
      );
      _cancelReply();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send $kind: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendSticker(String stickerCode) async {
    setState(() => _sending = true);
    try {
      await _chat.sendSticker(
        roomId: widget.roomId,
        stickerCode: stickerCode,
        replyToId: _replyingTo?.id,
        replyToText: _replyingTo?.text ?? _getMessagePreview(_replyingTo),
        replyToSenderId: _replyingTo?.senderId,
        replyToSenderName: _replyingToSenderName,
      );
      _cancelReply();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send sticker: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StickerPicker(
        onStickerSelected: (sticker) {
          Navigator.pop(context);
          _sendSticker(sticker);
        },
      ),
    );
  }

  String _extFromPath(String path) {
    final idx = path.lastIndexOf('.');
    return idx == -1 ? 'bin' : path.substring(idx + 1).toLowerCase();
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'No messages yet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenLink(String type, String id) async {
    if (!mounted) return;
    if (type == 'expense') {
      // Fetch expense data and navigate to detail screen
      final firestore = FirestoreService();
      final expMap = await firestore.getExpense(widget.roomId, id);
      if (!mounted) return;
      if (expMap != null) {
        final expense = Expense.fromMap(expMap, id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ExpenseDetailScreen(roomId: widget.roomId, expense: expense),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense not found.')));
      }
    } else if (type == 'task') {
      // Navigate to the tasks screen (CategoryTasksScreen shows all tasks)
      final task = await _firestore.getTask(widget.roomId, id);
      if (task != null && mounted) {
        // Get the category for this task
        final category = await _firestore.getCategory(
          widget.roomId,
          task.categoryId,
        );
        if (category != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CategoryTasksScreen(
                category: category,
                roomId: widget.roomId,
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task category not found.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Task not found.')));
      }
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unknown link type: $type')));
    }
  }

  Future<void> _showMoreActions() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.poll_rounded),
                title: const Text('Create poll'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePollDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: const Text('Send payment reminder'),
                onTap: () {
                  Navigator.pop(context);
                  _showReminderDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Link expense/task'),
                onTap: () {
                  Navigator.pop(context);
                  _showLinkDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns (id, previewText)
  Future<(String, String?)?> _pickItemForLink(String type) async {
    return showModalBottomSheet<(String, String?)>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: _LinkPicker(roomId: widget.roomId, type: type),
        );
      },
    );
  }

  Future<void> _showCreatePollDialog() async {
    final qCtrl = TextEditingController();
    final opts = [TextEditingController(), TextEditingController()];
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Poll'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: qCtrl,
                      decoration: const InputDecoration(labelText: 'Question'),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(opts.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: opts[i],
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: opts.length >= 5
                            ? null
                            : () => setState(
                                () => opts.add(TextEditingController()),
                              ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add option'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final options = opts
                    .map((e) => e.text)
                    .where((t) => t.trim().isNotEmpty)
                    .toList();
                if (options.length < 2) return; // require at least 2
                Navigator.pop(context);
                await _chat.sendPoll(
                  roomId: widget.roomId,
                  question: qCtrl.text,
                  options: options,
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReminderDialog() async {
    // First, get all room members
    final roomDoc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();

    if (!roomDoc.exists) return;

    // Get expenses and payments to calculate settlements
    final firestoreService = FirestoreService();
    final expenses = await firestoreService
        .getExpensesStream(widget.roomId)
        .first;
    final paymentMaps = await firestoreService
        .paymentsForRoom(widget.roomId)
        .first;

    final payments = paymentMaps.map((map) {
      return Payment(
        id: map['id'] ?? '',
        roomId: map['roomId'] ?? '',
        payerId: map['payerId'] ?? '',
        receiverId: map['receiverId'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        note: map['note'],
        createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
        createdBy: map['createdBy'] ?? '',
      );
    }).toList();

    // Calculate balances and settlements
    final balances = BalanceCalculator.calculateBalancesWithPayments(
      expenses,
      payments,
    );
    final settlements = BalanceCalculator.simplifySettlements(balances);

    if (settlements.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending settlements'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Show dialog with suggested settlements
    if (!mounted) return;
    final selected = await showDialog<Settlement>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Payment Reminder'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: settlements.length,
              itemBuilder: (context, index) {
                final settlement = settlements[index];
                return FutureBuilder<List<String>>(
                  future: Future.wait([
                    _getUserNameById(settlement.from),
                    _getUserNameById(settlement.to),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(title: Text('Loading...'));
                    }

                    final fromName = snapshot.data![0];
                    final toName = snapshot.data![1];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('$fromName → $toName'),
                        subtitle: Text(
                          '₹${settlement.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => Navigator.pop(context, settlement),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null || !mounted) return;

    // Send the reminder
    await _chat.sendReminder(
      roomId: widget.roomId,
      toUid: selected.from,
      amount: selected.amount,
      note: 'Please pay ${await _getUserNameById(selected.to)}',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment reminder sent!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<String> _getUserNameById(String uid) async {
    final profile = await FirestoreService().getUserProfile(uid);
    return profile?['displayName'] as String? ?? 'Unknown';
  }

  Future<void> _showLinkDialog() async {
    String type = 'expense';
    final idCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Link to item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'task', child: Text('Task')),
                ],
                onChanged: (v) => type = v ?? 'expense',
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(labelText: 'ID'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await _pickItemForLink(type);
                    if (picked != null) {
                      idCtrl.text = picked.$1;
                      if ((textCtrl.text.trim()).isEmpty && picked.$2 != null) {
                        textCtrl.text = picked.$2!;
                      }
                    }
                  },
                  icon: const Icon(Icons.list_alt_rounded),
                  label: const Text('Pick from list'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Preview text (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (idCtrl.text.trim().isEmpty) return;
                Navigator.pop(context);
                await _chat.sendLinkToItem(
                  roomId: widget.roomId,
                  linkType: type,
                  linkId: idCtrl.text.trim(),
                  previewText: textCtrl.text.trim().isEmpty
                      ? null
                      : textCtrl.text.trim(),
                );
              },
              child: const Text('Post'),
            ),
          ],
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onMic;
  final VoidCallback onGallery;
  final VoidCallback onMore;
  final VoidCallback onSticker;
  final bool sending;
  final bool isRecording;

  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onCamera,
    required this.onMic,
    required this.onGallery,
    required this.onMore,
    required this.onSticker,
    required this.sending,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Main Attachment Menu
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: sending || isRecording
                  ? null
                  : () => _showAttachmentMenu(context),
              tooltip: 'Attach',
            ),
            // Direct Camera and Mic removed (moved to menu).
            // Only show Stop button if recording.
            if (isRecording)
              IconButton(
                icon: const Icon(Icons.stop_circle_rounded, color: Colors.red),
                onPressed: onMic,
                tooltip: 'Stop Recording',
              ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                enabled: !isRecording,
                decoration: InputDecoration(
                  hintText: isRecording ? 'Recording audio...' : 'Message',
                  suffixIcon: isRecording
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.emoji_emotions_outlined),
                          onPressed: sending ? null : onSticker,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: sending || isRecording ? null : onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  onCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_rounded),
                title: const Text('Record Audio'),
                onTap: () {
                  Navigator.pop(context);
                  onMic();
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.perm_media_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Media (Photo, Video, Audio)'),
                onTap: () {
                  Navigator.pop(context);
                  onGallery();
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.poll_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: const Text('Poll / More'),
                onTap: () {
                  Navigator.pop(context);
                  onMore();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessageTile extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isSelected;
  final bool selectionMode;
  final void Function(int optionIndex)? onVote;
  final void Function(String type, String id)? onOpenLink;
  final void Function(ChatMessage message, String senderName)? onReply;
  final VoidCallback? onToggleSelection;
  final Function(ChatMessage message)? onBind;

  const _ChatMessageTile({
    required this.message,
    required this.isMe,
    required this.isSelected,
    required this.selectionMode,
    this.onVote,
    this.onOpenLink,
    this.onReply,
    this.onToggleSelection,
    this.onBind,
  });

  @override
  State<_ChatMessageTile> createState() => _ChatMessageTileState();
}

class _ChatMessageTileState extends State<_ChatMessageTile> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = FirestoreService().getUserProfile(widget.message.senderId);
  }

  @override
  void didUpdateWidget(_ChatMessageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.senderId != oldWidget.message.senderId) {
      _profileFuture = FirestoreService().getUserProfile(
        widget.message.senderId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Local references for cleaner code
    final message = widget.message;
    final isMe = widget.isMe;
    final isSelected = widget.isSelected;
    final selectionMode = widget.selectionMode;
    final onToggleSelection = widget.onToggleSelection;
    final onReply = widget.onReply;
    final onVote = widget.onVote;
    final onOpenLink = widget.onOpenLink;

    if (widget.onBind != null) {
      // Defer state update to avoid build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onBind!(message);
      });
    }

    // Mark as read if not sent by me and not already read by me
    if (!isMe) {
      final myUid = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).firebaseUser?.uid;
      if (myUid != null && !message.readBy.contains(myUid)) {
        // Avoid frequent writes: only if not in list.
        // Also consider debouncing or simple fire-and-forget.
        ChatService().markMessageAsRead(message.roomId, message.id);
      }
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        final senderName =
            snapshot.data?['displayName'] as String? ?? 'Unknown';
        final senderPhoto = snapshot.data?['photoURL'] as String?;

        return InkWell(
          onTap: selectionMode ? onToggleSelection : null,
          onLongPress: onToggleSelection,
          child: Container(
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Show sender info for messages from others
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.grey[300],
                            child:
                                (senderPhoto != null && senderPhoto.isNotEmpty)
                                ? ClipOval(
                                    child: SafeWebImage(
                                      senderPhoto,
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Text(
                                              senderName.isNotEmpty
                                                  ? senderName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                    ),
                                  )
                                : Text(
                                    senderName.isNotEmpty
                                        ? senderName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Dismissible(
                    key: Key('reply_${message.id}'),
                    direction: selectionMode
                        ? DismissDirection.none
                        : DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (onReply != null) {
                        onReply(message, senderName);
                        HapticFeedback.lightImpact();
                      }
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: Icon(
                        Icons.reply_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(
                        Icons.reply_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    child: AbsorbPointer(
                      absorbing: selectionMode,
                      child: _MessageBubble(
                        message: message,
                        isMe: isMe,
                        senderName: senderName,
                        onVote: onVote,
                        onOpenLink: onOpenLink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String senderName;
  final void Function(int optionIndex)? onVote;
  final void Function(String type, String id)? onOpenLink;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.senderName,
    this.onVote,
    this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;

    if (message.deleted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'This message was deleted',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    Widget child;
    switch (message.type) {
      case ChatMessageType.text:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text ?? '',
              style: TextStyle(color: fg),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
            if (message.edited)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '(edited)',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
        break;
      case ChatMessageType.sticker:
        child = Text(
          message.stickerCode ?? '😀',
          style: const TextStyle(fontSize: 64),
        );
        break;
      case ChatMessageType.image:
        final url = message.mediaUrl ?? '';
        if (url.isEmpty) {
          child = Container(
            width: 240,
            height: 180,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          );
        } else {
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((message.text ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(message.text!, style: TextStyle(color: fg)),
                ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: InteractiveViewer(
                            child: SafeWebImage(
                              url,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'chat_image_${message.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SafeWebImage(
                      url,
                      fit: BoxFit.cover,
                      width: 240,
                      height: 180,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 240,
                          height: 180,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 240,
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        break;
      case ChatMessageType.video:
        final url = message.mediaUrl ?? '';
        child = url.isEmpty
            ? const Text('[Invalid Video]', style: TextStyle(color: Colors.red))
            : _MediaTile(
                icon: Icons.videocam_rounded,
                label: 'Video',
                url: url,
                color: fg,
              );
        break;
      case ChatMessageType.audio:
        final url = message.mediaUrl ?? '';
        child = url.isEmpty
            ? const Text('[Invalid Audio]', style: TextStyle(color: Colors.red))
            : AudioPlayerWidget(url: url, isMe: isMe, color: fg);
        break;
      case ChatMessageType.poll:
        child = _PollTile(message: message, color: fg, onVote: onVote);
        break;
      case ChatMessageType.reminder:
        final t = message.text ?? 'Payment reminder';
        final amt = message.remindAmount != null
            ? ' • ${message.remindAmount!.toStringAsFixed(2)}'
            : '';
        child = Text('$t$amt', style: TextStyle(color: fg));
        break;
      case ChatMessageType.link:
        child = _LinkTile(
          type: message.linkType ?? 'link',
          id: message.linkId ?? '',
          text: message.text,
          color: fg,
          onOpen: onOpenLink,
        );
        break;
    }

    // Build reply preview
    Widget? replyPreview;
    if (message.replyToId != null && message.replyToId!.isNotEmpty) {
      replyPreview = Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: fg.withValues(alpha: 0.5), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.replyToSenderName ?? 'Unknown',
              style: TextStyle(
                color: fg.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.replyToText ?? '',
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      decoration: BoxDecoration(
        color: message.type == ChatMessageType.sticker
            ? Colors.transparent
            : bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [if (replyPreview != null) replyPreview, child],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  const _MediaTile({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (label == 'Video') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => VideoPlayerScreen(videoUrl: url),
            ),
          );
        } else {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PollTile extends StatelessWidget {
  final ChatMessage message;
  final Color color;
  final void Function(int index)? onVote;
  const _PollTile({required this.message, required this.color, this.onVote});

  int _totalVotes(List<Map<String, dynamic>> options) =>
      options.fold<int>(0, (s, e) => s + (List.from(e['votes'] ?? []).length));

  @override
  Widget build(BuildContext context) {
    final options =
        message.pollOptions
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    final total = _totalVotes(options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((message.pollQuestion ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              message.pollQuestion!,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ...List.generate(options.length, (i) {
          final opt = options[i];
          final text = opt['text']?.toString() ?? '';
          final votes = List<String>.from(opt['votes'] ?? []);
          final percent = total == 0 ? 0.0 : votes.length / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: onVote == null ? null : () => onVote!(i),
              child: Stack(
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(text, style: TextStyle(color: color)),
                        ),
                        Text(
                          '${(percent * 100).round()}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Text(
          '$total vote${total == 1 ? '' : 's'}',
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String type;
  final String id;
  final String? text;
  final Color color;
  final void Function(String type, String id)? onOpen;
  const _LinkTile({
    required this.type,
    required this.id,
    required this.text,
    required this.color,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen == null ? null : () => onOpen!(type, id),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link_rounded, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text ?? 'Open $type',
              softWrap: true,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: color,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkPicker extends StatelessWidget {
  final String roomId;
  final String type; // 'expense' | 'task'
  const _LinkPicker({required this.roomId, required this.type});

  @override
  Widget build(BuildContext context) {
    final col = (type == 'expense') ? 'expenses' : 'tasks';
    final title = type == 'expense' ? 'Pick expense' : 'Pick task';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .doc(roomId)
            .collection(col)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No items found'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final id = d.id;
              final label = type == 'expense'
                  ? (data['description'] as String? ?? 'Expense')
                  : (data['title'] as String? ?? 'Task');
              final subtitle = type == 'expense'
                  ? _formatAmount(data['amount'])
                  : (data['description'] as String? ?? '');
              return ListTile(
                title: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: id));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('ID copied')));
                  },
                ),
                onTap: () {
                  Navigator.pop<(String, String?)>(context, (id, label));
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatAmount(dynamic v) {
    double? a;
    if (v is int) a = v.toDouble();
    if (v is double) a = v;
    if (a == null) return '';
    return 'Amount: ${a.toStringAsFixed(2)}';
  }
}

/// Widget showing the reply preview bar above the composer
class _ReplyPreviewBar extends StatelessWidget {
  final String replyingToName;
  final String replyingToText;
  final VoidCallback onCancel;

  const _ReplyPreviewBar({
    required this.replyingToName,
    required this.replyingToText,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $replyingToName',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  replyingToText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

/// Sticker picker widget
class _StickerPicker extends StatelessWidget {
  final void Function(String sticker) onStickerSelected;

  const _StickerPicker({required this.onStickerSelected});

  // Sticker categories with emojis
  static const Map<String, List<String>> stickerCategories = {
    'Smileys': [
      '😀',
      '😃',
      '😄',
      '😁',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '😮‍💨',
      '🤥',
      '😌',
      '😔',
    ],
    'Gestures': [
      '👍',
      '👎',
      '👊',
      '✊',
      '🤛',
      '🤜',
      '🤞',
      '✌️',
      '🤟',
      '🤘',
      '👌',
      '🤌',
      '🤏',
      '👈',
      '👉',
      '👆',
      '👇',
      '☝️',
      '✋',
      '🤚',
      '🖐️',
      '🖖',
      '👋',
      '🤙',
      '💪',
      '🙏',
      '🤝',
      '👏',
      '🙌',
      '👐',
    ],
    'Hearts': [
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '🤎',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '💝',
      '💟',
      '♥️',
    ],
    'Objects': [
      '🎉',
      '🎊',
      '🎁',
      '🎈',
      '🏆',
      '🥇',
      '🥈',
      '🥉',
      '⭐',
      '🌟',
      '✨',
      '💫',
      '🔥',
      '💯',
      '💰',
      '💵',
      '💸',
      '🏠',
      '🚗',
      '✈️',
      '📱',
      '💻',
      '🎮',
      '📚',
      '✏️',
      '📝',
      '🔔',
      '📣',
      '🎵',
      '🎶',
    ],
    'Food': [
      '🍕',
      '🍔',
      '🍟',
      '🌭',
      '🍿',
      '🧂',
      '🥓',
      '🥚',
      '🍳',
      '🥐',
      '🍞',
      '🥖',
      '🥨',
      '🧀',
      '🥗',
      '🥙',
      '🥪',
      '🌮',
      '🌯',
      '🫔',
      '🍝',
      '🍜',
      '🍲',
      '🍛',
      '🍣',
      '🍱',
      '🥟',
      '🍤',
      '🍙',
      '🍚',
    ],
    'Animals': [
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
      '🙈',
      '🙉',
      '🙊',
      '🐔',
      '🐧',
      '🐦',
      '🐤',
      '🦆',
      '🦅',
      '🦉',
      '🦇',
      '🐺',
      '🐗',
      '🐴',
      '🦄',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: stickerCategories.length,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stickers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          TabBar(
            isScrollable: true,
            tabs: stickerCategories.keys.map((cat) => Tab(text: cat)).toList(),
          ),
          SizedBox(
            height: 250,
            child: TabBarView(
              children: stickerCategories.entries.map((entry) {
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (context, index) {
                    final sticker = entry.value[index];
                    return InkWell(
                      onTap: () => onStickerSelected(sticker),
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Text(
                          sticker,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
