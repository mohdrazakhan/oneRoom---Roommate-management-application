// lib/screens/expenses/expense_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Models/expense.dart';
import '../../services/firestore_service.dart';
import '../../widgets/safe_web_image.dart';
import 'add_expense_sheet.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final String roomId;
  final Expense expense;

  const ExpenseDetailScreen({
    super.key,
    required this.roomId,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);
    final currentUser = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<Expense?>(
      stream: firestoreService.getExpenseStream(roomId, expense.id),
      initialData: expense,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Expense Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final currentExpense = snapshot.data!;
        final category = ExpenseCategory.getCategory(currentExpense.category);

        return _buildExpenseDetails(
          context,
          firestoreService,
          currentUser,
          currentExpense,
          category,
        );
      },
    );
  }

  Widget _buildExpenseDetails(
    BuildContext context,
    FirestoreService firestoreService,
    User currentUser,
    Expense currentExpense,
    ExpenseCategory category,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    AddExpenseSheet(roomId: roomId, expense: currentExpense),
              );
              if (result == true && context.mounted) {
                Navigator.pop(context); // Go back to refresh the list
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(context, firestoreService),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Receipt image (if available)
          if (currentExpense.receiptUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SafeWebImage(
                currentExpense.receiptUrl!,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 64),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Category and Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(category.colorValue).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${currentExpense.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Description
          _buildInfoRow(
            context,
            'Description',
            currentExpense.description,
            Icons.description,
          ),
          const SizedBox(height: 16),

          // Paid By (multi-payer aware)
          ...(() {
            final payers = currentExpense.effectivePayers();
            if (payers.isEmpty) {
              return [
                _buildInfoRow(context, 'Paid By', 'Unknown', Icons.person),
                const SizedBox(height: 16),
              ];
            }
            return [
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(
                    'Paid By',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: payers.entries.map((entry) {
                    final uid = entry.key;
                    final amount = entry.value;
                    return FutureBuilder<String>(
                      future: _getUserName(firestoreService, uid),
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? 'Loading...';
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text('Paid'),
                          trailing: Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ];
          })(),

          // Date
          _buildInfoRow(
            context,
            'Date',
            _formatDate(currentExpense.createdAt),
            Icons.calendar_today,
          ),

          if (currentExpense.notes != null &&
              currentExpense.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Notes', currentExpense.notes!, Icons.note),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Split details
          Text(
            'Split Details',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ...currentExpense.splits.entries.map((entry) {
            final uid = entry.key;
            final amount = entry.value;
            final isSettled = currentExpense.settledWith[uid] == true;
            final isCurrentUser = uid == currentUser.uid;

            return FutureBuilder<String>(
              future: _getUserName(firestoreService, uid),
              builder: (context, snapshot) {
                final userName = snapshot.data ?? 'Loading...';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(userName[0].toUpperCase()),
                    ),
                    title: Text(userName),
                    subtitle: Text(
                      isSettled ? 'Settled' : 'Pending',
                      style: TextStyle(
                        color: isSettled ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (isCurrentUser && uid != currentExpense.paidBy) ...[
                          const SizedBox(width: 8),
                          if (!isSettled)
                            FilledButton.tonal(
                              onPressed: () => _settleExpense(
                                context,
                                firestoreService,
                                uid,
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Settle'),
                            )
                          else
                            OutlinedButton(
                              onPressed: () => _unsettleExpense(
                                context,
                                firestoreService,
                                uid,
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                foregroundColor: Colors.orange,
                              ),
                              child: const Text('Unsettle'),
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          }),

          const SizedBox(height: 24),

          // Status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: currentExpense.isFullySettled
                  ? Colors.green[50]
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: currentExpense.isFullySettled
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  currentExpense.isFullySettled
                      ? Icons.check_circle
                      : Icons.access_time,
                  color: currentExpense.isFullySettled
                      ? Colors.green
                      : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentExpense.isFullySettled
                            ? 'Fully Settled'
                            : 'Pending Settlement',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: currentExpense.isFullySettled
                              ? Colors.green[900]
                              : Colors.orange[900],
                        ),
                      ),
                      if (!currentExpense.isFullySettled) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_getPendingCount(currentExpense)} members still need to settle',
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _getPendingCount(Expense exp) {
    return exp.splits.entries.where((entry) {
      return exp.settledWith[entry.key] != true;
    }).length;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _getUserName(
    FirestoreService firestoreService,
    String uid,
  ) async {
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

  Future<void> _settleExpense(
    BuildContext context,
    FirestoreService firestoreService,
    String uid,
  ) async {
    try {
      await firestoreService.settleExpense(
        roomId: roomId,
        expenseId: expense.id,
        settlerUid: uid,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense settled successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unsettleExpense(
    BuildContext context,
    FirestoreService firestoreService,
    String uid,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsettle Expense'),
        content: const Text('Are you sure you want to mark this as unsettled?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsettle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await firestoreService.unsettleExpense(
        roomId: roomId,
        expenseId: expense.id,
        settlerUid: uid,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense unsettled successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    FirestoreService firestoreService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await firestoreService.deleteExpense(roomId, expense.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
