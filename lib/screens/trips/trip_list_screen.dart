import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../Models/room.dart';
import '../../services/firestore_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/room_card.dart';
import '../chat/chat_screen.dart';
import '../expenses/expenses_list_screen.dart';
import 'trip_media_screen.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  bool _showTripFabActions = false;

  Future<bool> _leaveTrip(Room room) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Trip?'),
        content: const Text(
          'This trip will be removed from your list. If no members remain, it will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await _fs.leaveTripRoomForUser(roomId: room.id, userId: user.uid);
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip removed from your list.')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to leave trip: $e')));
      return false;
    }
  }

  Widget _buildTripActionEntry({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 170,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTripSettingsSheet(Room room) async {
    final joinCode = await _fs.getOrCreateTripJoinCode(room.id);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key_rounded),
                  title: const Text('Room Joining ID'),
                  subtitle: Text(joinCode),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: joinCode));
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Join ID copied')),
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: const Text('Member List'),
                  subtitle: const Text('View all members and remove member'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _showMemberListSheet(room);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.group_add_rounded),
                  title: const Text('Add Member'),
                  subtitle: const Text(
                    'Name is required, phone/email optional',
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _showAddMemberSheet(room);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddMemberSheet(Room room) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Member',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Member Name *',
                  hintText: 'Amit Kumar',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Member name is required.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await _fs.addGuestToRoom(
                        room.id,
                        name,
                        phoneNumber: phoneController.text.trim(),
                        email: emailController.text.trim(),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                      return;
                    }

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Member added successfully.'),
                      ),
                    );
                  },
                  child: const Text('Add Member'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMemberListSheet(Room room) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _fs.streamRoomById(room.id),
          builder: (context, snap) {
            final roomMap = snap.data;
            final creatorUid = (roomMap?['createdBy'] ?? '').toString();
            final membersRaw = roomMap?['members'];
            final memberUidsRaw = roomMap?['memberUids'];
            final roomMemberUids = <String>{
              ...(membersRaw is List
                  ? membersRaw.cast<String>()
                  : const <String>[]),
              ...(memberUidsRaw is List
                  ? memberUidsRaw.cast<String>()
                  : const <String>[]),
            }.toList();

            final guestsRaw = roomMap?['guests'] as Map<String, dynamic>? ?? {};

            final guestMembers = guestsRaw.entries
                .where((entry) {
                  final value = entry.value;
                  if (value is! Map<String, dynamic>) return false;
                  return value['isActive'] != false;
                })
                .map((entry) {
                  final value = entry.value as Map<String, dynamic>;
                  return {
                    'id': entry.key,
                    'name': (value['name'] ?? '').toString(),
                    'phoneNumber': value['phoneNumber']?.toString(),
                    'email': value['email']?.toString(),
                    'type': 'guest',
                  };
                })
                .toList();

            return FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: _fs.getUsersProfiles(roomMemberUids),
              builder: (context, profilesSnap) {
                final profiles =
                    profilesSnap.data ?? const <String, Map<String, dynamic>>{};

                final roomMembers = roomMemberUids.map((uid) {
                  final profile = profiles[uid];
                  final displayName =
                      (profile?['displayName'] ??
                              profile?['name'] ??
                              (profile?['email'] != null
                                  ? (profile?['email'] as String)
                                        .split('@')
                                        .first
                                  : uid))
                          .toString();

                  return <String, dynamic>{
                    'id': uid,
                    'name': displayName,
                    'email': profile?['email']?.toString(),
                    'type': 'auth',
                    'isCreator': uid == creatorUid,
                  };
                }).toList();

                final members = <Map<String, dynamic>>[
                  ...roomMembers,
                  ...guestMembers,
                ];

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Members',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('No members added yet.'),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 380),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: members.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                final extras = <String>[];
                                final phone = member['phoneNumber'];
                                final email = member['email'];
                                if (phone != null && phone.isNotEmpty) {
                                  extras.add(phone);
                                }
                                if (email != null && email.isNotEmpty) {
                                  extras.add(email);
                                }

                                final name =
                                    (member['name'] as String?)?.trim() ?? '';
                                final isCreator = member['isCreator'] == true;
                                final isGuest = member['type'] == 'guest';

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      name.isEmpty
                                          ? '?'
                                          : name[0].toUpperCase(),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name.isEmpty ? 'Unnamed' : name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCreator)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(
                                              alpha: 0.18,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Text(
                                            'Creator',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    extras.isEmpty
                                        ? (isGuest
                                              ? 'Guest member'
                                              : 'Room member')
                                        : extras.join(' • '),
                                  ),
                                  trailing: isGuest
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline_rounded,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            await _fs.removeGuestFromRoom(
                                              room.id,
                                              member['id'] as String,
                                            );
                                          },
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showJoinTripSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final joinIdController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join Trip',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: joinIdController,
                decoration: const InputDecoration(
                  labelText: 'Room Joining ID *',
                  hintText: 'Enter 6-digit alphanumeric code',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final joinId = joinIdController.text.trim().toUpperCase();
                    if (joinId.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Room Joining ID is required.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await _fs.joinTripByCode(
                        joinCode: joinId,
                        userId: user.uid,
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                      return;
                    }

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Joined trip successfully.'),
                      ),
                    );
                  },
                  child: const Text('Join Trip'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateTripSheet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    XFile? tripImage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> pickImage() async {
              final picked = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
                maxWidth: 1200,
                maxHeight: 1200,
              );
              if (picked == null) return;
              setLocalState(() => tripImage = picked);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Trip',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Trip name *',
                      hintText: 'Goa Trip',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Short details about this trip',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Upload image'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tripImage == null
                              ? 'No image selected'
                              : 'Image selected',
                          style: TextStyle(color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final tripName = nameController.text.trim();
                        if (tripName.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Trip name is required.'),
                            ),
                          );
                          return;
                        }

                        await _fs.createTripRoom(
                          uid: user.uid,
                          name: tripName,
                          description: descriptionController.text.trim(),
                          imageFile: tripImage,
                        );

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Create Trip'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login first')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Wallet')),
      body: Stack(
        children: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _fs.roomsForUser(user.uid),
            builder: (context, snap) {
              final rawRooms = snap.data ?? const <Map<String, dynamic>>[];
              final tripRooms = rawRooms
                  .where((room) {
                    final settings = room['settings'] as Map<String, dynamic>?;
                    return (settings?['isTrip'] == true) ||
                        (room['isTrip'] == true);
                  })
                  .map((m) => Room.fromMap(m, (m['id'] ?? '').toString()))
                  .toList();

              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (tripRooms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Trips Yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a trip and start splitting expenses',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 90),
                itemCount: tripRooms.length,
                itemBuilder: (context, index) {
                  final room = tripRooms[index];
                  return Dismissible(
                    key: ValueKey('trip_${room.id}'),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (_) => _leaveTrip(room),
                    background: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Row(
                        children: [
                          Icon(Icons.exit_to_app_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Leave Trip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Leave Trip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.exit_to_app_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                    child: RoomCard(
                      room: room,
                      showTasksAction: false,
                      showSettingsAction: true,
                      showFolderAction: true,
                      showBalanceChip: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpensesListScreen(
                              roomId: room.id,
                              roomName: room.name,
                            ),
                          ),
                        );
                      },
                      onChatTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              roomId: room.id,
                              roomName: room.name,
                            ),
                          ),
                        );
                      },
                      onFolderTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TripMediaScreen(
                              roomId: room.id,
                              roomName: room.name,
                            ),
                          ),
                        );
                      },
                      onMorePressed: () => _showTripSettingsSheet(room),
                    ),
                  );
                },
              );
            },
          ),
          if (_showTripFabActions)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showTripFabActions = false),
                child: Container(color: Colors.black.withValues(alpha: 0.30)),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showTripFabActions) ...[
            _buildTripActionEntry(
              icon: Icons.group_add_rounded,
              title: 'Join Trip',
              subtitle: 'Join an existing trip',
              onTap: () async {
                setState(() => _showTripFabActions = false);
                await _showJoinTripSheet();
              },
            ),
            _buildTripActionEntry(
              icon: Icons.add_rounded,
              title: 'Create Trip',
              subtitle: 'Start a new trip',
              onTap: () async {
                setState(() => _showTripFabActions = false);
                await _showCreateTripSheet();
              },
            ),
          ],
          FloatingActionButton(
            onPressed: () {
              setState(() => _showTripFabActions = !_showTripFabActions);
            },
            child: Icon(_showTripFabActions ? Icons.close : Icons.add),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: const SafeArea(top: false, child: MyBannerAd()),
    );
  }
}
