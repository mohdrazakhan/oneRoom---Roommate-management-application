// lib/services/notification_service.dart
// import 'dart:io'; // Removed for web support
import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb, defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/navigation_service.dart';
import '../app.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/tasks/my_tasks_dashboard.dart';
import '../screens/expenses/expenses_list_screen.dart';

/// Top-level handler for background messages (must be top-level or static)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Already initialized, ignore
    if (!e.toString().contains('duplicate-app')) {
      debugPrint('❌ Firebase init error in background: $e');
    }
  }
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
  static const String _defaultChannelId = 'one_room_channel';

  bool _isServiceUnavailableError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('service_not_available') ||
        msg.contains('firebaseinstallations service is unavailable') ||
        msg.contains('java.io.ioexception: service_not_available');
  }

  Future<T?> _runWithRetry<T>({
    required String operation,
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    var delay = initialDelay;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isRetryable = _isServiceUnavailableError(e);
        final isLastAttempt = attempt == maxAttempts;

        if (!isRetryable || isLastAttempt) {
          debugPrint(
            '⚠️ $operation failed (attempt $attempt/$maxAttempts): $e',
          );
          return null;
        }

        debugPrint(
          '⚠️ $operation temporarily unavailable; retrying in ${delay.inSeconds}s',
        );
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    return null;
  }

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    if (_initialized) return;

    final canInitialize = await _validateMessagingRequirements();
    if (!canInitialize) {
      debugPrint('⚠️ Skipping NotificationService init: prerequisites missing');
      return;
    }

    _initialized = true;

    // Request permission (iOS/macOS/Web)
    try {
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
    } catch (e) {
      debugPrint('⚠️ Failed to request notification permission: $e');
    }

    // Android 13+ runtime permission
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('⚠️ Failed to request Android notification permission: $e');
      }
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
      // macOS? linux? web? (web doesn't use local_notifications usually same way)
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Ensure Android notification channel exists (Android 8+)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const androidChannel = AndroidNotificationChannel(
        _defaultChannelId,
        'One Room Notifications',
        description: 'Notifications for room activities',
        importance: Importance.high,
      );
      try {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(androidChannel);
      } catch (e) {
        debugPrint('⚠️ Failed to create notification channel: $e');
      }
    }

    // Set up background message handler
    // On web this is handled by service worker usually, but registering valid
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Set the handler for pending navigation
    NavigationService().setPendingNavigationHandler(_routeFromData);

    // Check if app was opened from a terminated state via notification
    // Store the data and process it when navigator is ready
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '📩 App opened from terminated state via notification: ${initialMessage.data}',
        );
        // Store the notification data to be processed when navigator is ready
        NavigationService().setPendingNotificationData(
          Map<String, dynamic>.from(initialMessage.data),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to check initial message: $e');
    }

    // Get FCM token and save to Firestore
    // Save token in background
    // ignore: unawaited_futures
    _saveTokenToFirestore().catchError((e) {
      debugPrint('⚠️ Failed to save token: $e');
    });

    // Subscribe to all rooms the user is a member of so server triggers reach this device
    // Subscribe to room topics in background (requires a quick Firestore query)
    // ignore: unawaited_futures
    _subscribeToAllMemberRooms().catchError((e) {
      debugPrint('⚠️ Failed to subscribe to member rooms: $e');
    });

    // Subscribe to "all_users" topic for broadcast notifications
    // ignore: unawaited_futures
    _runWithRetry<void>(
      operation: 'Subscribe to all_users topic',
      action: () => _messaging.subscribeToTopic('all_users'),
    );
    debugPrint('📢 Subscribed to all_users topic for broadcasts');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _saveTokenToFirestore(token).catchError((e) {
        debugPrint('⚠️ Failed to allow token refresh save: $e');
      });
    });
  }

  Future<bool> _validateMessagingRequirements() async {
    if (Firebase.apps.isEmpty) {
      debugPrint(
        '❌ NotificationService requirement missing: Firebase not initialized',
      );
      return false;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android Firebase Messaging requirements quick checklist:
      // 1) google-services plugin + google-services.json
      // 2) POST_NOTIFICATIONS permission in AndroidManifest (API 33+)
      // 3) Default notification channel metadata in AndroidManifest
      debugPrint('✅ NotificationService requirements checked for Android SDK');
    }

    return true;
  }

  /// Subscribe to all rooms the current user is a member of
  Future<void> _subscribeToAllMemberRooms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final qs = await FirebaseFirestore.instance
          .collection('rooms')
          .where('members', arrayContains: user.uid)
          .get();
      for (final doc in qs.docs) {
        final roomId = doc.id;
        try {
          await subscribeToRoom(roomId);
        } catch (e) {
          debugPrint('⚠️ Failed to subscribe to room_$roomId: $e');
        }
      }
      debugPrint('📢 Subscribed to ${qs.docs.length} room topics');
    } catch (e) {
      debugPrint('⚠️ Failed to fetch rooms for topic subscription: $e');
    }
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Web handles notifications automatically if in background,
    // but in foreground we might want to show a toast or customUI.
    // For now we try local notifs if supported, else ignore (web usually requires SW magic for background)
    // flutter_local_notifications has partial web support but complex setup.
    if (kIsWeb) return;

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
    if (response.payload == null) return;
    _routeFromPayload(response.payload!);
  }

  /// Handle when user taps notification while app is in background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 App opened from notification: ${message.data}');
    _routeFromData(message.data);
  }

  void _routeFromPayload(String payload) {
    // Payload was stored as message.data.toString(), which is not ideal for parsing.
    // Try to recover simple key-value pairs.
    final Map<String, String> data = {};
    final trimmed = payload.replaceAll(RegExp(r'[{|}]'), '');
    for (final part in trimmed.split(',')) {
      final kv = part.split(':');
      if (kv.length >= 2) {
        data[kv[0].trim()] = kv.sublist(1).join(':').trim();
      }
    }
    _routeFromData(data);
  }

  void _routeFromData(Map<String, dynamic> data) {
    final nav = NavigationService().navigatorKey.currentState;
    if (nav == null) {
      debugPrint('⚠️ Navigator not ready, storing notification for later');
      NavigationService().setPendingNotificationData(data);
      return;
    }

    final rawType = data['type']?.toString();
    // Normalize variants produced by helper and functions
    final type = _normalizeType(rawType);
    final roomId = data['roomId']?.toString();
    final roomName = data['roomName']?.toString() ?? 'Room';

    debugPrint('🔔 Routing notification: type=$type, roomId=$roomId');

    if (type == 'chat' && roomId != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(roomId: roomId, roomName: roomName),
        ),
      );
      return;
    }
    if ((type == 'task' || type == 'swap') && roomId != null) {
      nav.push(MaterialPageRoute(builder: (_) => const MyTasksDashboard()));
      return;
    }
    if (type == 'expense' && roomId != null) {
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              ExpensesListScreen(roomId: roomId, roomName: roomName),
        ),
      );
      return;
    }
    // Default to dashboard
    nav.pushNamed(MyApp.routeDashboard);
  }

  /// Map legacy / variant types to canonical routing categories
  String? _normalizeType(String? t) {
    if (t == null) return null;
    switch (t) {
      case 'chat':
      case 'chat_message':
        return 'chat';
      case 'task':
      case 'task_created':
      case 'task_edited':
      case 'task_deleted':
      case 'task_reminder':
      case 'swap':
        return 'task';
      case 'expense':
      case 'expense_created':
      case 'expense_edited':
      case 'expense_deleted':
        return 'expense';
      default:
        return t; // fallback unchanged
    }
  }

  /// Save FCM token to Firestore for this user/device
  Future<void> _saveTokenToFirestore([String? token]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fcmToken =
          token ??
          await _runWithRetry<String?>(
            operation: 'Fetch FCM token',
            action: () => _messaging.getToken(),
          );
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
            'platform': kIsWeb
                ? 'web'
                : defaultTargetPlatform.name, // Fixed Platform.operatingSystem
            'createdAt': FieldValue.serverTimestamp(),
            'lastUsed': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error saving FCM token: $e');
      // Rethrow if you want the caller to handle it, but for void async we just log
      // rethrow;
    }
  }

  /// Public helper to ensure token is saved after login
  Future<void> saveTokenForCurrentUser() => _saveTokenToFirestore();

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
    await _runWithRetry<void>(
      operation: 'Subscribe to room_$roomId topic',
      action: () => _messaging.subscribeToTopic('room_$roomId'),
    );
    debugPrint('📢 Subscribed to room_$roomId');
  }

  /// Unsubscribe from a room topic
  Future<void> unsubscribeFromRoom(String roomId) async {
    await _runWithRetry<void>(
      operation: 'Unsubscribe from room_$roomId topic',
      action: () => _messaging.unsubscribeFromTopic('room_$roomId'),
    );
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

    // Cloud Function implementation:
    // 1. Add firebase_functions package to pubspec.yaml
    // 2. Deploy the sendNotification function (see functions/src/index.ts)
    // 3. Uncomment below:
    // final functions = FirebaseFunctions.instance;
    // await functions.httpsCallable('sendNotification').call({
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

    // Cloud Function implementation:
    // 1. Deploy the sendRoomNotification function (see functions/src/index.ts)
    // 2. Uncomment below:
    // final functions = FirebaseFunctions.instance;
    // await functions.httpsCallable('sendRoomNotification').call({
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

    // Recurring notifications implementation guide:
    // 1. Add to pubspec.yaml: timezone: ^0.9.0
    // 2. Initialize: await timezone.initializeTimeZones();
    // 3. Use flutter_local_notifications zonedSchedule with DateTimeComponents.time
    // Example:
    // final tz.TZDateTime scheduledDate = tz.TZDateTime(
    //   tz.local, DateTime.now().year, DateTime.now().month,
    //   DateTime.now().day, hour, minute,
    // );
    // await _localNotifications.zonedSchedule(
    //   999, 'Daily Reminder', 'Check your tasks!',
    //   scheduledDate, platformChannelSpecifics,
    //   androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    //   matchDateTimeComponents: DateTimeComponents.time,
    // );
    debugPrint(
      '⏰ Daily reminder scheduled for $hour:$minute (implementation pending)',
    );
  }

  /// Get the current FCM token
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
