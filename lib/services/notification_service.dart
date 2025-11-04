// lib/services/notification_service.dart
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Top-level handler for background messages (must be top-level or static)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background message: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission (iOS/macOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('⚠️ Notification permission provisional');
    } else {
      debugPrint('❌ Notification permission denied');
      return;
    }

    // Initialize local notifications for Android/iOS foreground display
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Get FCM token and save to Firestore
    await _saveTokenToFirestore();

    // Subscribe to "all_users" topic for broadcast notifications
    await _messaging.subscribeToTopic('all_users');
    debugPrint('📢 Subscribed to all_users topic for broadcasts');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'one_room_channel',
      'One Room Notifications',
      channelDescription: 'Notifications for room activities',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on payload
  }

  /// Handle when user taps notification while app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 App opened from notification: ${message.data}');
    // TODO: Navigate to relevant screen based on message.data
  }

  /// Save FCM token to Firestore for this user/device
  Future<void> _saveTokenToFirestore([String? token]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final fcmToken = token ?? await _messaging.getToken();
    if (fcmToken == null) return;

    debugPrint('💾 Saving FCM token: ${fcmToken.substring(0, 20)}...');

    // Store in users/{uid}/tokens/{token} for multi-device support
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tokens')
        .doc(fcmToken)
        .set({
          'token': fcmToken,
          'platform': Platform.operatingSystem,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUsed': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Remove token when user logs out
  Future<void> removeToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tokens')
        .doc(token)
        .delete();

    debugPrint('🗑️ FCM token removed');
  }

  /// Subscribe to a room topic for room-wide notifications
  Future<void> subscribeToRoom(String roomId) async {
    await _messaging.subscribeToTopic('room_$roomId');
    debugPrint('📢 Subscribed to room_$roomId');
  }

  /// Unsubscribe from a room topic
  Future<void> unsubscribeFromRoom(String roomId) async {
    await _messaging.unsubscribeFromTopic('room_$roomId');
    debugPrint('🔇 Unsubscribed from room_$roomId');
  }

  /// Send a notification to specific user(s) via their FCM tokens
  /// Note: This requires a backend/cloud function in production for security
  /// For now, we'll create helper methods to trigger cloud functions
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // In production, call a Cloud Function that sends FCM messages
    // For now, we'll prepare the data structure
    debugPrint('📤 Would send notification to $userId: $title');

    // TODO: Call Cloud Function
    // await FirebaseFunctions.instance.httpsCallable('sendNotification').call({
    //   'userId': userId,
    //   'title': title,
    //   'body': body,
    //   'data': data,
    // });
  }

  /// Send notification to all room members
  Future<void> sendNotificationToRoom({
    required String roomId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('📤 Would send notification to room $roomId: $title');

    // TODO: Call Cloud Function that sends to room topic
    // await FirebaseFunctions.instance.httpsCallable('sendRoomNotification').call({
    //   'roomId': roomId,
    //   'title': title,
    //   'body': body,
    //   'data': data,
    // });
  }

  /// Schedule a daily reminder for tasks (local notification)
  Future<void> scheduleDailyTaskReminder({
    required int hour,
    required int minute,
  }) async {
    // Cancel any existing daily reminder
    await _localNotifications.cancel(999);

    // For now, just log the intention
    // TODO: Implement proper recurring notifications with timezone package
    debugPrint('⏰ Daily reminder would be scheduled for $hour:$minute');
    debugPrint(
      '   To enable, add timezone package and implement proper scheduling',
    );
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
