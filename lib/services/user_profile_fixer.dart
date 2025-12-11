// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to fix user profiles with missing displayNames
class UserProfileFixer {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fix the current user's profile if displayName is missing
  Future<void> fixCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping profile fix');
        return;
      }

      final userDoc = _db.collection('users').doc(user.uid);
      final snap = await userDoc.get();

      if (!snap.exists) {
        print('⚠️ User profile does not exist in Firestore');
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      final currentDisplayName = data['displayName'] as String?;

      // Check if displayName is missing or empty
      if (currentDisplayName == null || currentDisplayName.trim().isEmpty) {
        print('🔧 Fixing profile for user ${user.uid}');

        String newDisplayName = _generateDisplayName(user, data);

        print('✅ Updating displayName to: $newDisplayName');

        await userDoc.update({
          'displayName': newDisplayName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Also update Firebase Auth if needed
        if (user.displayName == null || user.displayName!.isEmpty) {
          await user.updateDisplayName(newDisplayName);
          await user.reload();
        }

        print('✅ Profile fixed successfully!');
      } else {
        print('✅ Profile already has displayName: $currentDisplayName');
      }
    } catch (e) {
      print('❌ Error fixing user profile: $e');
    }
  }

  /// Generate a displayName from available user data
  String _generateDisplayName(User user, Map<String, dynamic> firestoreData) {
    // Try Firebase Auth displayName first
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    // Try email username
    if (user.email != null && user.email!.isNotEmpty) {
      final emailUsername = user.email!.split('@')[0];
      if (emailUsername.isNotEmpty) {
        // Capitalize first letter
        return _capitalize(emailUsername);
      }
    }

    // Try phone number
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return 'User ${user.phoneNumber!.substring(0, 4)}';
    }

    // Check Firestore for email
    final firestoreEmail = firestoreData['email'] as String?;
    if (firestoreEmail != null && firestoreEmail.isNotEmpty) {
      final emailUsername = firestoreEmail.split('@')[0];
      return _capitalize(emailUsername);
    }

    // Last resort: use UID
    return 'User ${user.uid.substring(0, 8)}';
  }

  /// Capitalize first letter of a string
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Fix all users in a specific room
  Future<void> fixRoomMembersProfiles(String roomId) async {
    try {
      final roomDoc = await _db.collection('rooms').doc(roomId).get();

      if (!roomDoc.exists) {
        print('❌ Room not found: $roomId');
        return;
      }

      final members = List<String>.from(roomDoc.data()?['members'] ?? []);
      print('🔍 Fixing ${members.length} members in room $roomId');

      int fixed = 0;
      int alreadyOk = 0;

      for (final uid in members) {
        final userDoc = _db.collection('users').doc(uid);
        final snap = await userDoc.get();

        if (!snap.exists) {
          print('⚠️ User profile missing for UID: $uid - creating one');

          // Create a basic profile
          await userDoc.set({
            'displayName': 'User ${uid.substring(0, 8)}',
            'email': '',
            'photoUrl': null,
            'phoneNumber': null,
            'joinedRooms': [roomId],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          fixed++;
          continue;
        }

        final data = snap.data() as Map<String, dynamic>;
        final displayName = data['displayName'] as String?;

        if (displayName == null || displayName.trim().isEmpty) {
          print('🔧 Fixing user $uid...');

          String newDisplayName = '';
          final email = data['email'] as String?;

          if (email != null && email.isNotEmpty) {
            newDisplayName = _capitalize(email.split('@')[0]);
          } else {
            newDisplayName = 'User ${uid.substring(0, 8)}';
          }

          await userDoc.update({
            'displayName': newDisplayName,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Updated $uid to: $newDisplayName');
          fixed++;
        } else {
          print('✅ $uid already has displayName: $displayName');
          alreadyOk++;
        }
      }

      print('🎉 Room complete! Fixed: $fixed, Already OK: $alreadyOk');
    } catch (e) {
      print('❌ Error fixing room members: $e');
    }
  }

  /// Fix all room members for all rooms the current user is in
  Future<void> fixAllRoomMembers() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping room members fix');
        return;
      }

      // Get all rooms where current user is a member
      final roomsSnapshot = await _db
          .collection('rooms')
          .where('members', arrayContains: user.uid)
          .get();

      if (roomsSnapshot.docs.isEmpty) {
        print('ℹ️ User is not in any rooms yet');
        return;
      }

      print('🔍 Found ${roomsSnapshot.docs.length} rooms to fix');

      for (final roomDoc in roomsSnapshot.docs) {
        final roomName = roomDoc.data()['name'] ?? 'Unknown Room';
        print('\n🏠 Fixing room: $roomName (${roomDoc.id})');
        await fixRoomMembersProfiles(roomDoc.id);
      }

      print('\n✅ All rooms processed!');
    } catch (e) {
      print('❌ Error fixing all room members: $e');
    }
  }
}
