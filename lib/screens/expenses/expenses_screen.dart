// lib/screens/expenses/expenses_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Models/expense.dart';
import '../../services/firestore_service.dart';
import 'add_expense_sheet.dart';
import 'expense_detail_screen.dart';
import 'balances_screen.dart';

class ExpensesScreen extends StatefulWidget {
  final String roomId;

  const ExpensesScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BalancesScreen(roomId: widget.roomId),
                ),
              );
            },
            tooltip: 'View Balances',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...ExpenseCategory.categories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text('${cat.icon} ${cat.name}'),
                            selected: _selectedCategory == cat.name,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? cat.name : null;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expenses List
          Expanded(
            child: StreamBuilder<List<Expense>>(
              stream: firestoreService.getExpensesStream(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final expenses = snapshot.data ?? [];

                // Filter expenses
                final filteredExpenses = expenses.where((expense) {
                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      expense.description.toLowerCase().contains(
                        _searchQuery,
                      ) ||
                      (expense.notes?.toLowerCase().contains(_searchQuery) ??
                          false);

                  final matchesCategory =
                      _selectedCategory == null ||
                      expense.category == _selectedCategory;

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredExpenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          expenses.isEmpty
                              ? 'No expenses yet'
                              : 'No expenses found',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        if (expenses.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to add your first expense',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Group expenses by date
                final groupedExpenses = _groupExpensesByDate(filteredExpenses);

                return ListView.builder(
                  itemCount: groupedExpenses.length,
                  itemBuilder: (context, index) {
                    final entry = groupedExpenses[index];
                    final date = entry['date'] as String;
                    final dayExpenses = entry['expenses'] as List<Expense>;
                    final total = entry['total'] as double;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              Text(
                                '₹${total.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        ...dayExpenses.map(
                          (expense) =>
                              _buildExpenseCard(expense, firestoreService),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddExpenseSheet(roomId: widget.roomId),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense, FirestoreService firestoreService) {
    final category = ExpenseCategory.getCategory(expense.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(category.colorValue).withOpacity(0.2),
          child: Text(category.icon, style: const TextStyle(fontSize: 24)),
        ),
        title: Text(
          expense.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: FutureBuilder<String>(
          future: _formatPayersSubtitle(firestoreService, expense),
          builder: (context, snapshot) {
            final text = snapshot.data ?? 'Paid by —';
            return Text(text);
          },
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (expense.isFullySettled)
              const Text(
                'Settled',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ExpenseDetailScreen(roomId: widget.roomId, expense: expense),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _groupExpensesByDate(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};

    for (var expense in expenses) {
      final dateKey = _formatDate(expense.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(expense);
    }

    return grouped.entries.map((entry) {
      final total = entry.value.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );
      return {'date': entry.key, 'expenses': entry.value, 'total': total};
    }).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Today';
    } else if (expenseDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(expenseDate).inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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

  Future<String> _formatPayersSubtitle(
    FirestoreService firestoreService,
    Expense expense,
  ) async {
    final payers = expense.effectivePayers();
    if (payers.isEmpty) return 'Paid info unavailable';
    if (payers.length == 1) {
      final uid = payers.keys.first;
      final name = await _getUserName(firestoreService, uid);
      return 'Paid by $name';
    }

    // Multiple payers: show top 2 contributors and count of others
    final sorted = payers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(2).toList();
    final othersCount = payers.length - top.length;

    final names = await Future.wait(
      top.map((e) async {
        final name = await _getUserName(firestoreService, e.key);
        return '$name (₹${e.value.toStringAsFixed(0)})';
      }),
    );

    final base = names.join(', ');
    return othersCount > 0
        ? 'Paid by $base + $othersCount more'
        : 'Paid by $base';
  }
}
