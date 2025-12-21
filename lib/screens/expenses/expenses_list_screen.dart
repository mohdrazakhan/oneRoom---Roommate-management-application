import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/firestore_service.dart';
import '../../Models/expense.dart';
import '../../widgets/expense_card.dart';
import '../../constants.dart';
import 'add_expense_sheet.dart';
import 'expense_audit_log_screen.dart';
import 'expense_detail_popup.dart';
import 'balances_screen.dart';
import 'record_payment_screen.dart';
import 'payment_history_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';
import '../../services/expense_export_service.dart';

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
          // Payment History Button
          IconButton(
            tooltip: 'Payment History',
            icon: const Icon(Icons.payments_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentHistoryScreen(roomId: widget.roomId),
                ),
              );
            },
          ),
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
          // Export Button (Premium)
          IconButton(
            tooltip: 'Export Data',
            icon: const Icon(Icons.file_download),
            onPressed: () => _handleExport(context),
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: fs.streamRoomById(widget.roomId),
        builder: (context, roomSnap) {
          final roomData = roomSnap.data;
          List<ExpenseCategory> customCategories = [];

          if (roomData != null) {
            final customCats = roomData['customCategories'] as List<dynamic>?;
            if (customCats != null) {
              customCategories = customCats.map((c) {
                final data = c as Map<String, dynamic>;
                return ExpenseCategory.createCustom(
                  data['name'] ?? 'Custom',
                  data['emoji'] ?? '🏷️',
                );
              }).toList();
            }
          }

          final allCategories = [
            ...ExpenseCategory.categories,
            ...customCategories,
          ];

          return StreamBuilder<List<Map<String, dynamic>>>(
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
                        .where((e) => e.category == _selectedCategory)
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
                            checkmarkColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        ),
                        ...allCategories.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text('${cat.icon} ${cat.name}'),
                              selected: _selectedCategory == cat.name,
                              onSelected: (sel) {
                                setState(
                                  () =>
                                      _selectedCategory = sel ? cat.name : null,
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
                              // Find category object to ensure custom emoji is used
                              final catObj = allCategories.firstWhere(
                                (c) => c.name == e.category,
                                orElse: () => ExpenseCategory(
                                  name: e.category,
                                  icon: '🏷️',
                                  colorValue: 0xFF9E9E9E,
                                ),
                              );

                              return ExpenseCard(
                                expense: e,
                                roomId: widget.roomId,
                                currentUserUid: uid,
                                highlightIfPaidByMe: true,
                                customCategory: catObj,
                                onTap: () =>
                                    _showExpenseDetailPopup(context, e),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showExpenseOptionsMenu(context);
        },
        elevation: 8,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showExpenseOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
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
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_rounded,
                    color: Colors.orange,
                  ),
                ),
                title: const Text(
                  'New Expense',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('A purchase made for the group'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        AddExpenseSheet(roomId: widget.roomId),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Colors.green,
                  ),
                ),
                title: const Text(
                  'Record Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('A payment within the group'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) =>
                          RecordPaymentScreen(roomId: widget.roomId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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

  Future<void> _handleExport(BuildContext context) async {
    final subService = Provider.of<SubscriptionService>(context, listen: false);
    if (!subService.isPremium) {
      Navigator.pushNamed(context, '/subscription');
      return;
    }

    // Show export options
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export Expenses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Export as PDF'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performExport(ctx, isPdf: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Export as Excel'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _performExport(ctx, isPdf: false);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performExport(
    BuildContext context, {
    required bool isPdf,
  }) async {
    // Capture messenger before any async operations
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Show loading
      messenger.showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );

      final fs = FirestoreService();
      // Fetch specifically for export to ensure we have fresh data
      // We use the stream .first to get current snapshot
      final expensesMap = await fs.expensesForRoom(widget.roomId).first;

      final expenses = expensesMap
          .map((m) => Expense.fromMap(m, m['id']))
          .toList();

      if (expenses.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('No expenses to export!')),
        );
        return;
      }

      if (isPdf) {
        await ExpenseExportService.generateAndSharePDF(
          expenses: expenses,
          roomName: widget.roomName,
          currency: '₹', // Default currency
          memberNames: {},
        );
      } else {
        await ExpenseExportService.generateAndShareExcel(
          expenses: expenses,
          roomName: widget.roomName,
          currency: '₹', // Default currency
          memberNames: {},
        );
      }

      // Success handled by Share sheet opening, but we can clear snackbar
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
