// lib/Models/room_notification.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  taskSwapRequest,
  taskSwapApproved,
  taskSwapRejected,
  taskAdded,
  taskEdited,
  taskDeleted,
  expenseAdded,
  expenseEdited,
  expenseDeleted,
  chatMessage,
  memberAdded,
  memberRemoved,
  paymentRecorded,
  other;

  String get displayName {
    switch (this) {
      case NotificationType.taskSwapRequest:
        return 'Task Swap Request';
      case NotificationType.taskSwapApproved:
        return 'Swap Approved';
      case NotificationType.taskSwapRejected:
        return 'Swap Rejected';
      case NotificationType.taskAdded:
        return 'Task Added';
      case NotificationType.taskEdited:
        return 'Task Updated';
      case NotificationType.taskDeleted:
        return 'Task Deleted';
      case NotificationType.expenseAdded:
        return 'Expense Added';
      case NotificationType.expenseEdited:
        return 'Expense Updated';
      case NotificationType.expenseDeleted:
        return 'Expense Deleted';
      case NotificationType.chatMessage:
        return 'New Message';
      case NotificationType.memberAdded:
        return 'Member Added';
      case NotificationType.memberRemoved:
        return 'Member Removed';
      case NotificationType.paymentRecorded:
        return 'Payment Recorded';
      case NotificationType.other:
        return 'Notification';
    }
  }
}

class RoomNotification {
  final String id;
  final String roomId;
  final String userId; // The user who should see this notification
  final NotificationType type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  // Optional metadata
  final String? actorId; // User who triggered this notification
  final String? actorName;
  final String? relatedId; // Task ID, Expense ID, etc.
  final String? taskInstanceId; // For swap requests
  final Map<String, dynamic>? additionalData;
  // Swap decision metadata (for taskSwapRequest notifications only)
  final String? swapDecision; // 'approved' | 'rejected'
  final DateTime? decisionAt;

  RoomNotification({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.actorId,
    this.actorName,
    this.relatedId,
    this.taskInstanceId,
    this.additionalData,
    this.swapDecision,
    this.decisionAt,
  });

  factory RoomNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RoomNotification(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.other,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actorId: data['actorId'],
      actorName: data['actorName'],
      relatedId: data['relatedId'],
      taskInstanceId: data['taskInstanceId'],
      additionalData: data['additionalData'] as Map<String, dynamic>?,
      swapDecision: data['swapDecision'] as String?,
      decisionAt: (data['decisionAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'userId': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'actorId': actorId,
      'actorName': actorName,
      'relatedId': relatedId,
      'taskInstanceId': taskInstanceId,
      'additionalData': additionalData,
      'swapDecision': swapDecision,
      'decisionAt': decisionAt != null ? Timestamp.fromDate(decisionAt!) : null,
    };
  }

  RoomNotification copyWith({bool? isRead}) {
    return RoomNotification(
      id: id,
      roomId: roomId,
      userId: userId,
      type: type,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actorId: actorId,
      actorName: actorName,
      relatedId: relatedId,
      taskInstanceId: taskInstanceId,
      additionalData: additionalData,
      swapDecision: swapDecision,
      decisionAt: decisionAt,
    );
  }
}
