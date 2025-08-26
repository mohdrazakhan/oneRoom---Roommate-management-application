// File: lib/screens/dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'create_room_screen.dart';
import 'add_expense_screen.dart';
import 'expenses_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _auth = AuthService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _openCreateRoom() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateRoomScreen()));
    if (!mounted) return;
    setState(() {});
  }

  void _openAddExpense(String roomId) async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddExpenseScreen(roomId: roomId)),
    );
    if (!mounted) return;
    if (res == true)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Expense added')));
  }

  void _openExpensesList(String roomId, String roomName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpensesListScreen(roomId: roomId, roomName: roomName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Room Balance',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\u20b90.00',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Rooms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Not signed in'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('rooms')
                          .where('members', arrayContains: uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError)
                          return Center(child: Text('Error: ${snap.error}'));
                        if (!snap.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final docs = snap.data!.docs;
                        if (docs.isEmpty)
                          return const Center(
                            child: Text('You have no rooms yet.'),
                          );
                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = docs[i];
                            final data = d.data();
                            final name = data['name'] ?? 'Room';
                            final members = List<String>.from(
                              data['members'] ?? [],
                            );
                            final roomId = data['roomId'] ?? d.id;
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(
                                'Members: ${members.length} • ID: $roomId',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'add')
                                    _openAddExpense(roomId);
                                  else if (v == 'view')
                                    _openExpensesList(roomId, name);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'add',
                                    child: Text('Add Expense'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'view',
                                    child: Text('View Expenses'),
                                  ),
                                ],
                              ),
                              onTap: () => _openExpensesList(roomId, name),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateRoom,
        child: const Icon(Icons.add),
      ),
    );
  }
}
