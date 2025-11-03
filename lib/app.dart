// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/rooms_provider.dart';

// Screens (adjust imports if your paths differ)
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/home/create_room_screen.dart';
import 'screens/expenses/expenses_list_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String routeLogin = '/login';
  static const String routeSignup = '/signup';
  static const String routeDashboard = '/dashboard';
  static const String routeCreateRoom = '/create-room';
  static const String routeRoomExpenses = '/room-expenses';

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
      title: 'Roommate Manager',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,

      // The top-level navigator uses AuthWrapper to decide initial screen based on auth state.
      home: const AuthWrapper(),

      // Named routes for convenience
      routes: {
        routeLogin: (_) => const LoginScreen(),
        routeSignup: (_) => const SignupScreen(),
        routeDashboard: (_) => const DashboardScreen(),
        routeCreateRoom: (_) => const CreateRoomScreen(),
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

        // Unknown route
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
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
  VoidCallback? _authListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Remove previous listener if any
    _authListener?.call();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomsProvider = Provider.of<RoomsProvider>(context, listen: false);

    // Start/stop listening immediately based on current auth state
    if (!authProvider.isLoading && authProvider.firebaseUser != null) {
      roomsProvider.startListening(authProvider.firebaseUser!.uid);
    } else {
      roomsProvider.stopListening();
    }

    // Set up a listener so we react to future auth changes
    _authListener = () {
      // no-op wrapper for removal convenience
    };

    // Instead of storing VoidCallback returned by addListener (not returned),
    // we directly add a listener and keep a flag to remove it on dispose.
    authProvider.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final roomsProvider = Provider.of<RoomsProvider>(context, listen: false);

    if (authProvider.firebaseUser != null) {
      // start listening to rooms for this user
      roomsProvider.startListening(authProvider.firebaseUser!.uid);
    } else {
      // stop listening when signed out
      roomsProvider.stopListening();
    }

    // Trigger rebuild to show the right screen if needed
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Remove the listener we added to AuthProvider
    try {
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.firebaseUser == null) {
      // Not signed in -> show login screen
      return const LoginScreen();
    }

    // Signed in -> show dashboard
    return const DashboardScreen();
  }
}
