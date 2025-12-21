import 'dart:async';
import 'package:flutter/material.dart';

/// Global navigation service so we can navigate from background/foreground
/// notification handlers without BuildContext.
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Pending navigation data to process when navigator is ready
  Map<String, dynamic>? _pendingNotificationData;

  /// Callback to handle pending navigation
  void Function(Map<String, dynamic>)? _pendingNavigationHandler;

  NavigatorState? get _nav => navigatorKey.currentState;

  /// Check if navigator is ready
  bool get isNavigatorReady => _nav != null;

  Future<T?>? push<T>(Route<T> route) => _nav?.push(route);
  Future<T?>? pushAndRemoveUntil<T>(Route<T> route) =>
      _nav?.pushAndRemoveUntil(route, (r) => false);

  /// Store pending notification data to process when app is ready
  void setPendingNotificationData(Map<String, dynamic> data) {
    _pendingNotificationData = data;
    debugPrint('📌 Stored pending notification data: $data');
  }

  /// Set the handler for pending navigation
  void setPendingNavigationHandler(
    void Function(Map<String, dynamic>) handler,
  ) {
    _pendingNavigationHandler = handler;
  }

  /// Process any pending notification navigation
  /// Call this after the navigator is ready (e.g., after first frame)
  Future<void> processPendingNotification() async {
    if (_pendingNotificationData != null && _pendingNavigationHandler != null) {
      // Wait a bit for the app to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Ensure navigator is ready
      if (_nav != null) {
        debugPrint(
          '🚀 Processing pending notification: $_pendingNotificationData',
        );
        _pendingNavigationHandler!(_pendingNotificationData!);
        _pendingNotificationData = null;
      } else {
        debugPrint('⚠️ Navigator still not ready, retrying...');
        // Retry after another delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (_nav != null && _pendingNotificationData != null) {
          _pendingNavigationHandler!(_pendingNotificationData!);
          _pendingNotificationData = null;
        }
      }
    }
  }

  /// Check if there's pending notification data
  bool get hasPendingNotification => _pendingNotificationData != null;
}
