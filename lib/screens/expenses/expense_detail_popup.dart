import 'package:flutter/material.dart';
import '../../Models/expense.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import 'add_expense_sheet.dart';
import '../../widgets/safe_web_image.dart';

class ExpenseDetailPopup extends StatelessWidget {
  final Expense expense;
  final String roomId;

  const ExpenseDetailPopup({
    super.key,
    required this.expense,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = ExpenseCategory.getCategory(expense.category);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close and edit buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Expense Details',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _editExpense(context),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon and description
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(category.colorValue),
                                Color(
                                  category.colorValue,
                                ).withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  category.colorValue,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          expense.description,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Formatters.formatCurrency(expense.amount),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Details sections
                  _buildDetailRow(
                    context,
                    Icons.category_rounded,
                    'Category',
                    expense.category,
                  ),
                  _buildDetailRow(
                    context,
                    Icons.calendar_today_rounded,
                    'Purchase Date',
                    Formatters.formatDate(expense.createdAt),
                  ),

                  // Paid by section with user name resolution
                  FutureBuilder<String>(
                    future: _getUserDisplayName(expense.paidBy),
                    builder: (context, snapshot) {
                      return _buildDetailRow(
                        context,
                        Icons.person_rounded,
                        'Paid By',
                        snapshot.data ?? 'Loading...',
                      );
                    },
                  ),

                  // Split among section
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Split Among',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, String>>(
                    future: _getParticipantNames(expense.splitAmong),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final names = snapshot.data!;
                      return Column(
                        children: expense.splitAmong.map((uid) {
                          final name = names[uid] ?? 'Unknown';
                          final split = expense.splits[uid] ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  child: uid.startsWith('guest_')
                                      ? Icon(
                                          Icons.person,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        )
                                      : Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                Text(
                                  Formatters.formatCurrency(split),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  // Notes section
                  if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        expense.notes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],

                  // Receipt image section
                  if (expense.receiptUrl != null &&
                      expense.receiptUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Receipt',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SafeWebImage(
                        expense.receiptUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _getParticipantNames(List<String> uids) async {
    final names = <String, String>{};
    final userUids = <String>[];
    final guestUids = <String>[];

    for (var uid in uids) {
      if (uid.startsWith('guest_')) {
        guestUids.add(uid);
      } else {
        userUids.add(uid);
      }
    }

    // Fetch Users
    if (userUids.isNotEmpty) {
      final profiles = await FirestoreService().getUsersProfiles(userUids);
      for (var uid in userUids) {
        final p = profiles[uid];
        if (p != null) {
          names[uid] =
              p['displayName'] ??
              p['name'] ??
              (p['email'] != null ? (p['email'] as String).split('@')[0] : uid);
        } else {
          names[uid] = uid;
        }
      }
    }

    // Fetch Guests (from Room)
    if (guestUids.isNotEmpty) {
      try {
        final room = await FirestoreService().getRoom(roomId);
        if (room != null && room['guests'] != null) {
          final guests = room['guests'] as Map<String, dynamic>;
          for (var uid in guestUids) {
            if (guests.containsKey(uid)) {
              names[uid] = '${guests[uid]['name']} (Guest)';
            } else {
              names[uid] = 'Guest';
            }
          }
        }
      } catch (_) {}
    }

    // Fill missing
    for (var uid in uids) {
      if (!names.containsKey(uid)) names[uid] = uid;
    }

    return names;
  }

  Future<String> _getUserDisplayName(String uid) async {
    if (uid.startsWith('guest_')) {
      final names = await _getParticipantNames([uid]);
      return names[uid] ?? 'Guest';
    }
    try {
      final profiles = await FirestoreService().getUsersProfiles([uid]);
      final profile = profiles[uid];
      return profile?['displayName'] ??
          profile?['name'] ??
          (profile?['email'] is String
              ? (profile!['email'] as String).split('@')[0]
              : uid);
    } catch (e) {
      return uid;
    }
  }

  Future<void> _editExpense(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(roomId: roomId, expense: expense),
    );

    if (result == true && context.mounted) {
      // Close the popup and refresh parent
      Navigator.pop(context, true);
    }
  }
}
