import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  static final DeepLinkService _instance = DeepLinkService._internal();

  factory DeepLinkService() => _instance;

  DeepLinkService._internal();

  /// Initialize and listen for deep links
  Future<void> initialize(BuildContext context) async {
    final navigator = Navigator.of(context);
    try {
      // Check initial link (cold start - app was closed)
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(navigator, initialUri);
      }

      // Listen for links while app is running (warm start)
      _appLinks.uriLinkStream.listen(
        (Uri uri) {
          _handleDeepLink(navigator, uri);
        },
        onError: (err) {
          debugPrint('Deep link error: $err');
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize deep links: $e');
    }
  }

  /// Handle incoming deep link
  void _handleDeepLink(NavigatorState navigator, Uri uri) {
    debugPrint('Deep link received: $uri');

    // Extract room ID from URL
    // Example URLs:
    // - https://oneroom.living/join/ABC123
    // - oneroom://join/ABC123

    if (uri.pathSegments.isNotEmpty) {
      final firstSegment = uri.pathSegments.first;

      if (firstSegment == 'join' && uri.pathSegments.length > 1) {
        final roomId = uri.pathSegments[1];
        debugPrint('Navigating to join room with ID: $roomId');

        // Navigate to join room screen with room ID
        navigator.pushNamed('/join-room', arguments: {'roomId': roomId});
      }
    }
  }

  /// Create shareable deep link for room invitation
  String createRoomInviteLink(String roomId) {
    return 'https://oneroom.living/join/$roomId';
  }

  /// Create custom scheme link (fallback)
  String createCustomSchemeLink(String roomId) {
    return 'oneroom://join/$roomId';
  }
}
