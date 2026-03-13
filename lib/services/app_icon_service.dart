import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class AppIconService {
  static const String _iconConfigKey = 'app_icon';

  bool _isTransientRemoteConfigError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('internal remote config fetch error') ||
        msg.contains('service_not_available') ||
        msg.contains('firebaseinstallations service is unavailable');
  }

  /// Initialize Remote Config and check for icon updates
  Future<void> initializeAndCheck() async {
    debugPrint('🎨 AppIconService: Starting initialization...');
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await remoteConfig.setDefaults({_iconConfigKey: 'default'});
      debugPrint('🎨 AppIconService: Defaults set');

      // Fetch and activate
      // For testing: use 0 seconds to fetch immediately every time
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      debugPrint('🎨 AppIconService: Settings configured');

      final result = await remoteConfig.fetchAndActivate();
      debugPrint('🎨 AppIconService: Fetch result = $result');

      final targetIcon = remoteConfig.getString(_iconConfigKey);
      debugPrint('🎨 AppIconService: Target icon = "$targetIcon"');

      await _updateIcon(targetIcon);
    } catch (e) {
      if (_isTransientRemoteConfigError(e)) {
        debugPrint(
          '⚠️ AppIconService: Remote Config temporarily unavailable; skipping icon update this launch',
        );
      } else {
        debugPrint('❌ AppIconService Error: $e');
      }
    }
  }

  Future<void> _updateIcon(String targetIcon) async {
    try {
      if (!await FlutterDynamicIconPlus.supportsAlternateIcons) {
        debugPrint('Dynamic icons not supported');
        return;
      }

      final currentIcon = await FlutterDynamicIconPlus.alternateIconName;

      // Normalize 'default' to null for comparison/setting
      final String? effectiveTarget =
          (targetIcon == 'default' || targetIcon.isEmpty) ? null : targetIcon;

      if (currentIcon != effectiveTarget) {
        debugPrint('Updating app icon from $currentIcon to $effectiveTarget');
        await FlutterDynamicIconPlus.setAlternateIconName(
          iconName: effectiveTarget,
        );
        debugPrint('App icon updated successfully');
      } else {
        debugPrint('App icon is already up to date');
      }
    } catch (e) {
      debugPrint('Error updating app icon: $e');
    }
  }
}
