import 'package:flutter/material.dart';

/// Global navigation service so we can navigate from background/foreground
/// notification handlers without BuildContext.
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState? get _nav => navigatorKey.currentState;

  Future<T?>? push<T>(Route<T> route) => _nav?.push(route);
  Future<T?>? pushAndRemoveUntil<T>(Route<T> route) =>
      _nav?.pushAndRemoveUntil(route, (r) => false);
}
