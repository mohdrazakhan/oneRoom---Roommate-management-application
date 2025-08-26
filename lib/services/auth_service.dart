// File: lib/services/auth_service.dart
// Handles all Firebase Authentication logic.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInWithGoogle() async {
    try {
      // Use the package singleton to authenticate the user.
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken != null) {
        // The current google_sign_in token object only provides an idToken.
        // Pass idToken to Firebase credential; accessToken is not available here.
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );
        return userCredential.user;
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
    return null;
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
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // ignore
    }
  }
}
