// lib/widgets/expense_card.dart
import 'package:flutter/material.dart';
import '../Models/expense.dart';
import '../utils/formatters.dart';
import '../services/firestore_service.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final bool highlightIfPaidByMe;
  final String? currentUserUid;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static final Map<String, String> _nameCache = {};

  const ExpenseCard({
    super.key,
    required this.expense,
    this.highlightIfPaidByMe = false,
    this.currentUserUid,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Expense model no longer carries paidByName; display uid or resolve name upstream
    final paidByUid = expense.paidBy;
    final dateText = Formatters.formatDateTime(expense.createdAt);
    final amountText = Formatters.formatCurrency(expense.amount);

    final paidByMe = currentUserUid != null && currentUserUid == paidByUid;
    final category = ExpenseCategory.getCategory(expense.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category icon with gradient background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(category.colorValue),
                        Color(category.colorValue).withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Color(
                          category.colorValue,
                        ).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            paidByMe
                                ? Icons.account_circle
                                : Icons.person_outline,
                            size: 14,
                            color: paidByMe
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: paidByMe
                                ? Text(
                                    'You paid',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : _PaidByName(uid: paidByUid),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Amount and actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: paidByMe
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        amountText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: paidByMe
                              ? Theme.of(context).colorScheme.primary
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaidByName extends StatefulWidget {
  final String uid;
  const _PaidByName({required this.uid});

  @override
  State<_PaidByName> createState() => _PaidByNameState();
}

class _PaidByNameState extends State<_PaidByName> {
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Use cache if available
    final cached = ExpenseCard._nameCache[widget.uid];
    if (cached != null) {
      _name = cached;
      _loading = false;
    } else {
      FirestoreService().getUserDisplayName(widget.uid).then((value) {
        if (!mounted) return;
        setState(() {
          _name = value ?? _shortUid(widget.uid);
          ExpenseCard._nameCache[widget.uid] = _name!;
          _loading = false;
        });
      });
    }
  }

  String _shortUid(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 6)}...${uid.substring(uid.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = _loading
        ? _shortUid(widget.uid)
        : (_name ?? _shortUid(widget.uid));
    return Text(
      'Paid by: $text',
      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}
