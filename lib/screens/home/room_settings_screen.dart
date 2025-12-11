// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../Models/room.dart';
import '../../services/firestore_service.dart';

class RoomSettingsScreen extends StatefulWidget {
  final Room room;

  const RoomSettingsScreen({super.key, required this.room});

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _loadMemberProfiles();
  }

  Future<void> _loadMemberProfiles() async {
    try {
      final profiles = await FirestoreService().getUsersProfiles(
        widget.room.members,
      );
      print('🔍 Room Settings: Loaded ${profiles.length} member profiles');
      profiles.forEach((uid, profile) {
        print('👤 Member Profile $uid: $profile');
      });

      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      print('❌ Error loading member profiles: $e');
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  String _getMemberDisplayName(String uid) {
    final profile = _memberProfiles[uid];
    if (profile == null) {
      print('⚠️ No profile found for UID: $uid');
      return 'Member ${uid.substring(0, 4)}';
    }

    // Try multiple fields in order of preference
    if (profile['displayName'] != null &&
        profile['displayName'].toString().isNotEmpty) {
      print('✅ Using displayName: ${profile['displayName']}');
      return profile['displayName'];
    }

    if (profile['name'] != null && profile['name'].toString().isNotEmpty) {
      print('✅ Using name: ${profile['name']}');
      return profile['name'];
    }

    if (profile['email'] != null) {
      final email = profile['email'].toString();
      final username = email.split('@')[0];
      print('✅ Using email username: $username');
      return username;
    }

    print('⚠️ Falling back to UID for: $uid');
    return 'Member ${uid.substring(0, 4)}';
  }

  String _getMemberInitials(String uid) {
    final name = _getMemberDisplayName(uid);
    if (name.startsWith('Member')) {
      return name.substring(7, 8).toUpperCase();
    }
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
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
    // For now, just copy. Later can integrate share_plus package
    final message =
        'Join my room "${widget.room.name}" on One Room app!\n\n'
        'Room Code: ${widget.room.id}\n\n'
        'Use this code to join and sync all our tasks and expenses.';

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Share message copied! Paste it to share with roommates.',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.room.members.length} members',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Share Section
            Text(
              'Invite Members',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Room Code Card
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
                        Icons.vpn_key_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Room Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.room.id,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.content_copy_rounded),
                          onPressed: () => _copyRoomCode(context),
                          color: Theme.of(context).colorScheme.primary,
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Share this code with your roommates so they can join and sync all data.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _shareRoomCode(context),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Room Code'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
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
                  if (_isLoadingProfiles)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )
                  else
                    ...widget.room.members.asMap().entries.map((entry) {
                      final index = entry.key;
                      final memberId = entry.value;
                      final isCreator = memberId == widget.room.createdBy;
                      final memberName = _getMemberDisplayName(memberId);
                      final profile = _memberProfiles[memberId];
                      final photoUrl = profile?['photoUrl'] as String?;

                      return Column(
                        children: [
                          if (index > 0) const Divider(height: 24),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: photoUrl != null
                                    ? null
                                    : Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1),
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? Text(
                                        _getMemberInitials(memberId),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      )
                                    : null,
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
                                    if (profile?['email'] != null)
                                      Text(
                                        profile!['email'],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isCreator)
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
