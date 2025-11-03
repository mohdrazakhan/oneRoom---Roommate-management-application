// lib/screens/expenses/add_expense_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../Models/expense.dart';
import '../../services/firestore_service.dart';

class AddExpenseSheet extends StatefulWidget {
  final String roomId;
  final Expense? expense; // For editing

  const AddExpenseSheet({Key? key, required this.roomId, this.expense})
    : super(key: key);

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'Other';
  List<String> _roomMembers = [];
  Set<String> _selectedMembers = {};
  bool _isEqualSplit = true;
  Map<String, TextEditingController> _customAmountControllers = {};
  File? _receiptImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoomMembers();

    if (widget.expense != null) {
      _descriptionController.text = widget.expense!.description;
      _amountController.text = widget.expense!.amount.toString();
      _notesController.text = widget.expense!.notes ?? '';
      _selectedCategory = widget.expense!.category;
      _selectedMembers = Set.from(widget.expense!.splitAmong);
    }
  }

  Future<void> _loadRoomMembers() async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    final room = await firestoreService.getRoom(widget.roomId);

    if (room != null) {
      setState(() {
        _roomMembers = List<String>.from(room['memberUids'] ?? []);
        if (widget.expense == null) {
          // Default: select all members
          _selectedMembers = Set.from(_roomMembers);
        }
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customAmountControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // Handle bar
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.expense == null ? 'Add Expense' : 'Edit Expense',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.grey[300]),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'What was this expense for?',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an amount';
                          }
                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ExpenseCategory.categories.map((cat) {
                          final isSelected = _selectedCategory == cat.name;
                          return ChoiceChip(
                            label: Text('${cat.icon} ${cat.name}'),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = cat.name;
                              });
                            },
                            selectedColor: Color(
                              cat.colorValue,
                            ).withOpacity(0.3),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Split among members
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Split among',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedMembers.length ==
                                    _roomMembers.length) {
                                  _selectedMembers.clear();
                                } else {
                                  _selectedMembers = Set.from(_roomMembers);
                                }
                              });
                            },
                            child: Text(
                              _selectedMembers.length == _roomMembers.length
                                  ? 'Deselect All'
                                  : 'Select All',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._roomMembers.map((uid) {
                        return FutureBuilder<String>(
                          future: _getUserName(uid),
                          builder: (context, snapshot) {
                            final name = snapshot.data ?? 'Loading...';
                            final isSelected = _selectedMembers.contains(uid);

                            return CheckboxListTile(
                              title: Text(name),
                              value: isSelected,
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedMembers.add(uid);
                                  } else {
                                    _selectedMembers.remove(uid);
                                  }
                                });
                              },
                              secondary: CircleAvatar(
                                child: Text(name[0].toUpperCase()),
                              ),
                            );
                          },
                        );
                      }),

                      if (_selectedMembers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Equal Split'),
                                    icon: Icon(Icons.people),
                                  ),
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Custom'),
                                    icon: Icon(Icons.edit),
                                  ),
                                ],
                                selected: {_isEqualSplit},
                                onSelectionChanged: (Set<bool> newSelection) {
                                  setState(() {
                                    _isEqualSplit = newSelection.first;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        if (!_isEqualSplit) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Custom amounts',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._selectedMembers.map((uid) {
                            _customAmountControllers.putIfAbsent(
                              uid,
                              () => TextEditingController(),
                            );

                            return FutureBuilder<String>(
                              future: _getUserName(uid),
                              builder: (context, snapshot) {
                                final name = snapshot.data ?? 'Loading...';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: TextFormField(
                                    controller: _customAmountControllers[uid],
                                    decoration: InputDecoration(
                                      labelText: name,
                                      prefixIcon: const Icon(
                                        Icons.currency_rupee,
                                      ),
                                      border: const OutlineInputBorder(),
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
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ],

                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Add any additional notes',
                          prefixIcon: Icon(Icons.note),
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Receipt image
                      if (_receiptImage != null) ...[
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _receiptImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: () {
                                setState(() {
                                  _receiptImage = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Add receipt button
                      if (_receiptImage == null)
                        OutlinedButton.icon(
                          onPressed: _pickReceipt,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Add Receipt Photo'),
                        ),

                      const SizedBox(height: 24),

                      // Save button
                      FilledButton(
                        onPressed: _isLoading ? null : _saveExpense,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.expense == null
                                    ? 'Add Expense'
                                    : 'Save Changes',
                              ),
                      ),
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

  Future<void> _pickReceipt() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _receiptImage = File(image.path);
      });
    }
  }

  Future<String> _getUserName(String uid) async {
    final firestoreService = Provider.of<FirestoreService>(
      context,
      listen: false,
    );
    try {
      final profile = await firestoreService.getUserProfile(uid);
      final candidates = ['name', 'displayName', 'fullName', 'username'];
      for (final key in candidates) {
        final v = profile?[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      final email = profile?['email'];
      if (email is String && email.trim().isNotEmpty) return email.trim();
      return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
    } catch (e) {
      return uid.length > 8 ? '${uid.substring(0, 8)}…' : uid;
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member to split with'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestoreService = Provider.of<FirestoreService>(
        context,
        listen: false,
      );
      final currentUser = FirebaseAuth.instance.currentUser!;

      final amount = double.parse(_amountController.text);

      // Calculate splits
      Map<String, double> splits = {};
      if (_isEqualSplit) {
        final splitAmount = amount / _selectedMembers.length;
        for (var uid in _selectedMembers) {
          splits[uid] = splitAmount;
        }
      } else {
        for (var uid in _selectedMembers) {
          final customAmount =
              double.tryParse(_customAmountControllers[uid]?.text ?? '0') ?? 0;
          splits[uid] = customAmount;
        }

        // Validate custom splits
        final totalSplit = splits.values.fold<double>(
          0,
          (sum, amount) => sum + amount,
        );
        if ((totalSplit - amount).abs() > 0.01) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Split amounts (₹${totalSplit.toStringAsFixed(2)}) must equal total amount (₹${amount.toStringAsFixed(2)})',
              ),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Upload receipt if selected
      String? receiptUrl;
      if (_receiptImage != null) {
        receiptUrl = await firestoreService.uploadReceipt(
          _receiptImage!,
          widget.roomId,
        );
      }

      if (widget.expense == null) {
        // Add new expense
        await firestoreService.addExpense(
          roomId: widget.roomId,
          description: _descriptionController.text.trim(),
          amount: amount,
          paidBy: currentUser.uid,
          category: _selectedCategory,
          splitAmong: _selectedMembers.toList(),
          splits: splits,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          receiptUrl: receiptUrl,
        );
      } else {
        // Update existing expense
        await firestoreService.updateExpense(
          roomId: widget.roomId,
          expenseId: widget.expense!.id,
          description: _descriptionController.text.trim(),
          amount: amount,
          category: _selectedCategory,
          splitAmong: _selectedMembers.toList(),
          splits: splits,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          receiptUrl: receiptUrl,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.expense == null
                ? 'Expense added successfully'
                : 'Expense updated successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
