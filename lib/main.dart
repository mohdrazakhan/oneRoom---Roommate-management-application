// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'providers/rooms_provider.dart';
import 'providers/tasks_provider.dart';
import 'services/firestore_service.dart';
import 'services/user_profile_fixer.dart';
import 'app.dart'; // contains MyApp + AuthWrapper + routes

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Fix user profiles with missing displayNames
  try {
    final fixer = UserProfileFixer();
    print('🔧 Starting automatic user profile fix...');

    // Fix current user first
    await fixer.fixCurrentUserProfile();

    // Fix all room members automatically
    await fixer.fixAllRoomMembers();

    print('✅ Automatic profile fix completed!');
  } catch (e) {
    print('⚠️ Error fixing user profiles: $e');
  }

  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoomsProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
      ],
      child: const MyApp(), // MyApp is defined in app.dart
    );
  }
}
