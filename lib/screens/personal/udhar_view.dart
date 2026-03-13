import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Models/udhar_transaction.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'add_udhar_sheet.dart';

class UdharView extends StatefulWidget {
  const UdharView({super.key});

  @override
  State<UdharView> createState() => _UdharViewState();
}

class _UdharViewState extends State<UdharView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddUdharSheet(BuildContext context, {UdharTransaction? udhar}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddUdharSheet(transactionToEdit: udhar),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, UdharTransaction t) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Udhar Record'),
            content: Text('Delete this record for ${t.personName}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    UdharTransaction t,
  ) async {
    final user = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser!;
    await FirestoreService().deleteUdhar(user.uid, t.id);
    await _sendActionSmsNotification(
      t,
      message: _buildActionSmsMessage(t, action: 'delete'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Udhar record deleted')));
  }

  String _formatTimeLeft(DateTime dueDate) {
    final now = DateTime.now();
    final diff = dueDate.difference(now);

    if (diff.inSeconds >= 0) {
      if (diff.inDays >= 1) {
        final days = diff.inDays;
        return days == 1 ? '1 day remaining' : '$days days remaining';
      }
      if (diff.inHours >= 1) {
        final hours = diff.inHours;
        return hours == 1 ? '1 hour remaining' : '$hours hours remaining';
      }
      final minutes = diff.inMinutes <= 0 ? 1 : diff.inMinutes;
      return minutes == 1 ? '1 minute remaining' : '$minutes minutes remaining';
    }

    final overdue = now.difference(dueDate);
    if (overdue.inDays >= 1) {
      final days = overdue.inDays;
      return days == 1 ? 'overdue by 1 day' : 'overdue by $days days';
    }
    if (overdue.inHours >= 1) {
      final hours = overdue.inHours;
      return hours == 1 ? 'overdue by 1 hour' : 'overdue by $hours hours';
    }
    final minutes = overdue.inMinutes <= 0 ? 1 : overdue.inMinutes;
    return minutes == 1 ? 'overdue by 1 minute' : 'overdue by $minutes minutes';
  }

  String _getSenderName() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return (auth.profile?.displayName?.trim().isNotEmpty == true
            ? auth.profile!.displayName!
            : auth.firebaseUser?.displayName?.trim()) ??
        'Someone';
  }

  String _buildActionSmsMessage(
    UdharTransaction t, {
    required String action,
    double? amount,
    double? remaining,
  }) {
    final senderName = _getSenderName();
    final dueText = t.dueDate != null
        ? ' Due date: ${DateFormat('d MMM yyyy').format(t.dueDate!)}.'
        : '';

    if (action == 'delete') {
      return 'One Room - $senderName: Hi ${t.personName}, your Udhar record has been removed from my list. If needed, we can add a corrected entry again.';
    }

    if (action == 'settle_full') {
      return 'One Room - $senderName: Hi ${t.personName}, I have marked your Udhar as fully settled. Paid amount: Rs.${(amount ?? 0).toStringAsFixed(0)}. Remaining: Rs.0. Thank you.';
    }

    if (action == 'settle_partial') {
      return 'One Room - $senderName: Hi ${t.personName}, I recorded a partial payment of Rs.${(amount ?? 0).toStringAsFixed(0)}. Remaining amount: Rs.${(remaining ?? 0).toStringAsFixed(0)}.';
    }

    return 'One Room - $senderName: Udhar record updated for ${t.personName}. Current amount: Rs.${t.remainingAmount.toStringAsFixed(0)}.$dueText';
  }

  Future<void> _sendActionSmsNotification(
    UdharTransaction t, {
    required String message,
  }) async {
    final phone = t.phoneNumber?.trim() ?? '';
    if (phone.isEmpty) return;

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open SMS app for notification.'),
        ),
      );
    }
  }

  String _buildReminderMessage(UdharTransaction t) {
    final senderName = _getSenderName();
    final amount = t.remainingAmount.toStringAsFixed(0);
    final accruedInterest = t.accruedInterest();
    final amountBreakdown = t.hasInterest
        ? 'This includes principal ₹${t.amount.toStringAsFixed(0)} and accrued interest ₹${accruedInterest.toStringAsFixed(0)} (${t.interestLabel}, ${t.interestStartLabel.toLowerCase()}). '
        : '';

    // For "I Took" (debt) type — professional apology/commitment tone
    if (t.type == 'TAKEN') {
      if (t.dueDate == null) {
        return 'One Room reminder from $senderName: Hi, I acknowledge the amount of ₹$amount that I borrowed from you. $amountBreakdown I am committed to returning this to you as soon as possible. Thank you for your understanding. — $senderName';
      }

      final dueDate = t.dueDate!;
      final dueText = DateFormat('d MMM yyyy').format(dueDate);
      final isOverdue = dueDate.isBefore(DateTime.now());

      if (isOverdue) {
        final timeLeftText = _formatTimeLeft(dueDate);
        return 'One Room reminder from $senderName: Hi, I sincerely apologize for the delay. ₹$amount was due on $dueText and is $timeLeftText. $amountBreakdown I assure you I will return this amount at the earliest. — $senderName';
      }

      final timeLeftText = _formatTimeLeft(dueDate);
      return 'One Room reminder from $senderName: Hi, this is a confirmation that I will return ₹$amount to you by $dueText ($timeLeftText). $amountBreakdown I appreciate your trust. — $senderName';
    }

    // For "I Gave" (credit) type — collection tone
    if (t.dueDate == null) {
      return 'One Room reminder from $senderName: Hi, a gentle reminder that ₹$amount is pending from you. $amountBreakdown Please make the payment at your earliest convenience. — $senderName';
    }

    final dueDate = t.dueDate!;
    final dueText = DateFormat('d MMM yyyy').format(dueDate);
    final timeLeftText = _formatTimeLeft(dueDate);
    final isOverdue = dueDate.isBefore(DateTime.now());

    if (isOverdue) {
      return 'One Room reminder from $senderName: Hi, ₹$amount was due on $dueText and is $timeLeftText. $amountBreakdown Please settle this at the earliest. — $senderName';
    }

    return 'One Room reminder from $senderName: Hi, ₹$amount is due on $dueText ($timeLeftText). $amountBreakdown Kindly ensure payment by the due date. — $senderName';
  }

  Future<void> _updateReminderHistory(
    BuildContext context,
    UdharTransaction t,
    List<UdharReminderRecord> reminderHistory,
  ) async {
    final user = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser!;
    final updated = t.copyWith(reminderHistory: reminderHistory);
    await FirestoreService().updateUdhar(user.uid, updated);
  }

  Future<DateTime?> _pickReminderDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return null;

    if (!context.mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 10))),
    );
    if (pickedTime == null) return null;

    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (dateTime.isBefore(now)) return null;
    return dateTime;
  }

  Future<void> _sendSmsReminderNow(
    BuildContext context,
    UdharTransaction t, {
    required String message,
    String? reminderId,
  }) async {
    final phone = t.phoneNumber?.trim() ?? '';
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Add phone number first to send SMS.')),
      );
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        this.context,
      ).showSnackBar(const SnackBar(content: Text('Could not open SMS app.')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(
        content: Text(
          'Messages app opened. iPhone requires you to tap Send there.',
        ),
      ),
    );

    final now = DateTime.now();
    final updatedHistory = [...t.reminderHistory];
    final index = reminderId == null
        ? -1
        : updatedHistory.indexWhere((e) => e.id == reminderId);

    if (index >= 0) {
      updatedHistory[index] = updatedHistory[index].copyWith(
        isSent: true,
        sentAt: now,
      );
    } else {
      updatedHistory.add(
        UdharReminderRecord(
          id: now.microsecondsSinceEpoch.toString(),
          remindAt: now,
          message: message,
          isSent: true,
          sentAt: now,
        ),
      );
    }

    if (!mounted) return;
    await _updateReminderHistory(this.context, t, updatedHistory);
  }

  Future<void> _scheduleReminder(
    BuildContext context,
    UdharTransaction t,
  ) async {
    final picked = await _pickReminderDateTime(context);
    if (picked == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Pick a valid future date and time.')),
      );
      return;
    }

    final updated = [
      ...t.reminderHistory,
      UdharReminderRecord(
        id: picked.microsecondsSinceEpoch.toString(),
        remindAt: picked,
        message: _buildReminderMessage(t),
      ),
    ];

    if (!mounted) return;
    await _updateReminderHistory(this.context, t, updated);
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder scheduled for ${DateFormat('d MMM, h:mm a').format(picked)}',
        ),
      ),
    );
  }

  Future<void> _showReminderSheet(
    BuildContext context,
    UdharTransaction t,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final reminders = [...t.reminderHistory]
          ..sort((a, b) => b.remindAt.compareTo(a.remindAt));

        final messageController = TextEditingController(
          text: _buildReminderMessage(t),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminders for ${t.personName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Message Preview:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Edit message if needed',
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (!context.mounted) return;
                            await _scheduleReminder(context, t);
                          },
                          icon: const Icon(Icons.schedule_rounded),
                          label: const Text('Schedule'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            if (!context.mounted) return;
                            await _sendSmsReminderNow(
                              context,
                              t,
                              message: messageController.text,
                            );
                          },
                          icon: const Icon(Icons.sms_rounded),
                          label: const Text('Open SMS'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Scheduled / Sent',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: reminders.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('No reminders yet'),
                          )
                        : ListView.builder(
                            itemCount: reminders.length,
                            itemBuilder: (_, i) {
                              final r = reminders[i];
                              final isDue =
                                  !r.isSent &&
                                  r.remindAt.isBefore(DateTime.now());

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  DateFormat(
                                    'd MMM, h:mm a',
                                  ).format(r.remindAt),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDue ? Colors.red : null,
                                  ),
                                ),
                                subtitle: Text(
                                  r.isSent
                                      ? 'Sent ${r.sentAt != null ? DateFormat('d MMM, h:mm a').format(r.sentAt!) : ''}'
                                      : (isDue ? 'Due now' : 'Scheduled'),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!r.isSent)
                                      IconButton(
                                        onPressed: () async {
                                          Navigator.of(ctx).pop();
                                          if (!context.mounted) return;
                                          await _sendSmsReminderNow(
                                            context,
                                            t,
                                            message: r.message,
                                            reminderId: r.id,
                                          );
                                        },
                                        icon: const Icon(Icons.send_rounded),
                                      ),
                                    IconButton(
                                      onPressed: () async {
                                        final updated = t.reminderHistory
                                            .where((e) => e.id != r.id)
                                            .toList();
                                        Navigator.of(ctx).pop();
                                        if (!context.mounted) return;
                                        await _updateReminderHistory(
                                          context,
                                          t,
                                          updated,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPaymentHistorySheet(
    BuildContext context,
    UdharTransaction t,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final payments = [...t.paymentHistory]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment record for ${t.personName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every partial and full payment is listed here.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HistorySummaryItem(
                          label: 'Principal',
                          value: '₹${t.amount.toStringAsFixed(0)}',
                        ),
                      ),
                      Expanded(
                        child: _HistorySummaryItem(
                          label: 'Paid',
                          value: '₹${t.settledAmount.toStringAsFixed(0)}',
                          valueColor: Colors.green[700],
                        ),
                      ),
                      Expanded(
                        child: _HistorySummaryItem(
                          label: 'Left',
                          value: '₹${t.remainingAmount.toStringAsFixed(0)}',
                          valueColor: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Transactions',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: payments.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No payment transactions yet'),
                        )
                      : ListView.separated(
                          itemCount: payments.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final payment = payments[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.green.withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  '#${payments.length - i}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Paid ₹${payment.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${DateFormat('d MMM yyyy, h:mm a').format(payment.recordedAt)}\nRemaining after payment: ₹${payment.remainingAfter.toStringAsFixed(0)}',
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _recordSettlement(
    BuildContext context,
    UdharTransaction t,
    double amount,
  ) async {
    if (amount <= 0) return;

    final remaining = t.remainingAmount;
    if (remaining <= 0.0) return;

    final user = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser!;
    final appliedAmount = amount > remaining ? remaining : amount;
    final newSettled = t.settledAmount + appliedAmount;
    final totalDueNow = t.totalDue();
    final newRemaining = (totalDueNow - newSettled) < 0
        ? 0.0
        : (totalDueNow - newSettled);
    final isFullySettled = newRemaining <= 0.01;

    final updatedHistory = [
      ...t.paymentHistory,
      UdharPaymentRecord(
        amount: appliedAmount,
        remainingAfter: isFullySettled ? 0.0 : newRemaining,
        recordedAt: DateTime.now(),
      ),
    ];

    final updated = t.copyWith(
      settledAmount: isFullySettled ? totalDueNow : newSettled,
      status: isFullySettled
          ? (t.type == 'GIVEN' ? 'RECEIVED' : 'PAID')
          : 'PENDING',
      paymentHistory: updatedHistory,
    );

    await FirestoreService().updateUdhar(user.uid, updated);
    await _sendActionSmsNotification(
      t,
      message: _buildActionSmsMessage(
        t,
        action: isFullySettled ? 'settle_full' : 'settle_partial',
        amount: appliedAmount,
        remaining: newRemaining,
      ),
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFullySettled
              ? 'Payment settled fully'
              : 'Recorded ₹${appliedAmount.toStringAsFixed(0)}, left ₹${newRemaining.toStringAsFixed(0)}',
        ),
      ),
    );
  }

  Future<void> _showPartialAmountDialog(
    BuildContext context,
    UdharTransaction t,
  ) async {
    final remaining = t.remainingAmount;
    if (remaining <= 0.0) return;
    final accruedInterest = t.accruedInterest();
    final totalDueNow = t.totalDue();

    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          t.type == 'GIVEN' ? 'Record Partial Received' : 'Record Partial Paid',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Principal: ₹${t.amount.toStringAsFixed(0)}'),
            if (t.hasInterest)
              Text(
                'Accrued interest: ₹${accruedInterest.toStringAsFixed(0)} (${t.interestLabel})',
              ),
            Text('Total due now: ₹${totalDueNow.toStringAsFixed(0)}'),
            Text('Already settled: ₹${t.settledAmount.toStringAsFixed(0)}'),
            Text('Remaining: ₹${remaining.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'How much amount received now?',
                prefixText: '₹',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.trim()) ?? 0;
              if (value <= 0 || value > remaining) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enter a valid amount between 1 and ₹${remaining.toStringAsFixed(0)}',
                    ),
                  ),
                );
                return;
              }

              Navigator.of(ctx).pop();
              if (!context.mounted) return;
              await _recordSettlement(context, t, value);
            },
            child: const Text('Save Partial'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettlementDialog(
    BuildContext context,
    UdharTransaction t,
  ) async {
    final remaining = t.remainingAmount;
    if (remaining <= 0.0) return;
    final accruedInterest = t.accruedInterest();
    final totalDueNow = t.totalDue();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.type == 'GIVEN' ? 'Record Payment' : 'Record Repayment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Principal: ₹${t.amount.toStringAsFixed(0)}'),
            if (t.hasInterest)
              Text(
                'Accrued interest: ₹${accruedInterest.toStringAsFixed(0)} (${t.interestLabel})',
              ),
            Text('Total due now: ₹${totalDueNow.toStringAsFixed(0)}'),
            Text('Already settled: ₹${t.settledAmount.toStringAsFixed(0)}'),
            Text('Remaining: ₹${remaining.toStringAsFixed(0)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (!context.mounted) return;
              await _showPartialAmountDialog(context, t);
            },
            child: const Text('Partial Paid'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (!context.mounted) return;
              await _recordSettlement(context, t, remaining);
            },
            child: const Text('Settle Full'),
          ),
        ],
      ),
    );
  }

  Future<void> _callPhone(BuildContext context, String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 220,
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: const Text('Failed to load image'),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).firebaseUser!;
    final fs = FirestoreService();
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<UdharTransaction>>(
      stream: fs.streamUdharTransactions(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allTransactions = snapshot.data ?? [];
        final pendingGiven = allTransactions
            .where((u) => u.type == 'GIVEN' && u.status == 'PENDING')
            .toList();
        final pendingTaken = allTransactions
            .where((u) => u.type == 'TAKEN' && u.status == 'PENDING')
            .toList();
        final historyList = allTransactions
            .where((u) => u.status != 'PENDING')
            .toList();

        final totalToReceive = pendingGiven.fold(
          0.0,
          (sum, item) => sum + item.remainingAmount,
        );
        final totalToPay = pendingTaken.fold(
          0.0,
          (sum, item) => sum + item.remainingAmount,
        );
        final netBalance = totalToReceive - totalToPay;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.secondary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryItem(
                      label: 'To Receive',
                      amount: totalToReceive,
                      icon: Icons.arrow_downward_rounded,
                      color: Colors.white,
                    ),
                    VerticalDivider(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _SummaryItem(
                      label: 'To Pay',
                      amount: totalToPay,
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.white,
                    ),
                    VerticalDivider(
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    _SummaryItem(
                      label: 'Net Balance',
                      amount: netBalance.abs(),
                      prefix: netBalance >= 0 ? '+' : '-',
                      icon: Icons.account_balance_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 46,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.all(3),
                tabs: const [
                  Tab(text: 'To Receive'),
                  Tab(text: 'To Pay'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(
                    context,
                    list: pendingGiven,
                    accentColor: cs.primary,
                    emptyMessage: 'No pending amounts to receive',
                    tabId: 'receive',
                  ),
                  _buildList(
                    context,
                    list: pendingTaken,
                    accentColor: cs.secondary,
                    emptyMessage: 'No pending amounts to pay',
                    tabId: 'pay',
                  ),
                  _buildList(
                    context,
                    list: historyList,
                    accentColor: cs.tertiary,
                    emptyMessage: 'No settled history yet',
                    tabId: 'history',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context, {
    required List<UdharTransaction> list,
    required Color accentColor,
    required String emptyMessage,
    required String tabId,
  }) {
    final cs = Theme.of(context).colorScheme;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.handshake_rounded,
                size: 38,
                color: cs.primary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = [...list]
      ..sort((a, b) {
        if (tabId == 'history') {
          return b.createdAt.compareTo(a.createdAt);
        }
        return a.dueDate != null && b.dueDate != null
            ? a.dueDate!.compareTo(b.dueDate!)
            : b.createdAt.compareTo(a.createdAt);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final t = sorted[i];
        final isCompleted = t.status != 'PENDING';

        return Dismissible(
          key: ValueKey('${t.id}_$tabId'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                SizedBox(height: 4),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) => _confirmDelete(context, t),
          onDismissed: (_) => _deleteTransaction(context, t),
          child: _UdharCard(
            transaction: t,
            accentColor: accentColor,
            isCompleted: isCompleted,
            onTap: () => _showAddUdharSheet(context, udhar: t),
            onViewPaymentHistory: t.paymentHistory.isEmpty
                ? null
                : () => _showPaymentHistorySheet(context, t),
            onDelete: () async {
              final confirmed = await _confirmDelete(context, t);
              if (!confirmed) return;
              if (!context.mounted) return;
              await _deleteTransaction(context, t);
            },
            onMarkSettled: isCompleted
                ? null
                : () async {
                    await _showSettlementDialog(context, t);
                  },
            onCall: t.phoneNumber != null && t.phoneNumber!.isNotEmpty
                ? () => _callPhone(context, t.phoneNumber!)
                : null,
            onOpenReceipt: t.receiptUrl != null && t.receiptUrl!.isNotEmpty
                ? () => _showImagePreview(context, t.receiptUrl!)
                : null,
            onReminder: () => _showReminderSheet(context, t),
            pendingReminders: t.reminderHistory.where((r) => !r.isSent).length,
          ),
        );
      },
    );
  }
}

class _UdharCard extends StatelessWidget {
  final UdharTransaction transaction;
  final Color accentColor;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback? onViewPaymentHistory;
  final VoidCallback onDelete;
  final VoidCallback? onMarkSettled;
  final VoidCallback? onCall;
  final VoidCallback? onOpenReceipt;
  final VoidCallback onReminder;
  final int pendingReminders;

  const _UdharCard({
    required this.transaction,
    required this.accentColor,
    required this.isCompleted,
    required this.onTap,
    this.onViewPaymentHistory,
    required this.onDelete,
    this.onMarkSettled,
    this.onCall,
    this.onOpenReceipt,
    required this.onReminder,
    required this.pendingReminders,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = transaction.personName.isNotEmpty
        ? transaction.personName[0].toUpperCase()
        : '?';
    final displayAmount = isCompleted
        ? transaction.settledAmount
        : transaction.remainingAmount;
    final latestPayment = transaction.paymentHistory.isNotEmpty
        ? transaction.paymentHistory.last
        : null;
    final accruedInterest = transaction.accruedInterest();
    final totalDue = transaction.totalDue();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCompleted ? cs.surfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isCompleted
                ? cs.outline.withValues(alpha: 0.4)
                : accentColor.withValues(alpha: 0.9),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accentColor.withValues(alpha: 0.14),
                    backgroundImage:
                        transaction.personImageUrl != null &&
                            transaction.personImageUrl!.isNotEmpty
                        ? NetworkImage(transaction.personImageUrl!)
                        : null,
                    child:
                        transaction.personImageUrl == null ||
                            transaction.personImageUrl!.isEmpty
                        ? Text(
                            initials,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.personName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                          ),
                        ),
                        if (transaction.phoneNumber != null &&
                            transaction.phoneNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: GestureDetector(
                              onTap: onCall,
                              child: Text(
                                transaction.phoneNumber!,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        if (transaction.dueDate != null && !isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color:
                                      transaction.dueDate!.isBefore(
                                        DateTime.now(),
                                      )
                                      ? Colors.red
                                      : Colors.orange[800],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Due: ${DateFormat('MMM d').format(transaction.dueDate!)}',
                                  style: TextStyle(
                                    color:
                                        transaction.dueDate!.isBefore(
                                          DateTime.now(),
                                        )
                                        ? Colors.red
                                        : Colors.orange[800],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (transaction.notes?.isNotEmpty ?? false)
                          Text(
                            transaction.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (transaction.hasInterest)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Principal: ₹${transaction.amount.toStringAsFixed(0)} | Interest: ₹${accruedInterest.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.deepPurple[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (transaction.hasInterest)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Rule: ${transaction.interestLabel} | ${transaction.interestStartLabel} | Due now: ₹${totalDue.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (!isCompleted && transaction.settledAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Paid: ₹${transaction.settledAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (latestPayment != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Last: ₹${latestPayment.amount.toStringAsFixed(0)} on ${DateFormat('d MMM, h:mm a').format(latestPayment.recordedAt)} | Left: ₹${latestPayment.remainingAfter.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                if (onViewPaymentHistory != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: InkWell(
                                      onTap: onViewPaymentHistory,
                                      child: Text(
                                        'View all ${transaction.paymentHistory.length} payment records',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (latestPayment == null &&
                            onViewPaymentHistory != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: InkWell(
                              onTap: onViewPaymentHistory,
                              child: Text(
                                'View payment records',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${displayAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isCompleted ? Colors.green : accentColor)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCompleted
                              ? 'Settled'
                              : (transaction.type == 'GIVEN'
                                    ? 'Pending'
                                    : 'To Pay'),
                          style: TextStyle(
                            fontSize: 10,
                            color: isCompleted ? Colors.green : accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: onReminder,
                        tooltip: 'Reminders',
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: Colors.deepPurple,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (pendingReminders > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              pendingReminders > 9
                                  ? '9+'
                                  : pendingReminders.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (onOpenReceipt != null)
                    IconButton(
                      onPressed: onOpenReceipt,
                      icon: const Icon(
                        Icons.receipt_long_rounded,
                        size: 18,
                        color: Colors.blueGrey,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (onMarkSettled != null)
                    IconButton(
                      onPressed: onMarkSettled,
                      tooltip: 'Settle payment',
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.green,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _HistorySummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final String prefix;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.amount,
    this.prefix = '',
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$prefix₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}
