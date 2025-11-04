// lib/services/notification_helper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

/// Helper methods to send notifications for various app events
class NotificationHelper {
  static final _firestore = FirebaseFirestore.instance;
  static final _notificationService = NotificationService();

  /// Get current user's display name
  static Future<String> _getCurrentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Someone';

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    return userDoc.data()?['displayName'] as String? ??
        userDoc.data()?['name'] as String? ??
        user.displayName ??
        'Someone';
  }

  /// Notify when a new member is added to a room
  static Future<void> notifyMemberAdded({
    required String roomId,
    required String roomName,
    required String newMemberName,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '👥 New member in $roomName',
      body: '$senderName added $newMemberName to the room',
      data: {
        'type': 'member_added',
        'roomId': roomId,
        'screen': 'room_settings',
      },
    );
  }

  /// Notify when a task is created
  static Future<void> notifyTaskCreated({
    required String roomId,
    required String roomName,
    required String taskTitle,
    required String categoryName,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '✅ New task in $roomName',
      body: '$senderName created "$taskTitle" in $categoryName',
      data: {'type': 'task_created', 'roomId': roomId, 'screen': 'tasks'},
    );
  }

  /// Notify when a task is edited
  static Future<void> notifyTaskEdited({
    required String roomId,
    required String roomName,
    required String taskTitle,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '✏️ Task updated in $roomName',
      body: '$senderName updated "$taskTitle"',
      data: {'type': 'task_edited', 'roomId': roomId, 'screen': 'tasks'},
    );
  }

  /// Notify when a task is deleted
  static Future<void> notifyTaskDeleted({
    required String roomId,
    required String roomName,
    required String taskTitle,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '🗑️ Task deleted in $roomName',
      body: '$senderName deleted "$taskTitle"',
      data: {'type': 'task_deleted', 'roomId': roomId, 'screen': 'tasks'},
    );
  }

  /// Notify when an expense is created
  static Future<void> notifyExpenseCreated({
    required String roomId,
    required String roomName,
    required String description,
    required double amount,
    required String currency,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '💰 New expense in $roomName',
      body: '$senderName added "$description" - $currency$amount',
      data: {'type': 'expense_created', 'roomId': roomId, 'screen': 'expenses'},
    );
  }

  /// Notify when an expense is edited
  static Future<void> notifyExpenseEdited({
    required String roomId,
    required String roomName,
    required String description,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '✏️ Expense updated in $roomName',
      body: '$senderName updated "$description"',
      data: {'type': 'expense_edited', 'roomId': roomId, 'screen': 'expenses'},
    );
  }

  /// Notify when an expense is deleted
  static Future<void> notifyExpenseDeleted({
    required String roomId,
    required String roomName,
    required String description,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '🗑️ Expense deleted in $roomName',
      body: '$senderName deleted "$description"',
      data: {'type': 'expense_deleted', 'roomId': roomId, 'screen': 'expenses'},
    );
  }

  /// Notify when a chat message is sent
  static Future<void> notifyChatMessage({
    required String roomId,
    required String roomName,
    required String messagePreview,
  }) async {
    final senderName = await _getCurrentUserName();
    await _notificationService.sendNotificationToRoom(
      roomId: roomId,
      title: '💬 $senderName in $roomName',
      body: messagePreview,
      data: {
        'type': 'chat_message',
        'roomId': roomId,
        'roomName': roomName,
        'screen': 'chat',
      },
    );
  }

  /// Notify a specific user about their task for today
  static Future<void> notifyDailyTaskReminder({
    required String userId,
    required String taskTitle,
    required String roomName,
  }) async {
    await _notificationService.sendNotificationToUser(
      userId: userId,
      title: '⏰ Task reminder',
      body: 'Don\'t forget: "$taskTitle" in $roomName',
      data: {'type': 'task_reminder', 'screen': 'my_tasks'},
    );
  }
}
