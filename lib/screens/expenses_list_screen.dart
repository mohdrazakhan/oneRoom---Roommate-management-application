import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpensesListScreen extends StatelessWidget {
  final String roomId;
  final String roomName;
  const ExpensesListScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('rooms').doc(roomId);
    return Scaffold(
      appBar: AppBar(title: Text('Expenses — $roomName')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: roomRef
            .collection('expenses')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No expenses yet'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final amt = (d['amount'] as num?)?.toDouble() ?? 0.0;
              final desc = d['description'] ?? '';
              final payer = d['payerId'] ?? '';
              return ListTile(
                title: Text(desc),
                subtitle: Text('Paid by: $payer'),
                trailing: Text('₹${amt.toStringAsFixed(2)}'),
              );
            },
          );
        },
      ),
    );
  }
}
