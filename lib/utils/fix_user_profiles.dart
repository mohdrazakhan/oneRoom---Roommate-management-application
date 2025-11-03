// Utility to fix user profiles with missing displayNames
// This should be run once to update existing users

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> fixUserProfiles() async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user logged in');
      return;
    }

    final db = FirebaseFirestore.instance;
    final userDoc = db.collection('users').doc(currentUser.uid);
    final snap = await userDoc.get();

    if (!snap.exists) {
      print('❌ User profile does not exist in Firestore');
      return;
    }

    final data = snap.data() as Map<String, dynamic>;
    final displayName = data['displayName'] as String?;

    // Check if displayName is missing or empty
    if (displayName == null || displayName.trim().isEmpty) {
      print('🔍 Found user with missing displayName: ${currentUser.uid}');

      // Try to get displayName from Firebase Auth
      String newDisplayName = currentUser.displayName ?? '';

      // If still empty, use email username
      if (newDisplayName.isEmpty && currentUser.email != null) {
        newDisplayName = currentUser.email!.split('@')[0];
      }

      // If still empty, use phone number
      if (newDisplayName.isEmpty && currentUser.phoneNumber != null) {
        newDisplayName = 'User ${currentUser.phoneNumber!.substring(0, 4)}';
      }

      // If still empty, generate a random name
      if (newDisplayName.isEmpty) {
        newDisplayName = 'User ${currentUser.uid.substring(0, 8)}';
      }

      print('✨ Updating displayName to: $newDisplayName');

      // Update Firestore
      await userDoc.update({
        'displayName': newDisplayName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth if possible
      if (currentUser.displayName == null || currentUser.displayName!.isEmpty) {
        await currentUser.updateDisplayName(newDisplayName);
      }

      print('✅ Successfully updated user profile');
    } else {
      print('✅ User profile already has displayName: $displayName');
    }
  } catch (e) {
    print('❌ Error fixing user profile: $e');
  }
}

/// Fix all users in a room
Future<void> fixRoomMembersProfiles(String roomId) async {
  try {
    final db = FirebaseFirestore.instance;
    final roomDoc = await db.collection('rooms').doc(roomId).get();

    if (!roomDoc.exists) {
      print('❌ Room not found');
      return;
    }

    final members = List<String>.from(roomDoc.data()?['members'] ?? []);
    print('🔍 Checking ${members.length} members in room $roomId');

    for (final uid in members) {
      final userDoc = db.collection('users').doc(uid);
      final snap = await userDoc.get();

      if (!snap.exists) {
        print('⚠️ User profile missing for UID: $uid - skipping');
        continue;
      }

      final data = snap.data() as Map<String, dynamic>;
      final displayName = data['displayName'] as String?;

      if (displayName == null || displayName.trim().isEmpty) {
        print('🔧 Fixing user $uid...');

        // Generate displayName from email or UID
        String newDisplayName = '';
        final email = data['email'] as String?;

        if (email != null && email.isNotEmpty) {
          newDisplayName = email.split('@')[0];
        } else {
          newDisplayName = 'User ${uid.substring(0, 8)}';
        }

        await userDoc.update({
          'displayName': newDisplayName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✅ Updated $uid to: $newDisplayName');
      } else {
        print('✅ $uid already has displayName: $displayName');
      }
    }

    print('🎉 Finished fixing room members');
  } catch (e) {
    print('❌ Error fixing room members: $e');
  }
}
