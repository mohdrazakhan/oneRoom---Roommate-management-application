import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

class RoomsListScreen extends StatelessWidget {
  const RoomsListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'createRoom',
            icon: const Icon(Icons.add),
            label: const Text('Create Room'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'joinRoom',
            icon: const Icon(Icons.group_add),
            label: const Text('Join Room'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinRoomScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .where('members', arrayContains: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No rooms yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final name = data['name'] ?? 'Room';
              final members = List<String>.from(data['members'] ?? []);
              return ListTile(
                title: Text(name),
                subtitle: Text('Members: ${members.length}'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(name)),
                      body: Center(child: Text('Room: $name')),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
