import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Models/udhar_transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class AddUdharSheet extends StatefulWidget {
  final UdharTransaction? transactionToEdit;

  const AddUdharSheet({super.key, this.transactionToEdit});

  @override
  State<AddUdharSheet> createState() => _AddUdharSheetState();
}

class _AddUdharSheetState extends State<AddUdharSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _interestValueController = TextEditingController();
  final _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _type = 'GIVEN';
  String _interestType = UdharTransaction.interestTypeNone;
  String _interestFrequency = UdharTransaction.interestFrequencyDaily;
  String _interestStartRule = UdharTransaction.interestStartFromCreated;
  DateTime? _dueDate;
  bool _openSmsAfterSave = true;
  bool _isLoading = false;

  XFile? _personImage;
  Uint8List? _personImageBytes;
  XFile? _receiptImage;
  Uint8List? _receiptImageBytes;
  String? _existingPersonImageUrl;
  String? _existingReceiptUrl;

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _nameController.text = t.personName;
      _phoneController.text = t.phoneNumber ?? '';
      _amountController.text = t.amount.toStringAsFixed(0);
      _interestValueController.text = t.interestValue == 0
          ? ''
          : t.interestValue.toStringAsFixed(t.interestValue % 1 == 0 ? 0 : 2);
      _notesController.text = t.notes ?? '';
      _type = t.type;
      _interestType = t.interestType;
      _interestFrequency = t.interestFrequency;
      _interestStartRule = t.interestStartRule;
      _dueDate = t.dueDate;
      _existingPersonImageUrl = t.personImageUrl;
      _existingReceiptUrl = t.receiptUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _interestValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _sanitizePhoneNumber(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool personImage}) async {
    final source = await _pickImageSource();
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      if (personImage) {
        _personImage = picked;
        _personImageBytes = bytes;
      } else {
        _receiptImage = picked;
        _receiptImageBytes = bytes;
      }
    });
  }

  Future<void> _pickFromContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contacts permission is required.')),
      );
      return;
    }

    final contact = await FlutterContacts.openExternalPick();
    if (contact == null || !mounted) return;

    final firstPhone = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : '';
    setState(() {
      _nameController.text = contact.displayName.trim();
      _phoneController.text = _sanitizePhoneNumber(firstPhone);
    });
  }

  String _buildAddOrEditSmsMessage({
    required UdharTransaction transaction,
    required String senderName,
    required bool isEdit,
  }) {
    final dueText = transaction.dueDate != null
        ? ' Due date: ${DateFormat('d MMM yyyy').format(transaction.dueDate!)}.'
        : '';

    if (isEdit) {
      return 'One Room - $senderName: Hi ${transaction.personName}, your Udhar record has been updated. Current amount: Rs.${transaction.remainingAmount.toStringAsFixed(0)}.$dueText';
    }

    if (transaction.type == 'TAKEN') {
      return 'One Room - $senderName: Hi ${transaction.personName}, I have recorded that I borrowed Rs.${transaction.amount.toStringAsFixed(0)} from you.$dueText This message is for record keeping.';
    }

    return 'One Room - $senderName: Hi ${transaction.personName}, I have recorded Rs.${transaction.amount.toStringAsFixed(0)} as Udhar under your name.$dueText Please pay on time.';
  }

  Future<void> _openSmsComposer({
    required String phoneNumber,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messages app.')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser!;
    final fs = FirestoreService();

    try {
      String? personImageUrl = _existingPersonImageUrl;
      String? receiptUrl = _existingReceiptUrl;
      final sanitizedPhone = _phoneController.text.trim().isEmpty
          ? null
          : _sanitizePhoneNumber(_phoneController.text.trim());

      if (_personImage != null) {
        personImageUrl = await fs.uploadUdharPersonImage(
          _personImage!,
          user.uid,
        );
      }
      if (_receiptImage != null) {
        receiptUrl = await fs.uploadUdharReceipt(_receiptImage!, user.uid);
      }

      final amount = double.parse(_amountController.text);
      final interestValue = _interestType == UdharTransaction.interestTypeNone
          ? 0.0
          : (double.tryParse(_interestValueController.text.trim()) ?? 0.0);
      final previousSettled = widget.transactionToEdit?.settledAmount ?? 0.0;

      final draftTransaction = UdharTransaction(
        id: widget.transactionToEdit?.id ?? '',
        userId: user.uid,
        personName: _nameController.text.trim(),
        amount: amount,
        type: _type,
        status: widget.transactionToEdit?.status ?? 'PENDING',
        dueDate: _dueDate,
        createdAt: widget.transactionToEdit?.createdAt ?? DateTime.now(),
        phoneNumber: sanitizedPhone,
        personImageUrl: personImageUrl,
        receiptUrl: receiptUrl,
        interestType: _interestType,
        interestFrequency: _interestFrequency,
        interestValue: interestValue,
        interestStartRule: _interestStartRule,
        settledAmount: previousSettled,
        paymentHistory: widget.transactionToEdit?.paymentHistory ?? const [],
        reminderHistory: widget.transactionToEdit?.reminderHistory ?? const [],
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      final maxAllowedSettled = draftTransaction.totalDue();
      final safeSettled = previousSettled > maxAllowedSettled
          ? maxAllowedSettled
          : previousSettled;

      final transaction = UdharTransaction(
        id: widget.transactionToEdit?.id ?? '',
        userId: user.uid,
        personName: _nameController.text.trim(),
        amount: amount,
        type: _type,
        status: widget.transactionToEdit?.status ?? 'PENDING',
        dueDate: _dueDate,
        createdAt: widget.transactionToEdit?.createdAt ?? DateTime.now(),
        phoneNumber: sanitizedPhone,
        personImageUrl: personImageUrl,
        receiptUrl: receiptUrl,
        interestType: _interestType,
        interestFrequency: _interestFrequency,
        interestValue: interestValue,
        interestStartRule: _interestStartRule,
        settledAmount: safeSettled,
        paymentHistory: widget.transactionToEdit?.paymentHistory ?? const [],
        reminderHistory: widget.transactionToEdit?.reminderHistory ?? const [],
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final isEdit = widget.transactionToEdit != null;
      if (!isEdit) {
        await fs.addUdhar(user.uid, transaction);
      } else {
        await fs.updateUdhar(user.uid, transaction);
      }

      final shouldOpenSmsAfterSave =
          sanitizedPhone != null &&
          sanitizedPhone.isNotEmpty &&
          (!isEdit ? _openSmsAfterSave : true);

      // ignore: use_build_context_synchronously
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final senderName =
          (authProvider.profile?.displayName?.trim().isNotEmpty == true
              ? authProvider.profile!.displayName!
              : authProvider.firebaseUser?.displayName?.trim()) ??
          'Someone';

      if (mounted) Navigator.pop(context);

      if (shouldOpenSmsAfterSave) {
        await _openSmsComposer(
          phoneNumber: sanitizedPhone,
          message: _buildAddOrEditSmsMessage(
            transaction: transaction,
            senderName: senderName,
            isEdit: isEdit,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeTypeColor = _type == 'GIVEN' ? cs.primary : cs.secondary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.transactionToEdit == null
                          ? 'Add Udhar'
                          : 'Edit Udhar',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => _pickImage(personImage: true),
                  child: Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: cs.primary.withValues(alpha: 0.12),
                          backgroundImage: _personImageBytes != null
                              ? MemoryImage(_personImageBytes!)
                              : (_existingPersonImageUrl != null
                                    ? NetworkImage(_existingPersonImageUrl!)
                                    : null),
                          child:
                              _personImageBytes == null &&
                                  _existingPersonImageUrl == null
                              ? Icon(
                                  Icons.person_outline_rounded,
                                  size: 30,
                                  color: cs.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add person photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'GIVEN'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _type == 'GIVEN'
                                ? cs.primary
                                : cs.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_outward_rounded,
                                color: _type == 'GIVEN'
                                    ? Colors.white
                                    : cs.primary,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'I Gave',
                                style: TextStyle(
                                  color: _type == 'GIVEN'
                                      ? Colors.white
                                      : cs.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '(To Receive)',
                                style: TextStyle(
                                  color: _type == 'GIVEN'
                                      ? Colors.white.withValues(alpha: 0.82)
                                      : cs.primary.withValues(alpha: 0.82),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'TAKEN'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _type == 'TAKEN'
                                ? cs.secondary
                                : cs.secondary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: _type == 'TAKEN'
                                    ? Colors.white
                                    : cs.secondary,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'I Took',
                                style: TextStyle(
                                  color: _type == 'TAKEN'
                                      ? Colors.white
                                      : cs.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '(To Pay)',
                                style: TextStyle(
                                  color: _type == 'TAKEN'
                                      ? Colors.white.withValues(alpha: 0.82)
                                      : cs.secondary.withValues(alpha: 0.82),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Person Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Pick from contacts',
                      onPressed: _pickFromContacts,
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: Icon(Icons.contacts_rounded, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Principal Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.26),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interest Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('No interest'),
                            selected:
                                _interestType ==
                                UdharTransaction.interestTypeNone,
                            onSelected: (_) {
                              setState(() {
                                _interestType =
                                    UdharTransaction.interestTypeNone;
                                _interestValueController.clear();
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('% interest'),
                            selected:
                                _interestType ==
                                UdharTransaction.interestTypePercent,
                            onSelected: (_) {
                              setState(() {
                                _interestType =
                                    UdharTransaction.interestTypePercent;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Fixed extra'),
                            selected:
                                _interestType ==
                                UdharTransaction.interestTypeFixed,
                            onSelected: (_) {
                              setState(() {
                                _interestType =
                                    UdharTransaction.interestTypeFixed;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_interestType !=
                          UdharTransaction.interestTypeNone) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Per day'),
                              selected:
                                  _interestFrequency ==
                                  UdharTransaction.interestFrequencyDaily,
                              onSelected: (_) {
                                setState(() {
                                  _interestFrequency =
                                      UdharTransaction.interestFrequencyDaily;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Per month'),
                              selected:
                                  _interestFrequency ==
                                  UdharTransaction.interestFrequencyMonthly,
                              onSelected: (_) {
                                setState(() {
                                  _interestFrequency =
                                      UdharTransaction.interestFrequencyMonthly;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Interest Starts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('From lending date'),
                              selected:
                                  _interestStartRule ==
                                  UdharTransaction.interestStartFromCreated,
                              onSelected: (_) {
                                setState(() {
                                  _interestStartRule =
                                      UdharTransaction.interestStartFromCreated;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('After due date'),
                              selected:
                                  _interestStartRule ==
                                  UdharTransaction.interestStartFromDueDate,
                              onSelected: (_) {
                                setState(() {
                                  _interestStartRule =
                                      UdharTransaction.interestStartFromDueDate;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _interestValueController,
                          decoration: InputDecoration(
                            labelText:
                                _interestType ==
                                    UdharTransaction.interestTypePercent
                                ? 'Interest Rate (%)'
                                : 'Extra Amount (₹)',
                            prefixIcon: Icon(
                              _interestType ==
                                      UdharTransaction.interestTypePercent
                                  ? Icons.percent_rounded
                                  : Icons.add_card_rounded,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (val) {
                            if (_interestType ==
                                UdharTransaction.interestTypeNone) {
                              return null;
                            }
                            final parsed = double.tryParse(val?.trim() ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter valid interest';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _interestType == UdharTransaction.interestTypePercent
                              ? 'Example: 1% per day on ₹300 gives ₹3 extra every day.'
                              : 'Example: fixed extra amount is added every ${_interestFrequency == UdharTransaction.interestFrequencyMonthly ? 'month' : 'day'}.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _interestStartRule ==
                                  UdharTransaction.interestStartFromDueDate
                              ? 'Interest will start only after the due date passes.'
                              : 'Interest will start counting from the lending date.',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Due Date (Optional)',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _dueDate != null
                                  ? DateFormat('MMM d, yyyy').format(_dueDate!)
                                  : 'Tap to set a due date',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: _dueDate != null
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_dueDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _dueDate = null),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
                if (widget.transactionToEdit == null) ...[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _openSmsAfterSave,
                    onChanged: (value) {
                      setState(() => _openSmsAfterSave = value);
                    },
                    title: const Text('Open SMS after save'),
                    subtitle: const Text(
                      'On iPhone this opens the Messages app with a prefilled message.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _pickImage(personImage: false),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                            image: _receiptImageBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_receiptImageBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (_existingReceiptUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            _existingReceiptUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                          ),
                          child:
                              _receiptImageBytes == null &&
                                  _existingReceiptUrl == null
                              ? Icon(
                                  Icons.receipt_long_outlined,
                                  color: cs.primary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipt / Proof Image',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _receiptImageBytes == null &&
                                        _existingReceiptUrl == null
                                    ? 'Tap to upload image'
                                    : 'Tap to replace image',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_receiptImageBytes != null ||
                            _existingReceiptUrl != null)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _receiptImage = null;
                                _receiptImageBytes = null;
                                _existingReceiptUrl = null;
                              });
                            },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: cs.error,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: activeTypeColor,
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
                          widget.transactionToEdit == null
                              ? 'Save Record'
                              : 'Update Record',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
