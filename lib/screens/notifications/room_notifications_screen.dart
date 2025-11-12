// lib/screens/notifications/room_notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/room_notification.dart';
import '../../Models/room.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../tasks/my_tasks_dashboard.dart';

class RoomNotificationsScreen extends StatefulWidget {
  final Room room;

  const RoomNotificationsScreen({super.key, required this.room});

  @override
  State<RoomNotificationsScreen> createState() =>
      _RoomNotificationsScreenState();
}

class _RoomNotificationsScreenState extends State<RoomNotificationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  // Local optimistic cache of decisions keyed by taskInstanceId
  final Map<String, String> _localSwapDecisions = {};

  @override
  void initState() {
    super.initState();
    // Mark all as read when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
    });
  }

  Future<void> _markAllAsRead() async {
    final uid = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser?.uid;

    if (uid == null) return;

    try {
      await _firestoreService.markAllNotificationsAsRead(
        roomId: widget.room.id,
        userId: uid,
      );
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<AuthProvider>(context).firebaseUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.room.name} Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear all',
            onPressed: () => _clearAllNotifications(uid),
          ),
        ],
      ),
      body: StreamBuilder<List<RoomNotification>>(
        stream: _firestoreService.getNotificationsStream(
          roomId: widget.room.id,
          userId: uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll be notified about task swaps,\nexpenses, and chat messages',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(context, notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    RoomNotification notification,
  ) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _firestoreService.deleteNotification(notification.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notification deleted')));
      },
      child: Material(
        color: notification.isRead
            ? Colors.white
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(context, notification),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(
                      notification.type,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Formatters.formatRelativeTime(notification.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      // Action buttons for swap requests
                      if (notification.type ==
                              NotificationType.taskSwapRequest &&
                          notification.taskInstanceId != null)
                        _buildSwapSection(context, notification),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapSection(
    BuildContext context,
    RoomNotification notification,
  ) {
    final decision =
        notification.swapDecision ??
        _localSwapDecisions[notification.taskInstanceId!];
    if (decision != null) {
      final isApproved = decision == 'approved';
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isApproved ? Colors.green : Colors.red).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isApproved ? Icons.check_rounded : Icons.close_rounded,
                size: 16,
                color: isApproved ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isApproved ? 'Approved' : 'Rejected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isApproved ? Colors.green[800] : Colors.red[800],
                ),
              ),
              if (notification.decisionAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  Formatters.formatRelativeTime(notification.decisionAt!),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // No decision yet -> show action buttons
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _respondToSwap(context, notification.taskInstanceId!, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _respondToSwap(context, notification.taskInstanceId!, false),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToSwap(
    BuildContext context,
    String taskInstanceId,
    bool approve,
  ) async {
    try {
      await _firestoreService.respondToSwapRequest(
        roomId: widget.room.id,
        taskInstanceId: taskInstanceId,
        approve: approve,
      );
      // Optimistic local update so chip appears immediately
      setState(() {
        _localSwapDecisions[taskInstanceId] = approve ? 'approved' : 'rejected';
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Swap approved!' : 'Swap rejected'),
            backgroundColor: approve ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    RoomNotification notification,
  ) {
    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.taskSwapRequest:
      case NotificationType.taskSwapApproved:
      case NotificationType.taskSwapRejected:
      case NotificationType.taskAdded:
      case NotificationType.taskEdited:
      case NotificationType.taskDeleted:
        // Navigate to tasks screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyTasksDashboard()),
        );
        break;
      case NotificationType.expenseAdded:
      case NotificationType.expenseEdited:
      case NotificationType.expenseDeleted:
        // Navigate back to room (expenses)
        Navigator.pop(context);
        break;
      case NotificationType.chatMessage:
        // Navigate to chat - you'll need to implement this
        Navigator.pop(context);
        break;
      default:
        break;
    }
  }

  Future<void> _clearAllNotifications(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteAllNotifications(
          roomId: widget.room.id,
          userId: uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.taskSwapRequest:
        return Icons.swap_horiz_rounded;
      case NotificationType.taskSwapApproved:
        return Icons.check_circle_rounded;
      case NotificationType.taskSwapRejected:
        return Icons.cancel_rounded;
      case NotificationType.taskAdded:
      case NotificationType.taskEdited:
        return Icons.task_alt_rounded;
      case NotificationType.taskDeleted:
        return Icons.delete_rounded;
      case NotificationType.expenseAdded:
      case NotificationType.expenseEdited:
        return Icons.receipt_long_rounded;
      case NotificationType.expenseDeleted:
        return Icons.money_off_rounded;
      case NotificationType.chatMessage:
        return Icons.chat_bubble_rounded;
      case NotificationType.memberAdded:
        return Icons.person_add_rounded;
      case NotificationType.memberRemoved:
        return Icons.person_remove_rounded;
      case NotificationType.other:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.taskSwapRequest:
        return Colors.blue;
      case NotificationType.taskSwapApproved:
        return Colors.green;
      case NotificationType.taskSwapRejected:
        return Colors.red;
      case NotificationType.taskAdded:
      case NotificationType.taskEdited:
        return Colors.purple;
      case NotificationType.taskDeleted:
        return Colors.red;
      case NotificationType.expenseAdded:
      case NotificationType.expenseEdited:
        return Colors.orange;
      case NotificationType.expenseDeleted:
        return Colors.red;
      case NotificationType.chatMessage:
        return Colors.teal;
      case NotificationType.memberAdded:
        return Colors.green;
      case NotificationType.memberRemoved:
        return Colors.orange;
      case NotificationType.other:
        return Colors.grey;
    }
  }
}
