// File: lib/services/auth_service.dart
// Handles all Firebase Authentication logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<User?> signInWithGoogle() async {
    try {
      debugPrint('🔵 Starting Google Sign-In...');

      // Request sign out first to clear any cached state
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('✅ Google user signed in: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-auth-token',
          message: 'Missing Google ID or access token.',
        );
      }

      debugPrint('✅ Got Google authentication tokens');

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint(
        '✅ Firebase sign-in successful: ${userCredential.user?.email}',
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  /// Creates or updates a user profile document in Firestore under `users/{uid}`.
  Future<void> createUserProfile(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    // Sign out from Firebase and Google (if used)
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore sign-out failures from Google
    }
  }
}
