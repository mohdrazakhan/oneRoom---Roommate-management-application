import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _desc = TextEditingController();

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Prevent same user creating two rooms with the same name
    final existing = await FirebaseFirestore.instance
        .collection('rooms')
        .where('ownerId', isEqualTo: uid)
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a room with this name')),
      );
      return;
    }

    // Generate a unique 4-char alphanumeric Room ID and use it as document ID
    String generateRoomId() {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rnd = Random.secure();
      return List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    }

    String roomId = generateRoomId();
    int attempts = 0;
    while (attempts < 6) {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
      final snap = await docRef.get();
      if (!snap.exists) {
        // available
        await docRef.set({
          'roomId': roomId,
          'name': name,
          'description': _desc.text.trim(),
          'ownerId': uid,
          'members': [uid],
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Room created: $roomId')));
        return;
      }
      // collision, try again
      roomId = generateRoomId();
      attempts++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not generate unique Room ID, try again'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _create, child: const Text('Create')),
          ],
        ),
      ),
    );
  }
}
