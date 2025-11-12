// lib/screens/home/room_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../Models/room.dart';
import '../../Models/user_profile.dart';
import '../expenses/expenses_list_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late TabController _tabController;
  bool _adding = false;
  final _addEmailCtrl = TextEditingController();
  bool _loadingProfiles = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Subscribe this device to the room topic to receive pushes for chats, tasks, and expenses
    // Note: We intentionally do NOT unsubscribe on dispose so the user continues to receive
    // room notifications while a member. Unsubscribe when leaving the room.
    try {
      // Lazy import to avoid heavier import graph at top
      // ignore: avoid_dynamic_calls
      Future.microtask(() async {
        // Defer to ensure widget fields are initialized
        final notificationService = NotificationService();
        await notificationService.subscribeToRoom(widget.roomId);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _addMemberByEmail(String email) async {
    if (email.trim().isEmpty) {
      _showMsg('Please enter an email');
      return;
    }
    setState(() => _adding = true);
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        _showMsg('No user found with that email');
        return;
      }
      final uid = q.docs.first.id;
      await _fs.addMember(widget.roomId, uid);
      _showMsg('Member added');
      _addEmailCtrl.clear();
    } catch (e) {
      _showMsg('Failed to add member: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _leaveRoom(String uid) async {
    try {
      await _fs.leaveRoom(widget.roomId, uid);
      // Unsubscribe from room topic upon leaving
      try {
        await NotificationService().unsubscribeFromRoom(widget.roomId);
      } catch (_) {}
      _showMsg('You left the room');
      // After leaving, navigate back to dashboard
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMsg('Failed to leave room: $e');
    }
  }

  Future<void> _deleteRoom(String uid, String createdBy) async {
    // Only creator can delete
    if (uid != createdBy) {
      _showMsg('Only the room creator can delete this room');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete room?'),
        content: const Text(
          'This will permanently delete the room and its expenses. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      // Delete expenses subcollection (batch delete) then delete room doc.
      final expensesSnap = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('expenses')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in expensesSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
        FirebaseFirestore.instance.collection('rooms').doc(widget.roomId),
      );
      await batch.commit();
      _showMsg('Room deleted');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showMsg('Failed to delete room: $e');
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Helper to load member profiles from the room doc
  Future<List<UserProfile>> _loadMemberProfiles(
    List<dynamic> memberUids,
  ) async {
    if (mounted) {
      setState(() => _loadingProfiles = true);
    }
    try {
      final results = <UserProfile>[];
      for (final uidValue in memberUids) {
        final uid = uidValue as String?;
        if (uid == null) {
          continue;
        }
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (snap.exists) {
          results.add(UserProfile.fromDoc(snap));
        } else {
          results.add(
            UserProfile(
              uid: uid,
              displayName: null,
              email: null,
              photoUrl: null,
            ),
          );
        }
      }
      return results;
    } finally {
      if (mounted) {
        setState(() => _loadingProfiles = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUid = auth.firebaseUser?.uid;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _fs.streamRoomById(widget.roomId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final roomMap = snap.data;
        if (roomMap == null) {
          return const Scaffold(body: Center(child: Text('Room not found')));
        }

        final room = Room.fromMap(
          Map<String, dynamic>.from(roomMap),
          roomMap['id'] as String,
        );
        final members = room.members;

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Expenses'),
              ],
            ),
            actions: [
              if (currentUid == room.createdBy)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete room',
                  onPressed: () =>
                      _deleteRoom(currentUid ?? '', room.createdBy),
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // DETAILS TAB
              SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room info', style: AppTextStyles.heading2),
                    const SizedBox(height: AppSpacing.sm),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(room.name, style: AppTextStyles.heading1),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Created by: ${room.createdBy}',
                              style: AppTextStyles.body,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Members: ${members.length}',
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Members section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Members', style: AppTextStyles.heading2),
                        TextButton.icon(
                          onPressed: () async {
                            // Refresh members by reloading the room in provider (roomsProv already listening)
                            setState(() {});
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Member list (load profiles)
                    FutureBuilder<List<UserProfile>>(
                      future: _loadMemberProfiles(members),
                      builder: (context, profSnap) {
                        if (profSnap.connectionState ==
                                ConnectionState.waiting ||
                            _loadingProfiles) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final list = profSnap.data ?? [];
                        if (list.isEmpty) return const Text('No members');
                        return Column(
                          children: list.map((p) {
                            final isMe = p.uid == currentUid;
                            final display = p.displayName?.isNotEmpty == true
                                ? p.displayName
                                : (p.email ?? p.uid);
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  display?.substring(0, 1).toUpperCase() ?? '',
                                ),
                              ),
                              title: Text(display ?? ''),
                              subtitle: Text(p.email ?? ''),
                              trailing: isMe
                                  ? TextButton(
                                      onPressed: () async {
                                        // leave room
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Leave room?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text(
                                                  'Leave',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true &&
                                            currentUid != null) {
                                          await _leaveRoom(currentUid);
                                        }
                                      },
                                      child: const Text('Leave'),
                                    )
                                  : null,
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Add member by email
                    const Text(
                      'Add member (by email)',
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addEmailCtrl,
                            decoration: const InputDecoration(
                              hintText: 'member@example.com',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ElevatedButton(
                          onPressed: _adding
                              ? null
                              : () => _addMemberByEmail(
                                  _addEmailCtrl.text.trim(),
                                ),
                          child: _adding
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // EXPENSES TAB
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open full expenses for this room',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.list),
                        label: const Text('View Expenses'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpensesListScreen(
                                roomId: widget.roomId,
                                roomName: widget.roomName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
