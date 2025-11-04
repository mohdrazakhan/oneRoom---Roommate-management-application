// lib/screens/expenses/enhanced_modern_expense_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// image picking removed from this screen; import removed
import 'package:provider/provider.dart';
// removed unused import 'intl'
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Models/expense.dart';
import '../../providers/rooms_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

class EnhancedModernExpenseScreen extends StatefulWidget {
  final String roomId;
  final Expense? expense; // null => create, non-null => edit

  const EnhancedModernExpenseScreen({
    super.key,
    required this.roomId,
    this.expense,
  });

  @override
  State<EnhancedModernExpenseScreen> createState() =>
      _EnhancedModernExpenseScreenState();
}

class _EnhancedModernExpenseScreenState
    extends State<EnhancedModernExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = ExpenseCategory.categories.first.name;
  String _splitType = 'equal';
  List<String> _selectedMembers = [];
  List<String> _members = [];
  Map<String, String> _memberNames = {}; // uid -> displayName

  // Multiple payers: key=uid, value=amount they paid
  final Map<String, TextEditingController> _paidBy = {};

  // Split editors controllers
  final Map<String, TextEditingController> _splitExactCtrls =
      {}; // amount per member
  final Map<String, TextEditingController> _splitPercentCtrls =
      {}; // percent per member
  final Map<String, TextEditingController> _splitSharesCtrls =
      {}; // integer shares per member
  String?
  _splitAutoUid; // for percentage/exact (last selected member gets remainder)
  String? _splitError;
  bool _splitValid = true;

  File? _receiptImage;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _loadRoomMembers();
    // Keep split preview reactive to total amount edits
    _amountCtrl.addListener(() => setState(() {}));
    if (_isEditing) {
      _prefillForm();
    }
  }

  Future<void> _loadRoomMembers() async {
    final roomsProvider = Provider.of<RoomsProvider>(context, listen: false);
    final room = roomsProvider.getRoomById(widget.roomId);
    if (room == null) return;

    setState(() => _members = room.members);

    // Load member display names
    final profiles = await FirestoreService().getUsersProfiles(room.members);
    final names = <String, String>{};
    for (var uid in room.members) {
      final profile = profiles[uid];
      if (profile != null) {
        final displayName = profile['displayName'] as String?;
        final email = profile['email'] as String?;
        names[uid] = displayName?.isNotEmpty == true
            ? displayName!
            : (email?.split('@').first ?? 'User ${uid.substring(0, 4)}');
      } else {
        names[uid] = 'User ${uid.substring(0, 4)}';
      }
    }

    if (mounted) {
      setState(() {
        _memberNames = names;
        if (!_isEditing && _members.isNotEmpty) {
          _selectedMembers = [..._members];
          _splitAutoUid = _selectedMembers.isNotEmpty
              ? _selectedMembers.last
              : null;
          _ensureSplitControllers();
        }
      });
    }
  }

  void _prefillForm() {
    final e = widget.expense!;
    _descCtrl.text = e.description;
    _amountCtrl.text = e.amount.toStringAsFixed(2);
    _notesCtrl.text = e.notes ?? '';
    _category = e.category;
    _selectedMembers = [...e.splitAmong];

    // Initialize paidBy map: use existing multi-payer data or fall back to single paidBy
    _paidBy.clear();
    if (_members.isNotEmpty) {
      final existingPayers = e
          .effectivePayers(); // uses payers map or fallback to {paidBy: amount}
      for (var uid in _members) {
        final paidAmount = existingPayers[uid] ?? 0.0;
        _paidBy[uid] = TextEditingController(
          text: paidAmount == 0.0 ? '0.00' : paidAmount.toStringAsFixed(2),
        );
      }
    }

    // Initialize split controllers for edit
    _ensureSplitControllers();
    _splitAutoUid = _selectedMembers.isNotEmpty ? _selectedMembers.last : null;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    for (var ctrl in _paidBy.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _ensureSplitControllers() {
    for (final uid in _members) {
      _splitExactCtrls.putIfAbsent(
        uid,
        () => TextEditingController(text: '0.00'),
      );
      _splitPercentCtrls.putIfAbsent(
        uid,
        () => TextEditingController(text: '0'),
      );
      _splitSharesCtrls.putIfAbsent(
        uid,
        () => TextEditingController(text: '1'),
      );
    }
  }

  // Calculate per-member split amounts based on current split type and inputs
  Map<String, double> _calcSplitAmounts() {
    final total = double.tryParse(_amountCtrl.text) ?? 0.0;
    final selected = _selectedMembers;
    final amounts = <String, double>{};
    if (selected.isEmpty || total <= 0) return amounts;

    double round2(double v) => double.parse(v.toStringAsFixed(2));

    if (_splitType == 'equal') {
      final per = total / selected.length;
      // distribute rounding diff to last member
      double running = 0;
      for (int i = 0; i < selected.length; i++) {
        final uid = selected[i];
        double value = i == selected.length - 1
            ? (total - running)
            : round2(per);
        if (i != selected.length - 1) running += value;
        amounts[uid] = round2(value);
      }
      return amounts;
    }

    if (_splitType == 'percentage') {
      // Last selected member is auto remainder to make 100%
      final auto =
          _splitAutoUid ?? (selected.isNotEmpty ? selected.last : null);
      double sumPercentOthers = 0;
      for (final uid in selected) {
        if (uid == auto) continue;
        sumPercentOthers +=
            double.tryParse(_splitPercentCtrls[uid]?.text ?? '0') ?? 0;
      }
      final remainder = (100 - sumPercentOthers).clamp(0, 100).toDouble();
      final overPercent = sumPercentOthers > 100;
      if (auto != null) {
        _splitPercentCtrls[auto]!.text = remainder.toStringAsFixed(0);
      }
      // Build amounts
      for (int i = 0; i < selected.length; i++) {
        final uid = selected[i];
        final pct = double.tryParse(_splitPercentCtrls[uid]?.text ?? '0') ?? 0;
        final raw = total * (pct / 100.0);
        if (overPercent) {
          // When invalid (>100%), avoid negative residuals; just show
          // straightforward amounts without forcing residual on last.
          amounts[uid] = round2(raw);
        } else {
          // Valid path: distribute rounding diff to last member only
          // using running sum so final sum equals total.
          // We'll compute running in a local closure scope
        }
      }
      if (!overPercent) {
        // recompute with running distribution to ensure sum==total
        amounts.clear();
        double running = 0;
        for (int i = 0; i < selected.length; i++) {
          final uid = selected[i];
          final pct =
              double.tryParse(_splitPercentCtrls[uid]?.text ?? '0') ?? 0;
          final raw = total * (pct / 100.0);
          double value = i == selected.length - 1
              ? (total - running)
              : round2(raw);
          if (i != selected.length - 1) running += value;
          amounts[uid] = round2(value);
        }
      }
      return amounts;
    }

    if (_splitType == 'exact') {
      // Last selected member is auto remainder to meet total
      final auto =
          _splitAutoUid ?? (selected.isNotEmpty ? selected.last : null);
      double sumOthers = 0;
      for (final uid in selected) {
        if (uid == auto) continue;
        sumOthers += double.tryParse(_splitExactCtrls[uid]?.text ?? '0') ?? 0;
      }
      final remainder = (total - sumOthers);
      final overExact = sumOthers > total + 0.0001;
      if (auto != null) {
        final autoCtrl = _splitExactCtrls[auto]!;
        if (overExact) {
          // Don't allow negative remainder; keep auto at 0 when invalid
          autoCtrl.text = '0.00';
        } else {
          autoCtrl.text = remainder.isFinite
              ? remainder.toStringAsFixed(2)
              : '0.00';
        }
      }
      // Build amounts: avoid negative by not forcing residual when invalid
      if (overExact) {
        for (int i = 0; i < selected.length; i++) {
          final uid = selected[i];
          final raw = double.tryParse(_splitExactCtrls[uid]?.text ?? '0') ?? 0;
          amounts[uid] = round2(raw < 0 ? 0 : raw);
        }
      } else {
        double running = 0;
        for (int i = 0; i < selected.length; i++) {
          final uid = selected[i];
          final raw = double.tryParse(_splitExactCtrls[uid]?.text ?? '0') ?? 0;
          double value = i == selected.length - 1
              ? (total - running)
              : round2(raw);
          if (i != selected.length - 1) running += value;
          amounts[uid] = round2(value);
        }
      }
      return amounts;
    }

    // shares
    int totalShares = 0;
    for (final uid in selected) {
      final s = int.tryParse(_splitSharesCtrls[uid]?.text ?? '0') ?? 0;
      totalShares += s < 0 ? 0 : s;
    }
    if (totalShares <= 0) {
      return amounts; // invalid, handled in validation
    }
    double running = 0;
    for (int i = 0; i < selected.length; i++) {
      final uid = selected[i];
      final s = int.tryParse(_splitSharesCtrls[uid]?.text ?? '0') ?? 0;
      final raw = total * (s / totalShares);
      double value = i == selected.length - 1 ? (total - running) : round2(raw);
      if (i != selected.length - 1) running += value;
      amounts[uid] = round2(value);
    }
    return amounts;
  }

  void _validateSplit() {
    final total = double.tryParse(_amountCtrl.text) ?? 0.0;
    _splitError = null;
    _splitValid = true;
    if (_selectedMembers.isEmpty || total <= 0) {
      _splitValid = false;
      _splitError = 'Enter total amount and select members';
      return;
    }
    if (_splitType == 'percentage') {
      final auto =
          _splitAutoUid ??
          (_selectedMembers.isNotEmpty ? _selectedMembers.last : null);
      double sumOthers = 0;
      for (final uid in _selectedMembers) {
        if (uid == auto) continue;
        sumOthers += double.tryParse(_splitPercentCtrls[uid]?.text ?? '0') ?? 0;
      }
      if (sumOthers > 100) {
        _splitValid = false;
        _splitError = 'Percent total exceeds 100%';
        return;
      }
    }
    if (_splitType == 'exact') {
      final auto =
          _splitAutoUid ??
          (_selectedMembers.isNotEmpty ? _selectedMembers.last : null);
      double sumOthers = 0;
      for (final uid in _selectedMembers) {
        if (uid == auto) continue;
        sumOthers += double.tryParse(_splitExactCtrls[uid]?.text ?? '0') ?? 0;
      }
      if (sumOthers > total + 0.001) {
        _splitValid = false;
        _splitError = 'Split amounts exceed total';
        return;
      }
    }

    // Final check: calculated amounts must sum to total
    final amounts = _calcSplitAmounts();
    if (amounts.isEmpty) {
      _splitValid = false;
      _splitError = 'Invalid split';
      return;
    }
    final sum = amounts.values.fold<double>(0.0, (a, b) => a + b);
    if ((sum - total).abs() > 0.01) {
      _splitValid = false;
      _splitError =
          'Split total (₹${sum.toStringAsFixed(2)}) must equal amount (₹${total.toStringAsFixed(2)})';
    }
  }

  String _paidSummary() {
    final entries = <String>[];
    double total = 0;
    for (final uid in _members) {
      final v = double.tryParse(_paidBy[uid]?.text ?? '0') ?? 0;
      if (v > 0) {
        total += v;
        entries.add(
          '${_memberNames[uid] ?? 'Member'}: ₹${v.toStringAsFixed(2)}',
        );
      }
    }
    if (entries.isEmpty) return 'Tap to select';
    final head = entries.take(2).join(', ');
    final more = entries.length > 2 ? ' +${entries.length - 2} more' : '';
    return '$head$more  •  Total ₹${total.toStringAsFixed(2)}';
  }

  Widget _buildSplitEditorCard() {
    _ensureSplitControllers();
    _splitAutoUid = _selectedMembers.isNotEmpty ? _selectedMembers.last : null;
    _validateSplit();
    final amounts = _calcSplitAmounts();

    InputDecoration dec({String? suffix}) => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      suffixText: suffix,
    );

    List<Widget> rows = [];
    for (final uid in _selectedMembers) {
      final name = _memberNames[uid] ?? 'Member';
      final isAuto =
          _splitAutoUid == uid &&
          (_splitType == 'percentage' || _splitType == 'exact');
      Widget editor;
      if (_splitType == 'percentage') {
        editor = SizedBox(
          width: 90,
          child: TextField(
            controller: _splitPercentCtrls[uid],
            enabled: !isAuto,
            readOnly: isAuto,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              // Clamp so that non-auto members never exceed the remaining 100%
              final ctrl = _splitPercentCtrls[uid]!;
              int entered = int.tryParse(value) ?? 0;
              // Sum of others excluding this uid and auto
              final auto = _splitAutoUid;
              int sumOthers = 0;
              for (final x in _selectedMembers) {
                if (x == uid || x == auto) continue;
                sumOthers +=
                    int.tryParse(_splitPercentCtrls[x]?.text ?? '0') ?? 0;
              }
              final allowed = 100 - sumOthers;
              if (entered > allowed) {
                entered = allowed.clamp(0, 100);
                final newText = entered.toString();
                ctrl.text = newText;
                ctrl.selection = TextSelection.collapsed(
                  offset: newText.length,
                );
              }
              setState(() {});
            },
            textAlign: TextAlign.center,
            decoration: dec(suffix: '%'),
          ),
        );
      } else if (_splitType == 'exact') {
        editor = SizedBox(
          width: 110,
          child: TextField(
            controller: _splitExactCtrls[uid],
            enabled: !isAuto,
            readOnly: isAuto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
            ],
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            decoration: dec(suffix: '₹'),
          ),
        );
      } else if (_splitType == 'shares') {
        editor = SizedBox(
          width: 90,
          child: TextField(
            controller: _splitSharesCtrls[uid],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.center,
            decoration: dec(suffix: 'share'),
          ),
        );
      } else {
        // equal
        editor = const SizedBox.shrink();
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isAuto)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Auto',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_splitType != 'equal') editor,
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '₹ ${amounts[uid]?.toStringAsFixed(2) ?? '0.00'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  _splitType == 'equal' ? 'Equal Split' : 'Split Details',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (!_splitValid && _splitError != null)
                  Text(
                    _splitError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_selectedMembers.isEmpty)
              const Text(
                'Select members to split',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }

  void _showMultiplePayersDialog() async {
    // Initialize stable controllers if not already done
    for (var uid in _members) {
      if (!_paidBy.containsKey(uid)) {
        _paidBy[uid] = TextEditingController(text: '0.00');
      }
    }

    // Track selected payers (order matters for auto-remainder logic)
    List<String> selectedPayers = [];
    for (var uid in _members) {
      final val = double.tryParse(_paidBy[uid]!.text) ?? 0.0;
      if (val > 0) selectedPayers.add(uid);
    }

    // Last selected payer is the "auto" one (gets remainder)
    String? autoUid = selectedPayers.isNotEmpty ? selectedPayers.last : null;

    // Helper: calculate remainder for auto payer
    void recalcAuto(StateSetter localSetState) {
      if (autoUid == null) return;
      final total = double.tryParse(_amountCtrl.text) ?? 0.0;
      double sumOthers = 0.0;
      for (var uid in _members) {
        if (uid == autoUid) continue;
        sumOthers += double.tryParse(_paidBy[uid]!.text) ?? 0.0;
      }
      final remainder = total - sumOthers;
      _paidBy[autoUid]!.text = remainder.toStringAsFixed(2);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, localSetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Who Paid?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Select members and set amounts',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Members list with checkboxes
                  Column(
                    children: _members.map((uid) {
                      final isSelected = selectedPayers.contains(uid);
                      final isAuto = autoUid == uid;
                      final displayName = _memberNames[uid] ?? 'User';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? Colors.blue : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  localSetState(() {
                                    if (checked == true) {
                                      selectedPayers.add(uid);
                                      autoUid = uid; // last selected is auto
                                      recalcAuto(localSetState);
                                    } else {
                                      selectedPayers.remove(uid);
                                      _paidBy[uid]!.text = '0.00';
                                      // Set new auto if any left
                                      autoUid = selectedPayers.isNotEmpty
                                          ? selectedPayers.last
                                          : null;
                                      recalcAuto(localSetState);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),

                              // Name
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),

                              // Amount field
                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: _paidBy[uid],
                                  enabled: isSelected && !isAuto,
                                  readOnly: isAuto,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9\.]'),
                                    ),
                                  ],
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: isAuto
                                        ? Colors.blue.withOpacity(0.1)
                                        : (isSelected
                                              ? Colors.white
                                              : Colors.grey[100]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixText: '₹ ',
                                    prefixStyle: const TextStyle(
                                      color: Colors.black87,
                                    ),
                                  ),
                                  onChanged: (_) {
                                    localSetState(
                                      () => recalcAuto(localSetState),
                                    );
                                  },
                                ),
                              ),

                              // Auto chip
                              if (isAuto) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Auto',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // DONE button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Validation: at least one selected, total equals amount
                        if (selectedPayers.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Select at least one payer'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final totalAmount =
                            double.tryParse(_amountCtrl.text) ?? 0.0;
                        double totalPaid = 0.0;
                        for (var uid in selectedPayers) {
                          totalPaid +=
                              double.tryParse(_paidBy[uid]!.text) ?? 0.0;
                        }

                        if ((totalPaid - totalAmount).abs() > 0.01) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Total paid (₹${totalPaid.toStringAsFixed(2)}) must equal total amount (₹${totalAmount.toStringAsFixed(2)})',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // Update state and close
                        setState(() {});
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      setState(() {}); // Refresh main screen to show updated paidBy
    });
  }

  void _showSplitTypeDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Type',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSplitTypeOption('equal', 'Split Equally', Icons.people),
            _buildSplitTypeOption('percentage', 'By Percentage', Icons.percent),
            _buildSplitTypeOption('shares', 'By Shares', Icons.pie_chart),
            _buildSplitTypeOption('exact', 'Exact Amounts', Icons.attach_money),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTypeOption(String type, String label, IconData icon) {
    final isSelected = _splitType == type;
    return InkWell(
      onTap: () {
        setState(() => _splitType = type);
        Navigator.pop(context);
        // After selecting a non-equal type, show editors so user can input values immediately
        if (type != 'equal') {
          // Delay to allow the previous sheet to close cleanly
          Future.microtask(() => _showSplitEditorsSheet());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[600],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  void _showSplitEditorsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _splitType == 'percentage'
                          ? Icons.percent
                          : _splitType == 'shares'
                          ? Icons.pie_chart
                          : Icons.attach_money,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _splitType == 'percentage'
                          ? 'Edit Percentage Split'
                          : _splitType == 'shares'
                          ? 'Edit Shares Split'
                          : 'Edit Exact Amounts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedMembers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      'Select members in "Split Among" first to edit amounts.',
                      style: TextStyle(fontSize: 14),
                    ),
                  )
                else
                  _buildSplitEditorCard(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // _pickReceipt removed: unused in this screen. If you want receipt picking
  // re-enabled later, we can add it back and wire the UI.

  Future<void> _showCreateCustomCategoryDialog() async {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '🏷️');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Custom Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Pet Care, Gifts, etc.',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji Icon',
                hintText: 'Choose an emoji',
                border: OutlineInputBorder(),
              ),
              maxLength: 2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: Long press the emoji keyboard button to access emoji picker',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emoji = emojiController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a category name')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': name,
                'emoji': emoji.isEmpty ? '🏷️' : emoji,
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _category = result['name']!;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one member')),
      );
      return;
    }

    // Validate split one more time before save
    _validateSplit();
    if (!_splitValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_splitError ?? 'Invalid split'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Build payers map from the UI controls and find primary payer
    final Map<String, double> payers = {};
    String primaryPayer = _members.first;
    double maxPaid = 0.0;
    for (var uid in _members) {
      final paid = double.tryParse(_paidBy[uid]?.text ?? '0') ?? 0.0;
      if (paid > 0) payers[uid] = paid;
      if (paid > maxPaid) {
        maxPaid = paid;
        primaryPayer = uid;
      }
    }

    setState(() => _saving = true);

    try {
      final description = _descCtrl.text.trim();
      final amount = double.parse(_amountCtrl.text.trim());
      final notes = _notesCtrl.text.trim();

      // Calculate splits from selected type
      final splits = _calcSplitAmounts();

      // Validate that sum(payers) equals total amount (within 1 cent tolerance)
      final totalPaid = payers.values.fold<double>(0.0, (p, c) => p + c);
      final amountDiff = (totalPaid - amount).abs();
      if (payers.isNotEmpty && amountDiff > 0.01) {
        throw 'Who Paid total (₹${totalPaid.toStringAsFixed(2)}) must equal Total (₹${amount.toStringAsFixed(2)})';
      }

      if (_isEditing) {
        // Track changes for audit
        final oldExpense = widget.expense!;
        final changes = <String, String>{};

        if (oldExpense.amount != amount) {
          changes['amount'] =
              '${oldExpense.amount.toStringAsFixed(2)} → ${amount.toStringAsFixed(2)}';
        }
        if (oldExpense.paidBy != primaryPayer) {
          final oldName = _memberNames[oldExpense.paidBy] ?? oldExpense.paidBy;
          final newName = _memberNames[primaryPayer] ?? primaryPayer;
          changes['paid by'] = '$oldName → $newName';
        }
        if (oldExpense.category != _category) {
          changes['category'] = '${oldExpense.category} → $_category';
        }
        if (oldExpense.splitAmong
                .toSet()
                .difference(_selectedMembers.toSet())
                .isNotEmpty ||
            _selectedMembers
                .toSet()
                .difference(oldExpense.splitAmong.toSet())
                .isNotEmpty) {
          final oldMembers = oldExpense.splitAmong
              .map((uid) => _memberNames[uid] ?? uid.substring(0, 4))
              .join(', ');
          final newMembers = _selectedMembers
              .map((uid) => _memberNames[uid] ?? uid.substring(0, 4))
              .join(', ');
          changes['split with'] = '$oldMembers → $newMembers';
        }

        // Update expense
        await FirestoreService().updateExpense(
          roomId: widget.roomId,
          expenseId: oldExpense.id,
          description: description,
          amount: amount,
          paidBy: primaryPayer,
          payers: payers.isNotEmpty ? payers : null,
          category: _category,
          splitAmong: _selectedMembers,
          splits: splits,
          notes: notes.isEmpty ? null : notes,
        );

        // Add audit log
        if (changes.isNotEmpty) {
          await _addAuditLog('updated', changes, description);
        }
      } else {
        // Create new expense
        await FirestoreService().addExpense(
          roomId: widget.roomId,
          description: description,
          amount: amount,
          paidBy: primaryPayer,
          payers: payers.isNotEmpty ? payers : null,
          category: _category,
          splitAmong: _selectedMembers,
          splits: splits,
          notes: notes.isEmpty ? null : notes,
        );

        // Add audit log
        await _addAuditLog('created', {
          'amount': amount.toStringAsFixed(2),
          'paid by': _memberNames[primaryPayer] ?? primaryPayer,
        }, description);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Expense updated!' : 'Expense added!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addAuditLog(
    String action,
    Map<String, String> changes,
    String description,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('auditLog')
          .add({
            'action': action,
            'performedBy': uid,
            'timestamp': FieldValue.serverTimestamp(),
            'expenseDescription': description,
            'changes': changes,
          });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Groceries',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => validateRequired(v, fieldName: 'Description'),
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [DecimalTextInputFormatter(decimalRange: 2)],
              decoration: InputDecoration(
                labelText: 'Total Amount',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: validateAmount,
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: [
                ...ExpenseCategory.categories.map(
                  (cat) => DropdownMenuItem(
                    value: cat.name,
                    child: Row(
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(cat.name),
                      ],
                    ),
                  ),
                ),
                // Add "Custom" option
                const DropdownMenuItem(
                  value: '__CREATE_CUSTOM__',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Create Custom Category...',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (val) {
                if (val == '__CREATE_CUSTOM__') {
                  _showCreateCustomCategoryDialog();
                } else {
                  setState(() => _category = val!);
                }
              },
            ),
            const SizedBox(height: 16),

            // Who Paid (Multiple Payers)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text('Who Paid?'),
                subtitle: Text(_paidSummary()),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showMultiplePayersDialog,
              ),
            ),
            const SizedBox(height: 16),

            // Split Type
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.pie_chart, color: Colors.green),
                title: const Text('Split Type'),
                subtitle: Text(
                  _splitType == 'equal' ? 'Split Equally' : _splitType,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSplitTypeDialog,
              ),
            ),
            const SizedBox(height: 16),

            // Split Among (Checkboxes)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.group, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'Split Among',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._members.map((uid) {
                      final isSelected = _selectedMembers.contains(uid);
                      final displayName = _memberNames[uid] ?? 'User';
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedMembers.add(uid);
                              _splitAutoUid = _selectedMembers.isNotEmpty
                                  ? _selectedMembers.last
                                  : null;
                              _ensureSplitControllers();
                            } else {
                              _selectedMembers.remove(uid);
                              _splitAutoUid = _selectedMembers.isNotEmpty
                                  ? _selectedMembers.last
                                  : null;
                            }
                          });
                        },
                        title: Text(displayName),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Split editors / preview
            _buildSplitEditorCard(),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any additional details',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Receipt (placeholder)
            if (_receiptImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(_receiptImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving || !_splitValid ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Expense' : 'Add Expense',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
