import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firestore_service.dart';
import '../../widgets/primary_button.dart';
import '../../utils/validators.dart';
import '../../utils/formatters.dart';
import '../../constants.dart';
import '../../Models/expense.dart';

class AddExpenseScreen extends StatefulWidget {
  final String roomId;

  const AddExpenseScreen({super.key, required this.roomId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  bool _saving = false;
  bool _loadingMembers = true;

  // Room members and profiles
  List<String> _members = [];
  Map<String, Map<String, dynamic>> _profiles = {};

  // Selections
  String? _paidByUid;
  Set<String> _selectedPayers = {}; // users to split among
  String _category = 'Other';
  DateTime? _selectedDate; // null => use serverTimestamp

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final fs = FirestoreService();
      final room = await fs.getRoomById(widget.roomId);
      final members = List<String>.from(room?['members'] ?? <String>[user.uid]);

      // Try to load profiles; if permission denied, proceed with empty profiles
      Map<String, Map<String, dynamic>> profiles = {};
      try {
        profiles = await fs.getUsersProfiles(members);
      } catch (profileError) {
        // Firestore rules may deny access to users collection; continue with empty
        debugPrint('Could not load profiles: $profileError');
      }

      // Fallback: add current user's name from Firebase Auth if profile missing
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        profiles.putIfAbsent(
          user.uid,
          () => {'displayName': user.displayName, 'email': user.email},
        );
      }

      setState(() {
        _members = members;
        _profiles = profiles;
        _paidByUid = user.uid;
        _selectedPayers = members.toSet(); // default: split among all
        _loadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load room: $e')));
      setState(() => _loadingMembers = false);
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _pickName(String uid) {
    final p = _profiles[uid];
    String? n =
        p?['displayName'] ??
        p?['name'] ??
        p?['fullName'] ??
        p?['username'] ??
        p?['email'];
    if (n == null || n.trim().isEmpty) {
      return _shortUid(uid);
    }
    return n;
  }

  String _shortUid(String uid) {
    if (uid.length <= 6) return uid;
    return '${uid.substring(0, 3)}…${uid.substring(uid.length - 3)}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1);
    final last = DateTime(now.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      // keep time as noon to avoid TZ surprises; only date matters here
      setState(
        () =>
            _selectedDate = DateTime(picked.year, picked.month, picked.day, 12),
      );
    }
  }

  Future<void> _addNewTag() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New tag'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Enter tag name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _category = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByUid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select who paid')));
      return;
    }
    if (_selectedPayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick at least one member to split among'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final total = double.parse(_amountCtrl.text.trim());
      final participants = _selectedPayers.toList();
      final perHead = participants.isEmpty ? 0.0 : total / participants.length;
      final splits = {for (final uid in participants) uid: perHead};

      await FirestoreService().addExpense(
        roomId: widget.roomId,
        description: _descCtrl.text.trim(),
        amount: total,
        paidBy: _paidByUid!,
        category: _category,
        splitAmong: participants,
        splits: Map<String, double>.from(splits),
        notes: null,
        receiptUrl: null,
        createdAt: _selectedDate, // null => server timestamp
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: _loadingMembers
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: validateRequired,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Amount
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        DecimalTextInputFormatter(decimalRange: 2),
                      ],
                      validator: validateAmount,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Paid By
                    DropdownButtonFormField<String>(
                      value: _paidByUid,
                      items: _members
                          .map(
                            (uid) => DropdownMenuItem(
                              value: uid,
                              child: Text(_pickName(uid)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _paidByUid = v),
                      decoration: const InputDecoration(labelText: 'Paid by'),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Split among
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Split among',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _selectedPayers = _members.toSet(),
                          ),
                          child: const Text('Select all'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _members
                          .map(
                            (uid) => FilterChip(
                              label: Text(_pickName(uid)),
                              selected: _selectedPayers.contains(uid),
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedPayers.add(uid);
                                  } else {
                                    _selectedPayers.remove(uid);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Date'),
                      subtitle: Text(
                        _selectedDate == null
                            ? 'Today (auto)'
                            : Formatters.formatDate(_selectedDate!),
                      ),
                      trailing: TextButton(
                        onPressed: _pickDate,
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Tags / category
                    const Text(
                      'Tag',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...ExpenseCategory.categories.map(
                          (cat) => ChoiceChip(
                            label: Text(cat.name),
                            selected: _category == cat.name,
                            onSelected: (_) =>
                                setState(() => _category = cat.name),
                          ),
                        ),
                        ActionChip(
                          label: const Text('New tag'),
                          avatar: const Icon(Icons.add, size: 18),
                          onPressed: _addNewTag,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    PrimaryButton(
                      label: 'Add',
                      onPressed: _save,
                      loading: _saving,
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
