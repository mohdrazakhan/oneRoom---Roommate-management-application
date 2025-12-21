// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/rooms_provider.dart';
import 'providers/tasks_provider.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'app.dart'; // contains MyApp + AuthWrapper + routes

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/// Bootstraps the app quickly, then initializes Firebase in parallel.
class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // Start background services after Firebase is ready
          _initializeBackgroundServices();
          return const RootApp();
        }

        // Lightweight splash while Firebase initializes (~instant UI)
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Color(0xFFF7F7FF),
            body: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<FirebaseApp> _initFirebase() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('⚠️ Firebase already initialized (hot restart detected)');
      return Firebase.app();
    }
    debugPrint('⚠️ Firebase initialization error: $e');
    rethrow;
  }
}

/// Initialize services that don't need to block app startup
void _initializeBackgroundServices() {
  // Initialize Firebase App Check (non-critical, can fail silently)
  FirebaseAppCheck.instance
      .activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      )
      .catchError((e) {
        debugPrint('⚠️ Firebase App Check initialization failed: $e');
      });

  // Initialize Google Mobile Ads (non-blocking)
  MobileAds.instance
      .initialize()
      .then((status) {
        debugPrint('✅ Google Mobile Ads initialized');
      })
      .catchError((e) {
        debugPrint('⚠️ Google Mobile Ads initialization failed: $e');
      });

  // Initialize notifications after a small delay
  Future.delayed(const Duration(milliseconds: 500), () {
    NotificationService().initialize();
  });
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth provider - loaded immediately (needed for auth checks)
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Firestore Service (Independent)
        Provider(create: (_) => FirestoreService()),

        // Subscription Service (Depends on FirestoreService)
        ChangeNotifierProxyProvider<FirestoreService, SubscriptionService>(
          create: (context) => SubscriptionService(
            Provider.of<FirestoreService>(context, listen: false),
          ),
          update: (context, fs, previous) =>
              previous ?? SubscriptionService(fs),
        ),

        // Rooms provider (Independent)
        ChangeNotifierProvider(create: (_) => RoomsProvider()),

        // Tasks provider
        ChangeNotifierProvider(create: (_) => TasksProvider()),
      ],
      child: const MyApp(),
    );
  }
}
