import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rooms_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/safe_web_image.dart';

class AllMembersScreen extends StatefulWidget {
  const AllMembersScreen({super.key});

  @override
  State<AllMembersScreen> createState() => _AllMembersScreenState();
}

class _AllMembersScreenState extends State<AllMembersScreen> {
  final _firestore = FirestoreService();
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMembers();
  }

  Future<void> _loadAllMembers() async {
    final roomsProvider = context.read<RoomsProvider>();
    final allMemberIds = <String>{};

    // Collect all unique member IDs from all rooms
    for (var room in roomsProvider.rooms) {
      allMemberIds.addAll(room.members);
    }

    // Fetch profiles for all members
    try {
      final profiles = await _firestore.getUsersProfiles(allMemberIds.toList());
      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
      }
    }
  }

  List<MapEntry<String, List<String>>> _getMembersByRoom() {
    final roomsProvider = context.read<RoomsProvider>();
    final membersByRoom = <MapEntry<String, List<String>>>[];

    for (var room in roomsProvider.rooms) {
      membersByRoom.add(MapEntry(room.name, room.members));
    }

    return membersByRoom;
  }

  @override
  Widget build(BuildContext context) {
    final roomsProvider = Provider.of<RoomsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Members'),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : roomsProvider.rooms.isEmpty
            ? _buildEmptyState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary Card
                  _buildSummaryCard(roomsProvider),
                  const SizedBox(height: 24),

                  // Members by Room
                  ..._getMembersByRoom().map((entry) {
                    return _buildRoomMembersCard(entry.key, entry.value);
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildSummaryCard(RoomsProvider roomsProvider) {
    final uniqueMembers = <String>{};
    for (var room in roomsProvider.rooms) {
      uniqueMembers.addAll(room.members);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          Text(
            '${uniqueMembers.length}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Unique Members',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Across ${roomsProvider.rooms.length} room${roomsProvider.rooms.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomMembersCard(String roomName, List<String> memberIds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          // Room Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.home_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    roomName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${memberIds.length} ${memberIds.length == 1 ? 'member' : 'members'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Members List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: memberIds.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey.withValues(alpha: 0.2), height: 1),
            itemBuilder: (context, index) {
              final memberId = memberIds[index];
              final profile = _memberProfiles[memberId];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: profile?['photoURL'] != null
                      ? ClipOval(
                          child: SafeWebImage(
                            profile!['photoURL'],
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                _getInitials(profile['displayName'] ?? 'U'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          _getInitials(profile?['displayName'] ?? 'U'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                title: Text(
                  profile?['displayName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: profile?['email'] != null
                    ? Text(
                        profile!['email'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      )
                    : null,
                trailing: Icon(
                  Icons.person_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Members Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join or create a room to see members',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
}
