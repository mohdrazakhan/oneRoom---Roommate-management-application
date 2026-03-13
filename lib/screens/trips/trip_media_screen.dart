import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../services/firestore_service.dart';

class TripMediaScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const TripMediaScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<TripMediaScreen> createState() => _TripMediaScreenState();
}

class _TripMediaScreenState extends State<TripMediaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String? _currentUserId;
  String? _roomCreatorId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadRoomMeta();
  }

  Future<void> _loadRoomMeta() async {
    final room = await _firestoreService.getRoom(widget.roomId);
    if (!mounted || room == null) return;
    setState(() {
      _roomCreatorId = (room['createdBy'] ?? '').toString();
    });
  }

  Future<void> _uploadImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (file == null) return;
    await _upload(file, 'image');
  }

  Future<void> _uploadVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _upload(file, 'video');
  }

  Future<void> _upload(XFile file, String mediaType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      await _firestoreService.uploadRoomMedia(
        roomId: widget.roomId,
        file: file,
        mediaType: mediaType,
        uploaderUid: user.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${mediaType == 'image' ? 'Image' : 'Video'} uploaded'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMedia(Map<String, dynamic> item) async {
    final mediaId = (item['id'] ?? '').toString();
    if (mediaId.isEmpty || _currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete media?'),
        content: const Text('Only creator can do this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteRoomMedia(
        roomId: widget.roomId,
        mediaId: mediaId,
        requesterUid: _currentUserId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Media deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.roomName} Folder')),
      floatingActionButton: _uploading
          ? const FloatingActionButton(
              onPressed: null,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library_outlined),
                            title: const Text('Upload Image'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _uploadImage();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.video_library_outlined),
                            title: const Text('Upload Video'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _uploadVideo();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Share Media'),
            ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.roomMediaStream(widget.roomId),
        builder: (context, snapshot) {
          final mediaItems = snapshot.data ?? const <Map<String, dynamic>>[];
          final isCreator =
              _currentUserId != null && _currentUserId == _roomCreatorId;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (mediaItems.isEmpty) {
            return const Center(
              child: Text('No shared media yet. Upload photos or videos.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: mediaItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = mediaItems[index];
              final type = (item['type'] ?? 'image').toString();
              final url = (item['url'] ?? '').toString();
              final uploaderName = (item['uploaderName'] ?? 'Member')
                  .toString();
              final timestamp = _toDate(item['createdAt']);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _TripMediaPreviewScreen(
                        mediaItems: mediaItems,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFFF2F4FF)),
                      if (type == 'image' && url.isNotEmpty)
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF5B63F1),
                          ),
                        )
                      else
                        const Icon(
                          Icons.videocam_rounded,
                          size: 34,
                          color: Color(0xFF5B63F1),
                        ),
                      if (type == 'video')
                        const Align(
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          child: Text(
                            timestamp == null
                                ? uploaderName
                                : '${DateFormat('dd MMM').format(timestamp)} • $uploaderName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (isCreator)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _deleteMedia(item),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TripMediaPreviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> mediaItems;
  final int initialIndex;

  const _TripMediaPreviewScreen({
    required this.mediaItems,
    required this.initialIndex,
  });

  @override
  State<_TripMediaPreviewScreen> createState() =>
      _TripMediaPreviewScreenState();
}

class _TripMediaPreviewScreenState extends State<_TripMediaPreviewScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1}/${widget.mediaItems.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) {
          final item = widget.mediaItems[index];
          final type = (item['type'] ?? 'image').toString();
          final url = (item['url'] ?? '').toString();

          if (type == 'video') {
            return Center(child: _FullscreenVideoPlayer(url: url));
          }

          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  final String url;

  const _FullscreenVideoPlayer({required this.url});

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await controller.initialize();
    final chewie = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.white,
        handleColor: Colors.white,
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white54,
      ),
    );

    if (!mounted) {
      await controller.dispose();
      chewie.dispose();
      return;
    }

    setState(() {
      _videoController = controller;
      _chewieController = chewie;
    });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null || _videoController == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}
