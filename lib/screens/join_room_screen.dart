import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _id = TextEditingController();

  Future<void> _join() async {
    final id = _id.text.trim();
    if (id.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = FirebaseFirestore.instance.collection('rooms').doc(id);
    final snap = await doc.get();
    if (!snap.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Room not found')));
      return;
    }
    await doc.update({
      'members': FieldValue.arrayUnion([uid]),
    });
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Joined room')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _id,
              decoration: const InputDecoration(labelText: 'Room ID'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _join, child: const Text('Join')),
          ],
        ),
      ),
    );
  }
}
