// lib/screens/expenses/add_expense_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../Models/expense.dart';
import '../../services/firestore_service.dart';

enum SplitMethod { equal, percentage, exact }

class AddExpenseSheet extends StatefulWidget {
  final String roomId;
  final Expense? expense;

  const AddExpenseSheet({super.key, required this.roomId, this.expense});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // State
  bool _isLoading = false;
  File? _receiptImage;

  List<String> _allParticipantUids = []; // Members + Guests
  Map<String, String> _memberNames = {}; // uid -> name
  final Map<String, String> _hiddenGuestNames = {}; // Name -> ID (for reuse)
  bool _membersLoaded = false;

  // Selections
  String _selectedCategory = 'Other';
  String? _selectedPayer; // null = current user initially
  bool _isMultiPayer = false;
  Map<String, double> _payersMap = {}; // uid -> amount
  final Set<String> _manuallyEditedPayers = {}; // Track who was manually edited
  SplitMethod _splitMethod = SplitMethod.equal;

  // Split Data
  Set<String> _selectedSplitMembers = {}; // For Equal split
  final Map<String, double> _percentageSplits = {};
  Map<String, double> _exactSplits = {};

  // Custom Categories
  List<ExpenseCategory> _customCategories = [];

  // Controllers for multi-payer inputs to allow live updates
  final Map<String, TextEditingController> _payerControllers = {};

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    final firestore = context.read<FirestoreService>();
    final room = await firestore.getRoom(widget.roomId);

