import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/firestore_service.dart';
import '../../Models/expense.dart';
import '../../utils/validators.dart';
import '../../utils/formatters.dart';

class ModernExpenseScreen extends StatefulWidget {
  final String roomId;
  final Expense? expense; // null for add, non-null for edit

  const ModernExpenseScreen({super.key, required this.roomId, this.expense});

  @override
  State<ModernExpenseScreen> createState() => _ModernExpenseScreenState();
}

class _ModernExpenseScreenState extends State<ModernExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();

  bool _saving = false;
  bool _loadingMembers = true;
  bool _uploadingImage = false;

  // Members
  List<String> _members = [];
  Map<String, Map<String, dynamic>> _profiles = {};

  // Selections
  String? _paidByUid;
  String _category = 'Other';
  DateTime _selectedDate = DateTime.now();
  String? _billImageUrl;
  File? _billImageFile;

  // Split configuration
  String _splitType = 'equal'; // 'equal', 'percentage', 'custom'
  Map<String, double> _customSplits = {}; // for percentage or custom amounts
  Set<String> _selectedMembers = {};

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

      Map<String, Map<String, dynamic>> profiles = {};
      try {
        profiles = await fs.getUsersProfiles(members);
      } catch (e) {
        debugPrint('Could not load profiles: $e');
      }

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
        _selectedMembers = members.toSet();

        // Initialize custom splits to equal
        for (var uid in members) {
          _customSplits[uid] = members.isEmpty ? 0 : (100.0 / members.length);
        }

        _loadingMembers = false;
      });

      // If editing, populate fields
      if (widget.expense != null) {
        _populateEditData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load room: $e')));
      setState(() => _loadingMembers = false);
    }
  }

  void _populateEditData() {
    final exp = widget.expense!;
    _titleCtrl.text = exp.description;
    _amountCtrl.text = exp.amount.toStringAsFixed(2);
    _notesCtrl.text = exp.notes ?? '';
    _paidByUid = exp.paidBy;
    _category = exp.category;
    _selectedDate = exp.createdAt;
    _billImageUrl = exp.receiptUrl;
    _selectedMembers = exp.splitAmong.toSet();

    // Determine split type based on splits
    final splits = exp.splits;
    final totalAmount = exp.amount;

    if (splits.isNotEmpty) {
      final firstSplit = splits.values.first;
      final allEqual = splits.values.every(
        (v) => (v - firstSplit).abs() < 0.01,
      );

      if (allEqual) {
        _splitType = 'equal';
      } else {
        // Check if it's percentage-based or custom amounts
        _splitType = 'custom';
        _customSplits = Map.from(splits);

        // Convert to percentages if they add up to 100
        final percentages = splits.map((uid, amount) {
          return MapEntry(uid, (amount / totalAmount) * 100);
        });

        final percentSum = percentages.values.fold(0.0, (a, b) => a + b);
        if ((percentSum - 100).abs() < 1) {
          _splitType = 'percentage';
          _customSplits = percentages;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _getMemberName(String uid) {
    final p = _profiles[uid];
    return p?['displayName'] ??
        p?['name'] ??
        p?['email']?.split('@')[0] ??
        'Member';
  }

  String _getMemberInitials(String uid) {
    final name = _getMemberName(uid);
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Future<void> _pickBillImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _billImageFile = File(image.path);
        _billImageUrl = null; // Clear old URL
      });
    }
  }

  Future<void> _takeBillPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _billImageFile = File(image.path);
        _billImageUrl = null;
      });
    }
  }

  void _removeBillImage() {
    setState(() {
      _billImageFile = null;
      _billImageUrl = null;
    });
  }

  Future<String?> _uploadBillImage() async {
    if (_billImageFile == null) return _billImageUrl;

    setState(() => _uploadingImage = true);

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'expenses/${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final uploadTask = await storageRef.putFile(_billImageFile!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() => _uploadingImage = false);
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading bill image: $e');
      setState(() => _uploadingImage = false);
      return null;
    }
  }

  void _showSplitTypeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Split Type',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            _buildSplitTypeOption(
              'Equal Split',
              'Split equally among selected members',
              Icons.pie_chart_outline,
              'equal',
            ),
            _buildSplitTypeOption(
              'Percentage',
              'Split by custom percentages',
              Icons.percent,
              'percentage',
            ),
            _buildSplitTypeOption(
              'Custom Amount',
              'Enter exact amounts for each person',
              Icons.edit,
              'custom',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTypeOption(
    String title,
    String subtitle,
    IconData icon,
    String type,
  ) {
    final isSelected = _splitType == type;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.2)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isSelected ? Colors.orange : Colors.grey[600]),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.orange)
          : null,
      onTap: () {
        setState(() => _splitType = type);
        Navigator.pop(context);
        if (type != 'equal') {
          _showCustomSplitDialog();
        }
      },
    );
  }

  void _showCustomSplitDialog() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedMembersList = _selectedMembers.toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _splitType == 'percentage'
                            ? 'Split by %'
                            : 'Custom Amounts',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                        child: const Text('DONE'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: selectedMembersList.length,
                    itemBuilder: (context, index) {
                      final uid = selectedMembersList[index];
                      final currentValue = _customSplits[uid] ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Text(
                                _getMemberInitials(uid),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getMemberName(uid),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_splitType == 'percentage')
                                    Text(
                                      '${(currentValue / 100 * amount).toStringAsFixed(2)} INR',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: currentValue.toStringAsFixed(
                                          _splitType == 'percentage' ? 0 : 2,
                                        ),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final newValue =
                                            double.tryParse(value) ?? 0.0;
                                        setModalState(() {
                                          _customSplits[uid] = newValue;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _splitType == 'percentage' ? '%' : '₹',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_splitType == 'percentage')
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_customSplits.values.fold(0.0, (a, b) => a + b).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                (_customSplits.values.fold(
                                              0.0,
                                              (a, b) => a + b,
                                            ) -
                                            100)
                                        .abs() <
                                    0.01
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _selectMember(String uid) {
    setState(() {
      if (_selectedMembers.contains(uid)) {
        _selectedMembers.remove(uid);
        _customSplits.remove(uid);
      } else {
        _selectedMembers.add(uid);
        if (_splitType == 'percentage') {
          _customSplits[uid] = _selectedMembers.length == 1
              ? 100
              : 100.0 / _selectedMembers.length;
        } else {
          _customSplits[uid] = 0.0;
        }
      }
    });
  }

  Map<String, double> _calculateSplits(double amount) {
    if (_splitType == 'equal') {
      final perPerson = _selectedMembers.isEmpty
          ? 0.0
          : amount / _selectedMembers.length;
      return {for (var uid in _selectedMembers) uid: perPerson};
    } else if (_splitType == 'percentage') {
      return _customSplits.map((uid, percent) {
        if (_selectedMembers.contains(uid)) {
          return MapEntry(uid, (percent / 100) * amount);
        }
        return MapEntry(uid, 0.0);
      });
    } else {
      // custom amounts
      return Map.from(_customSplits)
        ..removeWhere((uid, _) => !_selectedMembers.contains(uid));
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
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one person to split with'),
        ),
      );
      return;
    }

    // Validate splits
    if (_splitType == 'percentage') {
      final total = _customSplits.values.fold(0.0, (a, b) => a + b);
      if ((total - 100).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Percentages must add up to 100%')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final amount = double.parse(_amountCtrl.text.trim());
      final splits = _calculateSplits(amount);

      // Upload bill image if selected
      String? billUrl = await _uploadBillImage();

      final fs = FirestoreService();

      if (widget.expense == null) {
        // Add new expense
        await fs.addExpense(
          roomId: widget.roomId,
          description: _titleCtrl.text.trim(),
          amount: amount,
          paidBy: _paidByUid!,
          category: _category,
          splitAmong: _selectedMembers.toList(),
          splits: splits,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          receiptUrl: billUrl,
          createdAt: _selectedDate,
        );
      } else {
        // Update existing expense
        await fs.updateExpense(
          roomId: widget.roomId,
          expenseId: widget.expense!.id,
          description: _titleCtrl.text.trim(),
          amount: amount,
          paidBy: _paidByUid!,
          category: _category,
          splitAmong: _selectedMembers.toList(),
          splits: splits,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          receiptUrl: billUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null ? 'Expense added!' : 'Expense updated!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.expense != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Expense' : 'Add Expense',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          if (_saving || _uploadingImage)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'SAVE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _loadingMembers
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Bill Image Section
                  _buildBillImageSection(),
                  const SizedBox(height: 24),

                  // Title/Description
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter expense title',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: validateRequired,
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      DecimalTextInputFormatter(decimalRange: 2),
                    ],
                    validator: validateAmount,
                  ),
                  const SizedBox(height: 24),

                  // Category Selection
                  const Text(
                    'Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryGrid(),
                  const SizedBox(height: 24),

                  // Paid By
                  const Text(
                    'Paid By',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildPaidBySection(),
                  const SizedBox(height: 24),

                  // Split Configuration
                  const Text(
                    'Split With',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildSplitSection(),
                  const SizedBox(height: 24),

                  // Date
                  _buildDateSection(),
                  const SizedBox(height: 24),

                  // Notes (Optional)
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Add any additional notes',
                      prefixIcon: const Icon(Icons.note_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildBillImageSection() {
    if (_billImageFile != null || _billImageUrl != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _billImageFile != null
                  ? Image.file(_billImageFile!, fit: BoxFit.cover)
                  : Image.network(_billImageUrl!, fit: BoxFit.cover),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: _removeBillImage,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[50],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildImageOption(Icons.camera_alt, 'Camera', _takeBillPhoto),
          Container(width: 1, height: 60, color: Colors.grey[300]),
          _buildImageOption(Icons.photo_library, 'Gallery', _pickBillImage),
        ],
      ),
    );
  }

  Widget _buildImageOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.orange),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: ExpenseCategory.categories.map((cat) {
        final isSelected = _category == cat.name;
        return InkWell(
          onTap: () => setState(() => _category = cat.name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.orange : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  cat.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaidBySection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _members.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final uid = _members[index];
          final isSelected = _paidByUid == uid;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.orange : Colors.grey[300],
              child: Text(
                _getMemberInitials(uid),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
            title: Text(_getMemberName(uid)),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.orange)
                : null,
            onTap: () => setState(() => _paidByUid = uid),
          );
        },
      ),
    );
  }

  Widget _buildSplitSection() {
    return Column(
      children: [
        // Split type selector
        InkWell(
          onTap: _showSplitTypeDialog,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Split Type',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _splitType == 'equal'
                            ? 'Equal Split'
                            : _splitType == 'percentage'
                            ? 'By Percentage'
                            : 'Custom Amount',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Member selection
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final uid = _members[index];
              final isSelected = _selectedMembers.contains(uid);
              final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
              final splits = _calculateSplits(amount);
              final memberSplit = splits[uid] ?? 0.0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? Colors.orange
                      : Colors.grey[300],
                  child: Text(
                    _getMemberInitials(uid),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                title: Text(_getMemberName(uid)),
                subtitle: isSelected && amount > 0
                    ? Text(
                        '₹${memberSplit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
                trailing: Checkbox(
                  value: isSelected,
                  activeColor: Colors.orange,
                  onChanged: (_) => _selectMember(uid),
                ),
                onTap: () => _selectMember(uid),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    Formatters.formatDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
