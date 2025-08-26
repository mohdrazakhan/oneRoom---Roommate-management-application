import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddExpenseScreen extends StatefulWidget {
  final String roomId;
  const AddExpenseScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _desc.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _desc.text.trim();
    final amt = double.tryParse(_amount.text.trim()) ?? 0.0;
    if (desc.isEmpty || amt <= 0) return;
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final roomRef = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId);
    final room = await roomRef.get();
    final members = List<String>.from(room.data()?['members'] ?? []);
    // simple equal split
    final payments = {
      for (var m in members) m: amt / (members.isEmpty ? 1 : members.length),
    };
    await roomRef.collection('expenses').add({
      'description': desc,
      'amount': amt,
      'currency': 'INR',
      'payerId': uid,
      'payments': payments,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Amount (INR)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
          ],
        ),
      ),
    );
  }
}
