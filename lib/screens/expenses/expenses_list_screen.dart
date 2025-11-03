import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/firestore_service.dart';
import '../../Models/expense.dart';
import '../../widgets/expense_card.dart';
import '../../constants.dart';
import 'enhanced_modern_expense_screen.dart';
import 'expense_audit_log_screen.dart';
import 'expense_detail_popup.dart';
import 'balances_screen.dart';
import '../../providers/auth_provider.dart';

class ExpensesListScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ExpensesListScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  String? _selectedCategory; // null = All

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final uid = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.roomName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Audit Log Button
          IconButton(
            tooltip: 'Activity Log',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseAuditLogScreen(roomId: widget.roomId),
                ),
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Balances',
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BalancesScreen(roomId: widget.roomId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: fs.expensesForRoom(widget.roomId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? [];
          final allExpenses = data
              .map((m) => Expense.fromMap(m, m['id']))
              .toList();

          double total = 0;
          for (final e in allExpenses) {
            total += e.amount;
          }

          // Filter by category if selected
          final expenses = _selectedCategory == null
              ? allExpenses
              : allExpenses
                    .where((e) => (e.category) == _selectedCategory)
                    .toList();

          return Column(
            children: [
              // Modern Total Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.currencySymbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          total.toStringAsFixed(2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Category filter chips
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Row(
                          children: [
                            Icon(Icons.all_inclusive, size: 16),
                            SizedBox(width: 4),
                            Text('All'),
                          ],
                        ),
                        selected: _selectedCategory == null,
                        onSelected: (_) {
                          setState(() => _selectedCategory = null);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    ...ExpenseCategory.categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('${cat.icon} ${cat.name}'),
                          selected: _selectedCategory == cat.name,
                          onSelected: (sel) {
                            setState(
                              () => _selectedCategory = sel ? cat.name : null,
                            );
                          },
                          backgroundColor: Colors.white,
                          selectedColor: Color(
                            cat.colorValue,
                          ).withValues(alpha: 0.2),
                          checkmarkColor: Color(cat.colorValue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No expenses yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first expense',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: expenses.length,
                        itemBuilder: (context, i) {
                          final e = expenses[i];
                          return ExpenseCard(
                            expense: e,
                            currentUserUid: uid,
                            highlightIfPaidByMe: true,
                            onTap: () => _showExpenseDetailPopup(context, e),
                            onDelete: () async {
                              await fs.deleteExpense(widget.roomId, e.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EnhancedModernExpenseScreen(roomId: widget.roomId),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Expense'),
        elevation: 8,
      ),
    );
  }

  void _showExpenseDetailPopup(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            ExpenseDetailPopup(expense: expense, roomId: widget.roomId),
      ),
    ).then((result) {
      // Refresh if expense was edited
      if (result == true) {
        setState(() {});
      }
    });
  }
}