    if (room != null) {
      // Load Custom Categories
      final customCats = room['customCategories'] as List<dynamic>?;
      if (customCats != null) {
        _customCategories = customCats.map((c) {
          final data = c as Map<String, dynamic>;
          return ExpenseCategory.createCustom(
            data['name'] ?? 'Custom',
            data['emoji'] ?? '🏷️',
          );
        }).toList();
      }

      final listA = room['memberUids'];
      final listB = room['members'];
      final uids = listA is List
          ? List<String>.from(listA)
          : (listB is List ? List<String>.from(listB) : <String>[]);

      // Fetch profiles to get names for dropdowns
      final profiles = await firestore.getUsersProfiles(uids);
      final names = <String, String>{};

      for (var uid in uids) {
        final p = profiles[uid];
        String name = 'Unknown';
        if (p != null) {
          name =
              p['displayName'] ??
              p['name'] ??
              (p['email'] != null ? (p['email'] as String).split('@')[0] : uid);
        }
        names[uid] = name;
      }

      // Load Guests
      final guestsMap = room['guests'] as Map<String, dynamic>?;
      final guestUids = <String>[];
      _hiddenGuestNames.clear();

      if (guestsMap != null) {
        guestsMap.forEach((guestId, data) {
          if (data['isActive'] == true) {
            final name = data['name'] ?? 'Guest';

            // Check if guest should be shown:
            // 1. Only include if editing an expense where guest is already involved
            // 2. Otherwise don't show by default (user must add them manually)
            bool keep = false;

            if (widget.expense != null) {
              final e = widget.expense!;
              if (e.paidBy == guestId) keep = true;
              if (e.payers?.containsKey(guestId) == true) keep = true;
              if (e.splits.containsKey(guestId)) keep = true;
            }

            if (keep) {
              guestUids.add(guestId);
              names[guestId] = name;
            } else {
              // Store for potential reuse if user adds them again
              _hiddenGuestNames[name.toLowerCase()] = guestId;
              // We also populate names so if we revive them, we have the name
              names[guestId] = name;
            }
          }
        });
      }

      if (mounted) {
        setState(() {
          _allParticipantUids = [...uids, ...guestUids];
          _memberNames = names;
          _membersLoaded = true;

          _initializeFromExpense();
        });
      }
    }
  }

  void _initializeFromExpense() {
    final currentUser = FirebaseAuth.instance.currentUser?.uid;

    if (widget.expense != null) {
      final e = widget.expense!;
      _descriptionController.text = e.description;
      _amountController.text = e.amount.toString();
      _notesController.text = e.notes ?? '';
      _selectedCategory = e.category;

      // Payer Logic
      if (e.payers != null && e.payers!.length > 1) {
        _isMultiPayer = true;
        _payersMap = Map.from(e.payers!);
        _selectedPayer = null;
      } else {
        _isMultiPayer = false;
        _selectedPayer = e.paidBy;
        _payersMap = {};
      }

      // Determine split method
      bool allEqual = true;
      if (e.splitAmong.isNotEmpty) {
        final expected = e.amount / e.splitAmong.length;
        for (var uid in e.splitAmong) {
          final amt = e.splits[uid] ?? 0;
          if ((amt - expected).abs() > 0.1) {
            allEqual = false;
            break;
          }
        }
      }

      if (allEqual) {
        _splitMethod = SplitMethod.equal;
        _selectedSplitMembers = Set.from(e.splitAmong);
      } else {
        _splitMethod = SplitMethod.exact;
        _exactSplits = Map.from(e.splits);
        _selectedSplitMembers = Set.from(e.splitAmong); // Keep for consistency
      }
    } else {
      // New Expense Defaults
      _selectedPayer = currentUser;
      if (_allParticipantUids.isNotEmpty) {
        _selectedSplitMembers = Set.from(_allParticipantUids);
      }
      if (_selectedPayer == null && _allParticipantUids.isNotEmpty) {
        _selectedPayer = _allParticipantUids.first;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (var c in _payerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getPayerController(String uid, double amount) {
    if (!_payerControllers.containsKey(uid)) {
      _payerControllers[uid] = TextEditingController(
        text: amount.toStringAsFixed(2),
      );
    }
    // Update if needed - BUT handle caret position if user is typing?
    // Actually, if we use controller, we should ONLY update it programmatically
    // when the logic changes the value, NOT when the user types (which updates the controller automatically).
    // So distinct check is important.

    // However, since we rebuild on setState, we need to make sure we don't overwrite user's typing
    // if this rebuild was caused by their typing.
    // Ideally, _distributeRemaining updates the map, and we syncing map -> controller for AUTO fields.
    // For manual fields, the controller is master for the moment.

    return _payerControllers[uid]!;
  }

  @override
  Widget build(BuildContext context) {
    // If data not loaded yet, show loader
    if (!_membersLoaded) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.expense == null ? 'Add Expense' : 'Edit Expense',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Row 1: Description (Full Width)
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          prefixIcon: const Icon(
                            Icons.description_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Row 2: Amount + Category
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _amountController,
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                prefixIcon: const Icon(
                                  Icons.currency_rupee,
                                  size: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 16,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'),
                                ),
                              ],
                              validator: (val) => (val == null || val.isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Category (Half)
                          Expanded(child: _buildCategoryDropdown()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 3: Who Paid (Full Width)
                      _buildPayerDropdown(),
                      const SizedBox(height: 16),

                      // Second Row of Options: Split Method
                      _buildSplitMethodSelector(),
                      const SizedBox(height: 16),

                      // Dynamic Split Section
                      _buildSplitSection(),
                      const SizedBox(height: 16),

                      // Notes & Receipt
                      ExpansionTile(
                        title: const Text(
                          'Add Notes & Receipt',
                          style: TextStyle(fontSize: 14),
                        ),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          if (_receiptImage != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _receiptImage!,
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    // Optimization to prevent buffer warnings
                                    cacheWidth: 1024,
                                    gaplessPlayback: true,
                                  ),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _receiptImage = null),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.black54,
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _pickReceipt,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Attach Receipt'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Save Button
                      FilledButton(
                        onPressed: _isLoading ? null : _saveExpense,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.expense == null
                                    ? 'Add Expense'
                                    : 'Save Changes',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    // Combine standard and custom categories for the dropdown items
    final allCategories = [...ExpenseCategory.categories, ..._customCategories];

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Category',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        ...allCategories.map((c) {
          // Check if this is a custom category to add delete option
          final isCustom = _customCategories.contains(c);
          return DropdownMenuItem(
            value: c.name,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(c.icon),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                if (isCustom)
                  GestureDetector(
                    onTap: () {
                      // Handle delete
                      // We need to stop propagation if possible, but DropdownMenuItem eats taps usually.
                      // However, using a child gesture detector might work if we are careful.
                      // Actually, Flutter Dropdowns can be tricky with interactions inside items.
                      // A common workaround is to have a separate "Manage" dialog or confirm delete.
                      // Let's try to intercept here.
                      _deleteCustomCategory(c);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red[300],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        // Add "Custom" option helper if current selection is not in list (e.g. deleted or legacy)
        if (!allCategories.any((c) => c.name == _selectedCategory) &&
            _selectedCategory != 'Custom' &&
            _selectedCategory != 'Other')
          DropdownMenuItem(
            value: _selectedCategory,
            child: Row(
              children: [
                const Text('🏷️'),
                const SizedBox(width: 8),
                Text(_selectedCategory, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        const DropdownMenuItem(
          value: 'Custom',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Create New...',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == 'Custom') {
          // Reset selection to something valid temporarily or just keep previous
          // to avoid "Custom" lingering as selected value if dialog cancelled
          _showCreateCustomCategoryDialog(); // This handles state update on success
        } else if (val != null) {
          // Check if the user clicked the delete icon area?
          // No, onChanged is fired when Item is selected.
          // If the user tapped the delete icon, we might have triggered _deleteCustomCategory AND onChanged.
          // We'll handle this by checking if the value still exists in the list.
          setState(() => _selectedCategory = val);
        }
      },
      selectedItemBuilder: (context) {
        return [
          ...allCategories.map((c) {
            return Row(
              children: [
                Text(c.icon),
                const SizedBox(width: 8),
                Text(c.name, overflow: TextOverflow.ellipsis),
              ],
            );
          }),
          if (!allCategories.any((c) => c.name == _selectedCategory) &&
              _selectedCategory != 'Custom' &&
              _selectedCategory != 'Other')
            Row(
              children: [
                const Text('🏷️'),
                const SizedBox(width: 8),
                Text(_selectedCategory, overflow: TextOverflow.ellipsis),
              ],
            ),
          const Row(
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 8),
              Text('Custom...'),
            ],
          ),
        ];
      },
    );
  }

  Future<void> _deleteCustomCategory(ExpenseCategory cat) async {
    // Confirm delete
    // Note: Since this is inside a dropdown, closing the dropdown is tricky or happens automatically.
    // If the tap closes the dropdown, we show the dialog.
    // If we are currently selecting this category, reset to Other.

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      try {
        final fs = context.read<FirestoreService>();
        await fs.removeCategoryFromRoom(widget.roomId, cat.name, cat.icon);
        if (!mounted) return;
        setState(() {
          _customCategories.remove(cat);
          if (_selectedCategory == cat.name) {
            _selectedCategory = 'Other';
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  Widget _buildPayerDropdown() {
    if (_isMultiPayer) {
      return _buildMultiPayerSection();
    }

    return DropdownButtonFormField<String>(
      key: ValueKey('payer_$_selectedPayer'), // Ensure rebuilds updates
      initialValue: _allParticipantUids.contains(_selectedPayer)
          ? _selectedPayer
          : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Who Paid',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        ..._allParticipantUids.map((uid) {
          final isGuest = uid.startsWith('guest_');
          return DropdownMenuItem(
            value: uid,
            child: Row(
              children: [
                if (isGuest)
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.orange,
                  )
                else
                  const SizedBox.shrink(),
                if (isGuest) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    uid == FirebaseAuth.instance.currentUser?.uid
                        ? 'You'
                        : (_memberNames[uid] ?? 'Unknown'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const DropdownMenuItem(
          value: 'ADD_GUEST',
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Add Guest...',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const DropdownMenuItem(
          value: 'MULTIPLE',
          child: Row(
            children: [
              Icon(Icons.people, size: 16),
              SizedBox(width: 8),
              Text('Multiple People...'),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == 'MULTIPLE') {
          setState(() {
            _isMultiPayer = true;
            // Initialize map with current payer if any
            if (_selectedPayer != null) {
              final amt = double.tryParse(_amountController.text) ?? 0;
              _payersMap = {_selectedPayer!: amt};
            } else {
              _payersMap = {};
            }
          });
        } else if (val == 'ADD_GUEST') {
          _showAddGuestDialog();
        } else if (val != null) {
          setState(() => _selectedPayer = val);
        }
      },
      validator: (val) => (val == null && !_isMultiPayer) ? 'Required' : null,
    );
  }

  Future<void> _showAddGuestDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Guest'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Guest Name',
            hintText: 'e.g. John',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final name = nameController.text.trim();
                String? guestId;

                // Check if we can reuse a hidden (settled) guest
                final lowerName = name.toLowerCase();
                if (_hiddenGuestNames.containsKey(lowerName)) {
                  guestId = _hiddenGuestNames[lowerName];
                }

                try {
                  if (guestId == null) {
                    final fs = context.read<FirestoreService>();
                    guestId = await fs.addGuestToRoom(widget.roomId, name);
                  }

                  if (mounted) {
                    final String finalGuestId = guestId;
                    setState(() {
                      if (!_allParticipantUids.contains(finalGuestId)) {
                        _allParticipantUids.add(finalGuestId);
                      }
                      _memberNames[finalGuestId] = name;
                      _selectedPayer = finalGuestId; // Select the new guest
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (mounted) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiPayerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Who Paid?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Select members and set amounts',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isMultiPayer = false;
                    // Reset to single payer
                    if (_payersMap.isNotEmpty) {
                      _selectedPayer = _payersMap.keys.first;
                    } else {
                      // Safe default: Current User or first available
                      final currentUser =
                          FirebaseAuth.instance.currentUser?.uid;
                      if (currentUser != null &&
                          _allParticipantUids.contains(currentUser)) {
                        _selectedPayer = currentUser;
                      } else {
                        _selectedPayer = _allParticipantUids.isNotEmpty
                            ? _allParticipantUids.first
                            : null;
                      }
                    }
                  });
                },
                child: const Text('Single Payer'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          ..._allParticipantUids.map((uid) {
            final isPaying = _payersMap.containsKey(uid);
            final isAuto = isPaying && !_manuallyEditedPayers.contains(uid);
            // Determine if this specific user is the one receiving the remainder (last of the auto candidates)
            final autoFillCandidates = _payersMap.keys
                .where((u) => !_manuallyEditedPayers.contains(u))
                .toList();
            final isRemainderTarget =
                isAuto &&
                autoFillCandidates.isNotEmpty &&
                autoFillCandidates.last == uid;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPaying
                      ? Colors.blue.withValues(alpha: 0.5)
                      : Colors.grey[300]!,
                  width: isPaying ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isPaying,
                    activeColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _payersMap[uid] = 0;
                          _distributeRemaining();
                        } else {
                          _payersMap.remove(uid);
                          _manuallyEditedPayers.remove(uid);
                          _distributeRemaining();
                        }
                      });
                    },
                  ),
                  Expanded(
                    child: Text(
                      uid == FirebaseAuth.instance.currentUser?.uid
                          ? 'You'
                          : (_memberNames[uid] ?? 'Unknown'),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPaying) ...[
                    Container(
                      width: 140,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isAuto
                            ? Colors.blue.withValues(alpha: 0.05)
                            : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('payer_$uid'),
                              controller: _getPayerController(
                                uid,
                                _payersMap[uid] ?? 0,
                              ),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: isAuto
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isAuto ? Colors.blue[700] : Colors.black,
                              ),
                              decoration: const InputDecoration(
                                prefixText: ' ₹ ',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 14,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (val) {
                                // Mark as edited
                                final amount = double.tryParse(val) ?? 0;
                                // We don't setState here to avoid rebuilding the whole list constantly?
                                // No, we need to recalculate remaining.
                                setState(() {
                                  _payersMap[uid] = amount;
                                  _manuallyEditedPayers.add(uid);
                                  _distributeRemaining();
                                });
                              },
                            ),
                          ),
                          if (isRemainderTarget)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Auto',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (!isAuto)
                            // Show X to reset to Auto
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _manuallyEditedPayers.remove(uid);
                                  _payersMap[uid] = 0; // Will be recalculated
                                  _distributeRemaining();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.refresh,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _distributeRemaining() {
    final total = double.tryParse(_amountController.text) ?? 0;

    // 1. Calculate sum of manually edited payers
    double lockedSum = 0;
    for (var uid in _manuallyEditedPayers) {
      if (_payersMap.containsKey(uid)) {
        lockedSum += _payersMap[uid]!;
      }
    }

    final remaining = total - lockedSum;

    // 2. Find payers who are selected but NOT manually edited
    List<String> autoFillCandidates = _payersMap.keys
        .where((uid) => !_manuallyEditedPayers.contains(uid))
        .toList();

    // 3. Distribute remaining amount
    if (autoFillCandidates.isEmpty) {
      // If everyone is manually edited, we can't auto-fill anyone.
      // User must manually adjust.
    } else if (autoFillCandidates.length == 1) {
      // Perfect case: Assign ALL remaining to this single user
      // Ensure non-negative
      final uid = autoFillCandidates.first;
      final val = remaining > 0 ? remaining : 0.0;

      setState(() {
        _payersMap[uid] = val;
        if (_payerControllers[uid] != null) {
          String newVal = val.toStringAsFixed(2);
          if (_payerControllers[uid]!.text != newVal) {
            _payerControllers[uid]!.text = newVal;
          }
        }
      });
    } else {
      // Multiple candidates...
      // User asked: "automatic fill member c amount instantly".
      // Logic: Keep first N-1 candidates at 0 (or their current value? usually 0 if just checked)
      // and dump remaining into the LAST candidate.
      // This creates a "waterfall" effect.

      setState(() {
        // Reset all candidates first (optional, but cleaner)
        for (var i = 0; i < autoFillCandidates.length - 1; i++) {
          final uid = autoFillCandidates[i];
          _payersMap[uid] = 0;
          _payerControllers[uid]?.text = '0.00';
        }

        // Give rest to the last one
        final lastUid = autoFillCandidates.last;
        final finalAmount = remaining > 0 ? remaining : 0.0;
        _payersMap[lastUid] = finalAmount;

        // Fix: Update controller text directly!
        // This ensures the field shows the new calculated value immediately
        // even though it's focused or not.
        // We check to avoid infinite loop if this was triggered by itself (unlikely here)
        if (_payerControllers[lastUid] != null) {
          String newVal = finalAmount.toStringAsFixed(2);
          if (_payerControllers[lastUid]!.text != newVal) {
            _payerControllers[lastUid]!.text = newVal;
          }
        }
      });
    }
  }

  Widget _buildSplitMethodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSplitTypeBtn(SplitMethod.equal, 'Equal', Icons.group),
          ),
          Expanded(
            child: _buildSplitTypeBtn(
              SplitMethod.percentage,
              '% Split',
              Icons.percent,
            ),
          ),
          Expanded(
            child: _buildSplitTypeBtn(
              SplitMethod.exact,
              'Exact',
              Icons.numbers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTypeBtn(SplitMethod method, String label, IconData icon) {
    final isSelected = _splitMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _splitMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitSection() {
    switch (_splitMethod) {
      case SplitMethod.equal:
        return _buildEqualSplitSection();
      case SplitMethod.percentage:
        return _buildPercentageSplitSection();
      case SplitMethod.exact:
        return _buildExactSplitSection();
    }
  }

  Widget _buildEqualSplitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Split Among',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSplitMembers =
                      _selectedSplitMembers.length == _allParticipantUids.length
                      ? {}
                      : Set.from(_allParticipantUids);
                });
              },
              child: Text(
                _selectedSplitMembers.length == _allParticipantUids.length
                    ? 'Clear All'
                    : 'Select All',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allParticipantUids.map((uid) {
            final isSelected = _selectedSplitMembers.contains(uid);
            return FilterChip(
              label: Text(_memberNames[uid] ?? 'Unknown'),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedSplitMembers.add(uid);
                  } else {
                    _selectedSplitMembers.remove(uid);
                  }
                });
              },
              avatar: CircleAvatar(
                backgroundColor: isSelected ? Colors.white : Colors.grey[300],
                child: Text(
                  (_memberNames[uid] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPercentageSplitSection() {
    return Column(
      children: _allParticipantUids.map((uid) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(child: Text(_memberNames[uid] ?? 'Unknown')),
              SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: (_percentageSplits[uid] ?? 0).toString(),
                  decoration: const InputDecoration(
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    _percentageSplits[uid] = double.tryParse(val) ?? 0;
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExactSplitSection() {
    return Column(
      children: _allParticipantUids.map((uid) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(child: Text(_memberNames[uid] ?? 'Unknown')),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: (_exactSplits[uid] ?? 0).toString(),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) {
                    _exactSplits[uid] = double.tryParse(val) ?? 0;
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _receiptImage = File(image.path));
    }
  }

  Future<void> _showCreateCustomCategoryDialog() async {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '🏷️');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Gym, Internet',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji',
                helperText: 'Pick an emoji from your keyboard',
              ),
              maxLength: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final name = nameController.text.trim();
                // Use input emoji or default if empty (though controller has default)
                String emoji = emojiController.text.trim();
                if (emoji.isEmpty) emoji = '🏷️';
                // Take first char if multiple? User might paste multiple.
                // Just keep it as is, usually 1-2 chars.

                try {
                  // Save to Firestore
                  final fs = context.read<FirestoreService>();
                  await fs.addCategoryToRoom(widget.roomId, name, emoji);

                  // Update local state immediately for responsiveness
                  setState(() {
                    _customCategories.add(
                      ExpenseCategory.createCustom(name, emoji),
                    );
                    _selectedCategory = name;
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  // Handle error
                  if (ctx.mounted) {
                    Navigator.pop(ctx); // Close anyway or show error
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    // Payer Validation
    if (!_isMultiPayer && _selectedPayer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select who paid')));
      return;
    }

    final amount = double.parse(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0')),
      );
      return;
    }

    // Multi-Payer Sum Validation
    Map<String, double> finalPayers = {};
    if (_isMultiPayer) {
      double sum = 0;
      _payersMap.forEach((uid, amt) {
        if (amt > 0) {
          finalPayers[uid] = amt;
          sum += amt;
        }
      });

      if (finalPayers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one payer')),
        );
        return;
      }

      if ((sum - amount).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payer amounts (₹$sum) must equal Total (₹$amount)'),
          ),
        );
        return;
      }
    } else {
      finalPayers = {_selectedPayer!: amount};
    }

    final splits = _calculateFinalSplits(amount);
    if (splits == null) return; // Error handled inside

    setState(() => _isLoading = true);

    try {
      final firestore = context.read<FirestoreService>();
      String? receiptUrl = widget.expense?.receiptUrl;

      if (_receiptImage != null) {
        // Upload image
        receiptUrl = await firestore.uploadReceipt(
          _receiptImage!,
          widget.roomId,
        );
      }

      // Determine primary paidBy (for legacy/display compatibility)
      // If multiple, just pick the one with max amount or first one.
      // The backend 'payers' map is the source of truth for calculations.
      String primaryPayer = finalPayers.keys.first;
      if (finalPayers.length > 1) {
        // Optional: find max payer
        double max = -1;
        finalPayers.forEach((uid, amt) {
          if (amt > max) {
            max = amt;
            primaryPayer = uid;
          }
        });
      }

      if (widget.expense == null) {
        await firestore.addExpense(
          roomId: widget.roomId,
          description: _descriptionController.text.trim(),
          amount: amount,
          paidBy: primaryPayer,
          category: _selectedCategory,
          splitAmong: splits.keys.toList(),
          splits: splits,
          notes: _notesController.text.trim(),
          receiptUrl: receiptUrl,
          payers: finalPayers,
        );
      } else {
        await firestore.updateExpense(
          roomId: widget.roomId,
          expenseId: widget.expense!.id,
          description: _descriptionController.text.trim(),
          amount: amount,
          paidBy: primaryPayer,
          category: _selectedCategory,
          splitAmong: splits.keys.toList(),
          splits: splits,
          notes: _notesController.text.trim(),
          receiptUrl: receiptUrl,
          payers: finalPayers,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Map<String, double>? _calculateFinalSplits(double totalAmount) {
    Map<String, double> finalSplits = {};

    if (_splitMethod == SplitMethod.equal) {
      if (_selectedSplitMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select at least one member to split with'),
          ),
        );
        return null;
      }
      final perPerson = totalAmount / _selectedSplitMembers.length;
      for (var uid in _selectedSplitMembers) {
        finalSplits[uid] = perPerson;
      }
    } else if (_splitMethod == SplitMethod.percentage) {
      double totalPercent = 0;
      _percentageSplits.forEach((uid, percent) {
        if (percent > 0) {
          totalPercent += percent;
          finalSplits[uid] = (percent / 100) * totalAmount;
        }
      });
      if ((totalPercent - 100).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Percentages must equal 100% (Current: $totalPercent%)',
            ),
          ),
        );
        return null;
      }
    } else if (_splitMethod == SplitMethod.exact) {
      double totalAllocated = 0;
      _exactSplits.forEach((uid, amt) {
        if (amt > 0) {
          totalAllocated += amt;
          finalSplits[uid] = amt;
        }
      });
      if ((totalAllocated - totalAmount).abs() > 0.1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Split amounts must equal ₹$totalAmount (Current: ₹$totalAllocated)',
            ),
          ),
        );
        return null;
      }
    }

    if (finalSplits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid split configuration')),
      );
      return null;
    }

    return finalSplits;
  }
}
