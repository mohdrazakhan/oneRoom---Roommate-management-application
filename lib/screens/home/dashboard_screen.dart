import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/rooms_provider.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/safe_web_image.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/room_card.dart';
import '../../services/subscription_service.dart';
import '../../services/firestore_service.dart';

import '../expenses/expenses_list_screen.dart';
import '../tasks/tasks_home_screen.dart';
import '../tasks/my_tasks_dashboard.dart';
import '../profile/profile_screen.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'enhanced_room_settings_screen.dart';
import '../chat/chat_screen.dart';
import 'all_members_screen.dart';
import '../../widgets/premium_avatar_wrapper.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roomsProvider = Provider.of<RoomsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isPremium = Provider.of<SubscriptionService>(context).isPremium;
    final user = authProvider.firebaseUser;
    final profile = authProvider.profile;

    return Scaffold(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                final displayName =
                                    profile?.displayName ??
                                    user?.displayName ??
                                    'Roommate';
                                return Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'logout') {
                              try {
                                await authProvider.signOut();
                                if (!context.mounted) return;
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Logout failed: $e')),
                                );
                              }
                            } else if (value == 'profile') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            } else if (value == 'premium') {
                              Navigator.pushNamed(context, '/subscription');
                            }
                          },
                          itemBuilder: (context) {
                            final isPremium = Provider.of<SubscriptionService>(
                              context,
                              listen: false,
                            ).isPremium;
                            return [
                              const PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_rounded),
                                    SizedBox(width: 12),
                                    Text('Profile'),
                                  ],
                                ),
                              ),
                              if (!isPremium)
                                const PopupMenuItem(
                                  value: 'premium',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.workspace_premium,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Go Premium',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout_rounded,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sign Out',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                          },
                          child: PremiumAvatarWrapper(
                            isPremium: isPremium,
                            size: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Builder(
                                builder: (context) {
                                  final fallbackInitials = _getInitials(
                                    profile?.displayName ??
                                        user?.displayName ??
                                        'R',
                                  );

                                  return CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    child: user?.photoURL != null
                                        ? ClipOval(
                                            child: SafeWebImage(
                                              user!.photoURL!,
                                              fit: BoxFit.cover,
                                              width: 56,
                                              height: 56,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Center(
                                                      child: Text(
                                                        fallbackInitials,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                              fallbackInitials,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats Row
                    _buildStatsRow(context, roomsProvider),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await roomsProvider.refresh();
                  },
                  child: roomsProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : roomsProvider.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load rooms',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  roomsProvider.error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: () => roomsProvider.refresh(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : roomsProvider.rooms.isEmpty
                      ? _buildEmptyState(context)
                      : _buildRoomsList(context, roomsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SafeArea(child: MyBannerAd()),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showRoomOptionsMenu(context);
        },
        elevation: 8,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showRoomOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text(
                  'Create New Room',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Start a new room for your group'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.group_add_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: const Text(
                  'Join Existing Room',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Enter a room code to join'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(BuildContext context, RoomsProvider roomsProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.firebaseUser;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            Icons.home_rounded,
            '${roomsProvider.rooms.length}',
            'Rooms',
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllMembersScreen()),
              );
            },
            child: _buildStatItem(
              context,
              Icons.people_rounded,
              _getTotalMembers(roomsProvider).toString(),
              'Members',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          FutureBuilder<int>(
            future: FirestoreService().getTotalTasksCount(user?.uid ?? ''),
            builder: (context, snapshot) {
              final taskCount = snapshot.data ?? 0;
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyTasksDashboard()),
                  );
                },
                child: _buildStatItem(
                  context,
                  Icons.task_alt_rounded,
                  '$taskCount',
                  'Tasks',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_work_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to One Room!',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Get started by creating a new room or\njoining an existing one',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Option Cards
          _buildOptionCard(
            context,
            icon: Icons.add_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            title: 'Create New Room',
            description: 'Start fresh and invite your roommates to join',
            features: [
              'You\'ll be the room admin',
              'Get a shareable room code',
              'Invite unlimited members',
            ],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
              );
            },
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[300])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[300])),
            ],
          ),

          const SizedBox(height: 20),

          _buildOptionCard(
            context,
            icon: Icons.group_add_rounded,
            color: Theme.of(context).colorScheme.secondary,
            title: 'Join Existing Room',
            description: 'Enter a room code to join your roommates',
            features: [
              'Sync all data instantly',
              'Collaborate in real-time',
              'Share expenses & tasks',
            ],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 20, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Get Started',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: color, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList(BuildContext context, RoomsProvider roomsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Rooms',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  authProvider.signOut();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 180),
            itemCount: roomsProvider.rooms.length,
            onReorder: (oldIndex, newIndex) {
              roomsProvider.reorderRooms(oldIndex, newIndex);
            },
            proxyDecorator: (width, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  return Material(
                    elevation: 8.0,
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.transparent,
                    child: child,
                  );
                },
                child: RoomCard(room: roomsProvider.rooms[index]),
              );
            },
            itemBuilder: (context, i) {
              final room = roomsProvider.rooms[i];
              return Container(
                key: ValueKey(room.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: RoomCard(
                  room: room,
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
                  onTasksTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TasksHomeScreen(
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
                        builder: (_) =>
                            ChatScreen(roomId: room.id, roomName: room.name),
                      ),
                    );
                  },
                  onMorePressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EnhancedRoomSettingsScreen(room: room),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'R';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'R';
    }
    final first = parts[0].isNotEmpty ? parts[0][0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    if (first.isEmpty) return 'R';
    return (first + second).toUpperCase();
  }

  int _getTotalMembers(RoomsProvider roomsProvider) {
    final uniqueMembers = <String>{};
    for (var room in roomsProvider.rooms) {
      uniqueMembers.addAll(room.members);
    }
    return uniqueMembers.length;
  }
}
