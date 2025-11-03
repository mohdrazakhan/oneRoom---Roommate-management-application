import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'providers/rooms_provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final roomsProvider = Provider.of<RoomsProvider>(context, listen: false);

        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            // Start rooms listener for this user (startListening is idempotent for same uid).
            roomsProvider.startListening(user.uid);
            return const DashboardScreen();
          } else {
            // Stop rooms listener when signed out to avoid leaked subscriptions.
            roomsProvider.stopListening();
            return const LoginScreen();
          }
        }

        // Still initializing auth state.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
