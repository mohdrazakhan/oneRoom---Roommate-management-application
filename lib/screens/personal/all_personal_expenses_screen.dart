import 'package:flutter/material.dart';
import '../../Models/personal_expense.dart';
import '../../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart'; // <--- NEW IMPORT
import 'personal_expenses_list_screen.dart'; // To access PersonalExpenseTile and AddPersonalExpenseSheet
import 'add_personal_expense_sheet.dart';

class AllPersonalExpensesScreen extends StatefulWidget {
  const AllPersonalExpensesScreen({super.key});

  @override
  State<AllPersonalExpensesScreen> createState() =>
      _AllPersonalExpensesScreenState();
}

class _AllPersonalExpensesScreenState extends State<AllPersonalExpensesScreen> {
  final FirestoreService _fs = FirestoreService();
  String _searchQuery = '';
  String _sortMode = 'Date (Newest)';

  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Amount (High to Low)',
    'Amount (Low to High)',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.firebaseUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'All Expenses',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // ── SEARCH & SORT BAR ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Search Field
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search expenses...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort Dropdown
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortMode,
                      icon: Icon(
                        Icons.sort_rounded,
                        color: cs.primary,
                        size: 20,
                      ),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      dropdownColor: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      items: _sortOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortMode = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── LIST OF EXPENSES ─────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<PersonalExpense>>(
              stream: _fs.streamPersonalExpenses(user.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<PersonalExpense> expenses = snapshot.data!;

                // 1. FILTER
                if (_searchQuery.isNotEmpty) {
                  expenses = expenses.where((e) {
                    final desc = e.description.toLowerCase();
                    final cat = e.category.toLowerCase();
                    return desc.contains(_searchQuery) ||
                        cat.contains(_searchQuery);
                  }).toList();
                }

                // 2. SORT
                expenses.sort((a, b) {
                  switch (_sortMode) {
                    case 'Date (Newest)':
                      return b.date.compareTo(a.date);
                    case 'Date (Oldest)':
                      return a.date.compareTo(b.date);
                    case 'Amount (High to Low)':
                      return b.amount.compareTo(a.amount);
                    case 'Amount (Low to High)':
                      return a.amount.compareTo(b.amount);
                    default:
                      return 0;
                  }
                });

                if (expenses.isEmpty) {
                  return Center(
                    child: Text(
                      'No expenses found',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final e = expenses[index];
                    return PersonalExpenseTile(
                      expense: e,
                      emoji: _getEmojiForCategory(e.category),
                      onTap: () {
                        if (e.isRoomSync) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Room-synced expenses cannot be edited here.',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) =>
                              AddPersonalExpenseSheet(expenseToEdit: e),
                        );
                      },
                      onDelete: () async {
                        await _fs.deletePersonalExpense(user.uid, e.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getEmojiForCategory(String category) {
    switch (category) {
      case 'Food':
        return '🍔';
      case 'Rent':
        return '🏠';
      case 'Travel':
        return '🚕';
      case 'Shopping':
        return '🛍️';
      case 'Bills':
        return '🧾';
      case 'Room Spent':
        return '🏠';
      case 'Other':
      case 'Others':
        return '📝';
      default:
        return '💰';
    }
  }
}
