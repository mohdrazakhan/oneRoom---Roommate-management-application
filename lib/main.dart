import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Initialize GoogleSignIn plugin (required by the package before use).
  try {
    await GoogleSignIn.instance.initialize();
  } catch (_) {
    // Initialization may be unnecessary or fail on some platforms; ignore here.
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Room',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
