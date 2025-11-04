import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class RecordPaymentScreen extends StatefulWidget {
  final String roomId;

  const RecordPaymentScreen({super.key, required this.roomId});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _firestoreService = FirestoreService();

  String? _payerId;
  String? _receiverId;
  Map<String, dynamic>? _roomData;
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomData() async {
    try {
      final roomData = await _firestoreService.getRoomById(widget.roomId);
      if (roomData != null) {
        final members = List<String>.from(roomData['members'] ?? []);
        final profiles = await _firestoreService.getUsersProfiles(members);

        if (mounted) {
          setState(() {
            _roomData = roomData;
            _memberProfiles = profiles;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading room data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMemberDisplayName(String uid) {
    final profile = _memberProfiles[uid];
    if (profile == null) return 'Member';

    if (profile['displayName'] != null &&
        profile['displayName'].toString().isNotEmpty) {
      return profile['displayName'];
    }

    if (profile['email'] != null && profile['email'].toString().isNotEmpty) {
      return profile['email'].split('@')[0];
    }

    return 'Member ${uid.substring(0, 4)}';
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_payerId == null || _receiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both payer and receiver'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_payerId == _receiverId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payer and receiver cannot be the same person'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not logged in');

      await _firestoreService.addPayment(
        roomId: widget.roomId,
        payerId: _payerId!,
        receiverId: _receiverId!,
        amount: double.parse(_amountController.text),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdBy: currentUserId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Payment')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_roomData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Payment')),
        body: const Center(child: Text('Room not found')),
      );
    }

    final members = List<String>.from(_roomData!['members'] ?? []);

    if (members.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Payment')),
        body: const Center(
          child: Text('Need at least 2 members to record a payment'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Record cash payments between members to settle balances',
                        style: TextStyle(color: Colors.blue[900], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payer Section
              Text(
                'Who Paid?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonFormField<String>(
                  value: _payerId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  hint: const Text('Select payer'),
                  isExpanded: true,
                  items: members.map((uid) {
                    return DropdownMenuItem(
                      value: uid,
                      child: Text(_getMemberDisplayName(uid)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _payerId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Please select who paid';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Arrow Indicator
              Center(
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Receiver Section
              Text(
                'Who Received?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButtonFormField<String>(
                  value: _receiverId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  hint: const Text('Select receiver'),
                  isExpanded: true,
                  items: members.map((uid) {
                    return DropdownMenuItem(
                      value: uid,
                      child: Text(_getMemberDisplayName(uid)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _receiverId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Please select who received';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Amount Section
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee),
                  hintText: 'Enter amount',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Note Section (Optional)
              Text(
                'Note (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.note_outlined),
                  hintText: 'Add a note (e.g., "Cash settlement for October")',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Record Payment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
