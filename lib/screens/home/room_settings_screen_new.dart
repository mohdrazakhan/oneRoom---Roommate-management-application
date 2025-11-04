import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../Models/room.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';

class RoomSettingsScreen extends StatefulWidget {
  final Room room;

  const RoomSettingsScreen({super.key, required this.room});

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
    _loadMemberProfiles();
  }

  Future<void> _loadMemberProfiles() async {
    try {
      final profiles = await _firestoreService.getUsersProfiles(
        widget.room.members,
      );
      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  void _copyRoomCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.room.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room code copied to clipboard!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareRoomCode(BuildContext context) {
    final message =
        'Join my room "${widget.room.name}" on One Room app!\n\n'
        'Room Code: ${widget.room.id}\n\n'
        'Use this code to join and sync all our tasks and expenses.';
    Share.share(message, subject: 'Join my One Room group!');
  }

  Future<void> _deleteRoom() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.firebaseUser?.uid;

    // Only creator can delete
    if (currentUserId != widget.room.createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the room creator can delete the room'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text(
          'Are you sure you want to delete "${widget.room.name}"? This will permanently delete all tasks, expenses, and data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteRoom(widget.room.id);
        if (mounted) {
          Navigator.pop(context); // Go back to dashboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting room: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.firebaseUser?.uid;
    final isCreator = currentUserId == widget.room.createdBy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              onPressed: _deleteRoom,
              tooltip: 'Delete Room',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Room Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.home_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    widget.room.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.room.members.length} members',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Invite Section with QR code and enhanced sharing
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Invite Roommates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: QrImageView(
                      data: widget.room.id,
                      version: QrVersions.auto,
                      size: 120,
                      backgroundColor: Colors.white,
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: Size(40, 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      widget.room.id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.content_copy_rounded),
                        onPressed: () => _copyRoomCode(context),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Copy code',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded),
                        onPressed: () => _shareRoomCode(context),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Share code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan the QR code or use the room code to join and sync all data.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instructions Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    '1',
                    'Copy or share the room code above',
                    Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '2',
                    'Your roommate opens the app and taps "Join Room"',
                    Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '3',
                    'They paste the code and join the room',
                    Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '4',
                    'All data syncs automatically in real-time!',
                    Colors.blue.shade700,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Members Section
            Text(
              'Room Members',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_isLoadingMembers)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    ...widget.room.members.asMap().entries.map((entry) {
                      final index = entry.key;
                      final memberId = entry.value;
                      final memberIsCreator = memberId == widget.room.createdBy;
                      final profile = _memberProfiles[memberId];
                      final memberName =
                          profile?['displayName'] ?? 'Member ${index + 1}';
                      final memberEmail =
                          profile?['email'] ?? memberId.substring(0, 8) + '...';

                      return Column(
                        children: [
                          if (index > 0) const Divider(height: 24),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  memberName.isNotEmpty
                                      ? memberName[0].toUpperCase()
                                      : '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      memberName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      memberEmail,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (memberIsCreator)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Colors.amber.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Creator',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
