// lib/constants.dart
import 'package:flutter/material.dart';

/// App-wide color palette
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF3F51B5); // indigo
  static const Color primaryVariant = Color(0xFF303F9F);
  static const Color accent = Color(0xFFFFC107); // amber
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2E7D32);
  static const Color danger = Color(0xFFD32F2F);
  static const Color muted = Color(0xFF9E9E9E);
  static const Color text = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
}

/// App routes (use these strings to avoid typos)
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String createRoom = '/create-room';
  static const String roomExpenses = '/room-expenses';
  static const String profile = '/profile';
}

/// Common static strings
class AppStrings {
  AppStrings._();

  static const String appName = 'Roommate Manager';
  static const String currencySymbol = '₹'; // change as needed
}

/// Spacing constants for consistent layouts
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

/// Rounded radii
class AppRadius {
  AppRadius._();

  static const double sm = 6.0;
  static const double md = 12.0;
  static const double lg = 20.0;
}

/// Common shadows
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3)),
  ];
}

/// Reusable text styles
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}

/// A ThemeData helper you can use from `main.dart` / `app.dart`.
ThemeData appTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(secondary: AppColors.accent, surface: AppColors.surface);

  final base = ThemeData.from(colorScheme: colorScheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.muted.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      hintStyle: AppTextStyles.caption,
    ),
    textTheme: base.textTheme.copyWith(
      headlineSmall: AppTextStyles.heading1,
      titleMedium: AppTextStyles.heading2,
      bodyMedium: AppTextStyles.body,
      bodyLarge: AppTextStyles.bodyBold,
    ),
    iconTheme: const IconThemeData(color: AppColors.primary),
  );
}
