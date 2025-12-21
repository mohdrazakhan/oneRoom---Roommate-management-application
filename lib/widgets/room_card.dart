// ignore_for_file: avoid_print
// lib/widgets/room_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Models/room.dart';
import '../Models/expense.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';
import '../providers/auth_provider.dart';
import '../screens/notifications/room_notifications_screen.dart';
import '../Models/payment.dart';
import '../screens/expenses/balances_screen.dart';
import '../screens/home/expense_analytics_screen.dart';
import 'safe_web_image.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;
  final VoidCallback? onTasksTap;
  final VoidCallback? onChatTap;
  final VoidCallback? onMorePressed;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onTasksTap,
    this.onChatTap,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final membersCount = room.members.length;
    final dateText = Formatters.formatDateTime(room.createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive padding and margins
        final horizontalMargin = constraints.maxWidth < 360 ? 12.0 : 16.0;
        final cardPadding = constraints.maxWidth < 360 ? 12.0 : 16.0;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.03),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Modern gradient avatar
                        GestureDetector(
                          onTap: onMorePressed,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Fallback Gradient & Initials (always visible as base or if error)
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _initials(room.name),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Image on top if available
                                  if (room.photoUrl != null &&
                                      room.photoUrl!.isNotEmpty)
                                    SafeWebImage(
                                      room.photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        // On error, just show the underlying gradient/initials
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title and subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created $dateText',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Notification icon with badge
                        _NotificationBadge(roomId: room.id),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip(
                          context,
                          Icons.people_rounded,
                          '$membersCount member${membersCount == 1 ? '' : 's'}',
                        ),
                        _buildInfoChip(
                          context,
                          Icons.insights_rounded,
                          'Analytics',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExpenseAnalyticsScreen(room: room),
                              ),
                            );
                          },
                        ),
                        // My balance chip (you owe / you get) for this room
                        _MyBalanceChip(roomId: room.id),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action buttons - Responsive
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Adapt to screen width
                        final isSmallScreen = constraints.maxWidth < 350;
                        final spacing = isSmallScreen ? 6.0 : 8.0;

                        return Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                context,
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Expenses',
                                onPressed: onTap,
                                isPrimary: true,
                                compact: isSmallScreen,
                              ),
                            ),
                            SizedBox(width: spacing),
                            Expanded(
                              child: _buildActionButton(
                                context,
                                icon: Icons.task_alt_rounded,
                                label: 'Tasks',
                                onPressed: onTasksTap,
                                isPrimary: false,
                                compact: isSmallScreen,
                              ),
                            ),
                            SizedBox(width: spacing),
                            Expanded(
                              child: _buildActionButton(
                                context,
                                icon: Icons.forum_rounded,
                                label: 'Chat',
                                onPressed: onChatTap,
                                isPrimary: false,
                                compact: isSmallScreen,
                              ),
                            ),
                            if (onMorePressed != null) ...[
                              SizedBox(width: spacing),
                              _buildIconOnlyButton(
                                context,
                                icon: Icons.settings_rounded,
                                onPressed: onMorePressed,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool compact = false,
  }) {
    return Material(
      color: isPrimary
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 12,
            horizontal: compact ? 4 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 18 : 20,
                color: isPrimary
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: compact ? 4 : 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 11 : 13,
                      color: isPrimary
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconOnlyButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}

class _MyBalanceChip extends StatelessWidget {
  final String roomId;

  const _MyBalanceChip({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser?.uid;
    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    // Include payments in the balance shown on the home card so it's consistent
    // with the Balances screen. We first listen to expenses, then combine with
    // payments and compute the net using BalanceCalculator.calculateBalancesWithPayments.
    return StreamBuilder<List<Expense>>(
      stream: FirestoreService().getExpensesStream(roomId),
      builder: (context, expenseSnapshot) {
        if (!expenseSnapshot.hasData) return const SizedBox.shrink();
        final expenses = expenseSnapshot.data!;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService().paymentsForRoom(roomId),
          builder: (context, paymentSnapshot) {
            if (!paymentSnapshot.hasData) {
              // If we at least have expenses, show the old calculation while payments load.
              if (expenses.isEmpty) return const SizedBox.shrink();
              final balances = BalanceCalculator.calculateBalances(expenses);
              final net = balances[uid] ?? 0.0;
              return _buildBalanceChip(context, net, roomId);
            }

            final paymentMaps = paymentSnapshot.data!;
            final payments = paymentMaps
                .map(
                  (m) => Payment(
                    id: m['id'] ?? '',
                    roomId: m['roomId'] ?? '',
                    payerId: m['payerId'] ?? '',
                    receiverId: m['receiverId'] ?? '',
                    amount: (m['amount'] ?? 0).toDouble(),
                    note: m['note'],
                    createdAt:
                        (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
                    createdBy: m['createdBy'] ?? '',
                  ),
                )
                .toList();

            if (expenses.isEmpty && payments.isEmpty) {
              return const SizedBox.shrink();
            }

            final balances = BalanceCalculator.calculateBalancesWithPayments(
              expenses,
              payments,
            );
            final net = balances[uid] ?? 0.0;
            return _buildBalanceChip(context, net, roomId);
          },
        );
      },
    );
  }

  Widget _buildBalanceChip(BuildContext context, double net, String roomId) {
    String label;
    Color color;
    IconData icon;

    if (net > 0.01) {
      label = 'You get ${Formatters.formatCurrency(net)}';
      color = Colors.green;
      icon = Icons.trending_up_rounded;
    } else if (net < -0.01) {
      label = 'You owe ${Formatters.formatCurrency(net.abs())}';
      color = Colors.red;
      icon = Icons.trending_down_rounded;
    } else {
      label = 'Settled';
      color = Colors.grey;
      icon = Icons.check_circle_rounded;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BalancesScreen(roomId: roomId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final String roomId;

  const _NotificationBadge({required this.roomId});

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser?.uid;

    if (uid == null || uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: FirestoreService().getUnreadNotificationCount(
        roomId: roomId,
        userId: uid,
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        // Debug logging
        if (snapshot.hasError) {
          print('❌ Error getting notification count: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          print('🔔 Notification count for room $roomId: $unreadCount');
        }

        return InkWell(
          onTap: () => _openNotifications(context),
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openNotifications(BuildContext context) async {
    // Get the room object from Firestore
    final roomSnapshot = await FirestoreService().streamRoomById(roomId).first;

    if (roomSnapshot == null) return;

    // We need to import Room model and convert the map to Room
    final room = Room.fromMap(roomSnapshot, roomSnapshot['id']);

    if (context.mounted) {
      // Import the notifications screen at the top of this file
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomNotificationsScreen(room: room),
        ),
      );
    }
  }
}
