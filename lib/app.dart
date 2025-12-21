// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/rooms_provider.dart';
import 'services/navigation_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';

// Screens (adjust imports if your paths differ)
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/home/create_room_screen.dart';
import 'screens/expenses/expenses_list_screen.dart';
import 'screens/subscription/subscription_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String routeLogin = '/login';
  static const String routeSignup = '/signup';
  static const String routeDashboard = '/dashboard';
  static const String routeCreateRoom = '/create-room';
  static const String routeRoomExpenses = '/room-expenses';
  static const String routeSubscription = '/subscription';

  @override
  Widget build(BuildContext context) {
    // Modern Material 3 theme with beautiful colors
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1), // Indigo
      brightness: Brightness.light,
      primary: const Color(0xFF6366F1),
      secondary: const Color(0xFF8B5CF6),
      tertiary: const Color(0xFFEC4899),
    );

    final baseTheme = ThemeData(
      colorScheme: lightColorScheme,
      useMaterial3: true,
      fontFamily: 'SF Pro Display',

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        // Ensure icons and default foreground content are clearly visible on light backgrounds
        foregroundColor: lightColorScheme.onSurface,
        // Explicitly set title color to avoid white titles on transparent app bars
        titleTextStyle: TextStyle(
          color: lightColorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: lightColorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: lightColorScheme.onSurface),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightColorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightColorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // FloatingActionButton theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return MaterialApp(
      title: 'One-Room',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      navigatorKey: NavigationService().navigatorKey,

      // The top-level navigator uses AuthWrapper to decide initial screen based on auth state.
      home: const AuthWrapper(),

      // Named routes for convenience
      routes: {
        routeLogin: (_) => const LoginScreen(),
        routeSignup: (_) => const SignupScreen(),
        routeDashboard: (_) => const DashboardScreen(),
        routeCreateRoom: (_) => const CreateRoomScreen(),
        routeSubscription: (_) => const SubscriptionScreen(),
      },

      // onGenerateRoute handles routes that need arguments (e.g., room id + name)
      onGenerateRoute: (settings) {
        if (settings.name == routeRoomExpenses) {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            final roomId = args['roomId'] as String;
            final roomName = args['roomName'] as String? ?? 'Room';
            return MaterialPageRoute(
              builder: (_) =>
                  ExpensesListScreen(roomId: roomId, roomName: roomName),
            );
          }
        }

        // Handle Firebase Auth deep links (verification)
        if (settings.name != null && settings.name!.startsWith('/link')) {
          debugPrint('🔗 Handling Firebase Auth link: ${settings.name}');
          return MaterialPageRoute(
            settings:
                settings, // IMPORTANT: Pass settings so we can identify and pop this route later
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Verifying...'),
                    const SizedBox(height: 32),
                    // Fail-safe close button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Unknown route
        debugPrint('🚫 Page not found: ${settings.name}');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Page not found: ${settings.name}')),
          ),
        );
      },
    );
  }
}

/// AuthWrapper:
/// - Shows loading while auth state initializes
/// - Shows LoginScreen when not signed in
/// - Shows DashboardScreen when signed in
///
/// Also automatically starts/stops RoomsProvider listening so you don't leak listeners.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _initializedForUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final roomsProvider = Provider.of<RoomsProvider>(context, listen: false);
    final uid = auth.firebaseUser?.uid;

    // Start listening when user signs in
    if (uid != null && _initializedForUid != uid) {
      _initializedForUid = uid;

      if (!roomsProvider.isListeningTo(uid)) {
        debugPrint('🔐 AuthWrapper: Initializing listener for $uid');

        // Use SchedulerBinding to ensure this runs after the current build phase
        SchedulerBinding.instance.addPostFrameCallback((_) {
          roomsProvider.startListening(uid);

          // Initialize Subscription Service to check validity/expiry
          Provider.of<SubscriptionService>(context, listen: false).init(uid);

          // Setup notifications
          NotificationService().saveTokenForCurrentUser();
          NotificationService().initialize();
          NavigationService().processPendingNotification();
        });
      }
    } else if (uid == null && _initializedForUid != null) {
      // User signed out
      _initializedForUid = null;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        roomsProvider.stopListening();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    debugPrint(
      '🔐 AuthWrapper build: isLoading=${auth.isLoading}, user=${auth.firebaseUser?.uid}',
    );

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.firebaseUser == null) {
      return const LoginScreen();
    }

    // User is signed in, show dashboard
    return const DashboardScreen();
  }
}
