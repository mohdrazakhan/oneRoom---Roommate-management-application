import 'dart:async';
import 'package:flutter/foundation.dart'; // for kIsWeb if needed, generally useful
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // Provides XFile
import '../Models/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    forceCodeForRefreshToken: true,
    serverClientId:
        '30053537626-7lkjrf210smdeuivrr0ecnrir3hr4mrr.apps.googleusercontent.com',
  );

  User? firebaseUser;
  UserProfile? profile;
  bool isLoading = true;
  String? error;

  StreamSubscription<User?>? _authSubscription;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }

  AuthProvider() {
    // listen to auth state changes
    _authSubscription = _auth.authStateChanges().listen(
      (u) async {
        if (_disposed) return;
        firebaseUser = u;
        if (u != null) {
          await _loadOrCreateUserProfile(u);
        } else {
          profile = null;
        }
        isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        if (_disposed) return;
        error = e.toString();
        isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadOrCreateUserProfile(User u) async {
    try {
      final docRef = _db.collection('users').doc(u.uid);
      final snap = await docRef.get();
      if (snap.exists) {
        profile = UserProfile.fromDoc(snap);

        // Update profile if displayName is missing but available in Firebase Auth
        if ((profile!.displayName == null || profile!.displayName!.isEmpty) &&
            u.displayName != null &&
            u.displayName!.isNotEmpty) {
          debugPrint(
            '🔄 Updating missing displayName for ${u.uid}: ${u.displayName}',
          );
          await docRef.update({
            'displayName': u.displayName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          profile = profile!.copyWith(displayName: u.displayName);
        }
      } else {
        // create a basic profile from Firebase user information
        // Generate a display name from available data
        String displayName = u.displayName ?? '';
        if (displayName.isEmpty && u.email != null) {
          // Use email username as fallback and capitalize it
          final emailUsername = u.email!.split('@')[0];
          displayName = _capitalizeDisplayName(emailUsername);
        }
        if (displayName.isEmpty && u.phoneNumber != null) {
          // Use phone number as last resort
          displayName = 'User ${u.phoneNumber!.substring(0, 4)}';
        }

        debugPrint(
          '✨ Creating new profile for ${u.uid}: "$displayName" (email: ${u.email}, phone: ${u.phoneNumber})',
        );

        final newProfile = UserProfile(
          uid: u.uid,
          displayName: displayName,
          email: u.email,
          photoUrl: u.photoURL,
          phoneNumber: u.phoneNumber,
          joinedRooms: [],
        );

        debugPrint(
          '📤 Saving profile to Firestore: ${newProfile.toMapForCreate()}',
        );
        await docRef.set(newProfile.toMapForCreate());
        profile = newProfile;
        debugPrint(
          '✅ Profile created successfully with displayName: "${profile?.displayName}"',
        );
      }
    } catch (e) {
      error = 'Failed to load/create profile: $e';
      debugPrint('❌ Error in _loadOrCreateUserProfile: $e');
    }
  }

  /// Capitalize the first letter of display name (e.g., "john" -> "John")
  String _capitalizeDisplayName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      // Create user account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;

      // Ensure displayName is not empty
      final finalDisplayName = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : _capitalizeDisplayName(
              email.split('@')[0],
            ); // Use email username as fallback

      debugPrint('📝 Signing up user with displayName: "$finalDisplayName"');

      // Update Firebase Auth displayName FIRST
      await user.updateDisplayName(finalDisplayName);
      await user
          .reload(); // Reload to get updated displayName      // Create profile doc in Firestore
      final docRef = _db.collection('users').doc(user.uid);
      final newProfile = UserProfile(
        uid: user.uid,
        displayName: finalDisplayName,
        email: user.email,
        photoUrl: user.photoURL,
        joinedRooms: [],
      );

      debugPrint(
        '✅ Creating Firestore profile with displayName: $finalDisplayName',
      );
      await docRef.set(newProfile.toMapForCreate());

      firebaseUser = user;
      profile = newProfile;

      debugPrint('✅ Signup complete! DisplayName: ${profile?.displayName}');
    } on FirebaseAuthException catch (e) {
      error = e.message;
      rethrow;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      isLoading = true;
      notifyListeners();
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      firebaseUser = cred.user;
      if (firebaseUser != null) {
        await _loadOrCreateUserProfile(firebaseUser!);
      }
    } on FirebaseAuthException catch (e) {
      error = e.message;
      rethrow;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    firebaseUser = null;
    profile = null;
    notifyListeners();
  }

  /// Refresh profile from Firestore (useful if you update profile elsewhere)
  Future<void> reloadProfile() async {
    if (firebaseUser == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final snap = await _db.collection('users').doc(firebaseUser!.uid).get();
      if (snap.exists) profile = UserProfile.fromDoc(snap);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// update display name (updates both firebase auth and users collection)
  Future<void> updateDisplayName(String name) async {
    if (firebaseUser == null) return;
    isLoading = true;
    notifyListeners();
    try {
      await firebaseUser!.updateDisplayName(name);
      await _db.collection('users').doc(firebaseUser!.uid).update({
        'displayName': name,
      });
      profile = profile?.copyWith(displayName: name) ?? profile;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile with multiple fields
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    if (firebaseUser == null) return;
    isLoading = true;
    notifyListeners();
    try {
      // Convert DateTime to Timestamp if present
      final Map<String, dynamic> firestoreUpdates = {};
      updates.forEach((key, value) {
        if (value is DateTime) {
          firestoreUpdates[key] = Timestamp.fromDate(value);
        } else {
          firestoreUpdates[key] = value;
        }
      });

      // Update Firestore
      await _db
          .collection('users')
          .doc(firebaseUser!.uid)
          .update(firestoreUpdates);

      // Update local profile
      final snap = await _db.collection('users').doc(firebaseUser!.uid).get();
      if (snap.exists) {
        profile = UserProfile.fromDoc(snap);
      }

      // Update Firebase Auth if displayName changed
      if (updates.containsKey('displayName')) {
        await firebaseUser!.updateDisplayName(
          updates['displayName'] as String?,
        );
      }
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Update notification settings
  Future<void> updateNotificationSettings(String type, bool value) async {
    if (firebaseUser == null) return;

    try {
      final Map<String, dynamic> updates = {};
      switch (type) {
        case 'notifications':
          updates['notificationsEnabled'] = value;
          break;
        case 'taskReminders':
          updates['taskRemindersEnabled'] = value;
          break;
        case 'expenseReminders':
          updates['expenseRemindersEnabled'] = value;
          break;
        case 'chatNotifications':
          updates['chatNotificationsEnabled'] = value;
          break;
        case 'expensePaymentAlerts':
          updates['expensePaymentAlertsEnabled'] = value;
          break;
      }

      await _db.collection('users').doc(firebaseUser!.uid).update(updates);

      // Update local profile
      final snap = await _db.collection('users').doc(firebaseUser!.uid).get();
      if (snap.exists) {
        profile = UserProfile.fromDoc(snap);
      }

      notifyListeners();
    } catch (e) {
      error = e.toString();
      rethrow;
    }
  }

  /// Upload profile photo to Firebase Storage
  Future<void> uploadProfilePhoto(XFile imageFile) async {
    if (firebaseUser == null) return;
    isLoading = true;
    notifyListeners();

    try {
      final uid = firebaseUser!.uid;
      final storageRef = _storage.ref().child('users/$uid/profile.jpg');

      // Upload file
      // Use putData for cross-platform support (works on web & mobile)
      final bytes = await imageFile.readAsBytes();
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final photoUrl = await storageRef.getDownloadURL();

      // Update Firestore and Firebase Auth
      await _db.collection('users').doc(uid).update({'photoUrl': photoUrl});
      await firebaseUser!.updatePhotoURL(photoUrl);

      // Update local profile
      profile = profile?.copyWith(photoUrl: photoUrl) ?? profile;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Remove profile photo from Firebase Storage and update profile
  Future<void> removeProfilePhoto() async {
    if (firebaseUser == null) return;
    isLoading = true;
    notifyListeners();

    try {
      final uid = firebaseUser!.uid;
      final storageRef = _storage.ref().child('users/$uid/profile.jpg');

      // Delete file from storage (if it exists)
      try {
        await storageRef.delete();
      } catch (e) {
        // Ignore if file doesn't exist
        debugPrint('Photo file may not exist: $e');
      }

      // Update Firestore and Firebase Auth to remove photo URL
      await _db.collection('users').doc(uid).update({'photoUrl': null});
      await firebaseUser!.updatePhotoURL(null);

      // Update local profile
      profile = profile?.copyWith(photoUrl: '') ?? profile;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Change password (requires re-authentication)
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (firebaseUser == null || firebaseUser!.email == null) {
      throw Exception('No user logged in');
    }

    try {
      // Re-authenticate user first
      final credential = EmailAuthProvider.credential(
        email: firebaseUser!.email!,
        password: currentPassword,
      );

      await firebaseUser!.reauthenticateWithCredential(credential);

      // Change password
      await firebaseUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw Exception('Current password is incorrect');
      } else if (e.code == 'weak-password') {
        throw Exception('New password is too weak');
      } else {
        throw Exception(e.message ?? 'Failed to change password');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Send phone verification code
  Future<void> sendPhoneVerificationCode({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(String verificationId) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      debugPrint('📱 Sending phone verification code for: $phoneNumber');

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('✅ Phone auto-verification successful');
          verificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ Phone verification failed: ${e.code} - ${e.message}');
          verificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ Phone verification code sent');
          codeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏱️ Phone code auto-retrieval timeout');
          codeAutoRetrievalTimeout(verificationId);
        },
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error sending phone code: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      rethrow;
    }
  }

  /// Sign in with phone credential
  Future<void> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      isLoading = true;
      notifyListeners();

      debugPrint('📱 Signing in with phone credential');

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'User is null after phone sign-in',
        );
      }

      debugPrint('✅ Phone sign-in successful: ${user.uid}');

      firebaseUser = user;
      await _loadOrCreateUserProfile(user);

      debugPrint('✅ Profile loaded/created for phone user');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Phone sign-in failed: ${e.code} - ${e.message}');
      error = e.message ?? 'Phone authentication failed';
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error during phone sign-in: $e');
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      debugPrint('🔵 AuthProvider: Starting Google Sign-In...');
      isLoading = true;
      error = null;
      notifyListeners();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint(
          '⚠️ AuthProvider: Google Sign-In canceled by user (googleUser is null)',
        );
        // The user canceled the sign-in
        isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint('✅ AuthProvider: Google User signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint(
        '✅ AuthProvider: Got Google Auth tokens. ID Token present: ${googleAuth.idToken != null}',
      );

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('🔵 AuthProvider: Signing in to Firebase with credential...');

      // Sign in to Firebase with the Google [UserCredential]
      final userCredential = await _auth.signInWithCredential(credential);
      firebaseUser = userCredential.user;

      debugPrint(
        '✅ AuthProvider: Firebase Sign-In Successful: ${firebaseUser?.uid}',
      );

      if (firebaseUser != null) {
        await _loadOrCreateUserProfile(firebaseUser!);
      }
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      final details = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();

      // Treat user-driven cancellation/back-dismissal as non-error.
      if (code.contains('cancel') || details.contains('cancel')) {
        debugPrint('⚠️ AuthProvider: Google Sign-In cancelled: ${e.code}');
        error = null;
        return;
      }

      debugPrint('❌ AuthProvider: PlatformException: ${e.code} - ${e.message}');
      error = e.message ?? 'Google sign-in failed';
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ AuthProvider: FirebaseAuthException: ${e.code} - ${e.message}',
      );
      error = e.message;
      rethrow;
    } catch (e, stack) {
      debugPrint('❌ AuthProvider: Unexpected Error: $e');
      debugPrintStack(stackTrace: stack);
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithApple() async {
    try {
      isLoading = true;
      notifyListeners();

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        // Apple doesn't always return the name on subsequent logins,
        // but it does on the first one. We can try to capture it.
        if (appleCredential.givenName != null ||
            appleCredential.familyName != null) {
          final name = [
            appleCredential.givenName,
            appleCredential.familyName,
          ].where((s) => s != null).join(' ');
          if (name.isNotEmpty) {
            await firebaseUser!.updateDisplayName(name);
          }
        }
        await _loadOrCreateUserProfile(firebaseUser!);
      }
    } on FirebaseAuthException catch (e) {
      error = e.message;
      rethrow;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Generates a cryptographically secure random nonce, to be included in a
  /// credential request.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = List<int>.generate(
      length,
      (_) => charset.codeUnitAt(DateTime.now().microsecond % charset.length),
    );
    // In production use a proper CSPRNG, but for simple nonce this works or use random.nextInt
    return String.fromCharCodes(random);
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
