import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';

import '../../providers/rooms_provider.dart';

import '../../widgets/safe_web_image.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/room_card.dart';
import '../../services/subscription_service.dart';
import '../../services/firestore_service.dart';

import '../expenses/expenses_list_screen.dart';
import '../tasks/tasks_home_screen.dart';
import '../tasks/my_tasks_dashboard.dart';
import '../profile/profile_screen.dart';
import '../profile/report_bug_screen.dart';
import '../profile/about_screen.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'enhanced_room_settings_screen.dart';
import '../chat/chat_screen.dart';
import 'all_members_screen.dart';
import '../../widgets/premium_avatar_wrapper.dart';
import '../personal/personal_expenses_list_screen.dart';
import '../trips/trip_list_screen.dart';
import '../../widgets/ad_banner_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showRoomOptions = false;
  int _adInsertIndex = 1;

  void _toggleRoomOptions() {
    setState(() {
      _showRoomOptions = !_showRoomOptions;
    });
  }

  Future<void> _showMoreOptionsSheet() async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.14),
                        colorScheme.secondary.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      const Text(
                        'More Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildMoreOptionTile(
                  icon: Icons.bug_report_rounded,
                  title: 'Report a Bug',
                  subtitle: 'Tell us what went wrong',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReportBugScreen(),
                      ),
                    );
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.code_rounded,
                  title: 'Developer',
                  subtitle: 'App and developer details',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
                _buildMoreOptionTile(
                  icon: Icons.person_rounded,
                  title: 'Profile',
                  subtitle: 'Manage your account',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomsProvider = Provider.of<RoomsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isPremium = Provider.of<SubscriptionService>(context).isPremium;
    final user = authProvider.firebaseUser;
    final profile = authProvider.profile;

    return Stack(
      children: [
        Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false, // Allow content to extend behind navbar
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
                                      SnackBar(
                                        content: Text('Logout failed: $e'),
                                      ),
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
                                final isPremium =
                                    Provider.of<SubscriptionService>(
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
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
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Center(
                                                          child: Text(
                                                            fallbackInitials,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 20,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Failed to load rooms',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
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
          extendBody: true, // Allows body to scroll behind the navbar
          floatingActionButton: null,
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            height: 75,
            decoration: BoxDecoration(
              color: Colors.transparent, // Background handled by child Display
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.65),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 1. Join/Create Room
                      _buildNavItem(
                        context,
                        icon: Icons.add_home_work_rounded,
                        tooltip: 'Rooms',
                        onTap: _toggleRoomOptions,
                      ),

                      // 2. Trip Planner
                      _buildNavItem(
                        context,
                        icon: Icons.flight_takeoff_rounded,
                        tooltip: 'Trips',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TripListScreen(),
                            ),
                          );
                        },
                      ),

                      // 3. Center: Personal Expenses (Prominent)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PersonalExpensesListScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 28,
                          ),
                        ),
                      ),

                      // 4. Dummy
                      _buildNavItem(
                        context,
                        icon: Icons.star_border_rounded,
                        tooltip: 'Saved',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming Soon')),
                          );
                        },
                      ),

                      // 5. Dummy
                      _buildNavItem(
                        context,
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'More',
                        onTap: _showMoreOptionsSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Blur Overlay Background (Excluding Navbar with ClipPath)
        if (_showRoomOptions)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => setState(() => _showRoomOptions = false),
              child: ClipPath(
                clipper: _NavbarExclusionClipper(),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withValues(alpha: 0.2)),
                ),
              ),
            ),
          ),
        // Transparent Tap Zone for Navbar Area (No Blur)
        if (_showRoomOptions)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 160,
            child: GestureDetector(
              onTap: () => setState(() => _showRoomOptions = false),
              child: Container(color: Colors.transparent),
            ),
          ),

        // Circular Icon Dropdown Menu (No Background Card)
        if (_showRoomOptions)
          Positioned(
            left: MediaQuery.of(context).size.width * 0.08,
            bottom: MediaQuery.of(context).size.height * 0.13,
            child: AnimatedOpacity(
              opacity: _showRoomOptions ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedSlide(
                offset: _showRoomOptions ? Offset.zero : const Offset(0, 0.3),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Join Room
                    GestureDetector(
                      onTap: () {
                        setState(() => _showRoomOptions = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinRoomScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.group_add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Join Room',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Join an existing room',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 11,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Create Room
                    GestureDetector(
                      onTap: () {
                        setState(() => _showRoomOptions = false);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateRoomScreen(),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Create Room',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Start a new room',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 11,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 26,
      ),
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
    final rooms = roomsProvider.rooms;

    // Ensure _adInsertIndex is valid
    if (_adInsertIndex > rooms.length) {
      _adInsertIndex = rooms.length;
    }

    // Total items = rooms + 1 ad card
    final totalItems = rooms.length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

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
            itemCount: totalItems,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }

                if (oldIndex == _adInsertIndex) {
                  // Moving the ad
                  _adInsertIndex = newIndex;
                } else {
                  // Moving a room
                  final roomOldIndex = oldIndex < _adInsertIndex
                      ? oldIndex
                      : oldIndex - 1;
                  final roomNewIndex = newIndex <= _adInsertIndex
                      ? newIndex
                      : newIndex - 1;

                  roomsProvider.reorderRooms(roomOldIndex, roomNewIndex);

                  // Update adInsertIndex if a room moved past it
                  if (oldIndex < _adInsertIndex && newIndex >= _adInsertIndex) {
                    _adInsertIndex--;
                  } else if (oldIndex > _adInsertIndex &&
                      newIndex <= _adInsertIndex) {
                    _adInsertIndex++;
                  }
                }
              });
            },
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? childWidget) {
                  return Material(
                    elevation: 8.0,
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.transparent,
                    child: childWidget,
                  );
                },
                child: child,
              );
            },
            itemBuilder: (context, virtualIndex) {
              // Insert ad card at _adInsertIndex
              if (virtualIndex == _adInsertIndex && rooms.isNotEmpty) {
                return Container(
                  key: const ValueKey('ad_card_widget'),
                  margin: const EdgeInsets.only(
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  child: const AdCardWidget(),
                );
              }

              // Map virtual index back to real room index
              final roomIndex = virtualIndex < _adInsertIndex
                  ? virtualIndex
                  : virtualIndex - 1;

              if (roomIndex >= rooms.length) return const SizedBox.shrink();
              final room = rooms[roomIndex];

              return Container(
                key: ValueKey(room.id),
                margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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

// Custom Clipper to exclude rounded navbar from blur
class _NavbarExclusionClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Add the entire screen to the path
    path.addRect(Rect.fromLTRB(0, 0, size.width, size.height));

    // Cut out the rounded navbar shape at the bottom
    // Navbar: margin 20px from sides and bottom, height 75px, radius 30px
    final navbarRect = RRect.fromLTRBR(
      20, // left margin
      size.height - 95, // top (height - navbar height - bottom margin)
      size.width - 20, // right margin
      size.height - 20, // bottom margin
      const Radius.circular(30), // border radius
    );

    path.addRRect(navbarRect);
    path.fillType = PathFillType.evenOdd; // This creates a cutout

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
