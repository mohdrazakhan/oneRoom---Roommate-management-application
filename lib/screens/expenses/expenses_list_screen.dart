import 'dart:async'; // Added for Timer
import 'package:intl/intl.dart';

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
import '../../widgets/ad_banner_widget.dart';
import '../../widgets/video_ad_dialog.dart';

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
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  late final FirestoreService _fs;
  late final Stream<Map<String, dynamic>?> _roomStream;
  late final Stream<List<Map<String, dynamic>>> _expensesStream;

  @override
  void initState() {
    super.initState();
    _fs = FirestoreService();
    _roomStream = _fs.streamRoomById(widget.roomId);
    _expensesStream = _fs.expensesForRoom(widget.roomId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final theme = Theme.of(context);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
            ),
            colorScheme: theme.colorScheme.copyWith(
              surface: Colors.white,
              primary: theme.colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
              secondaryContainer: theme.colorScheme.primary.withValues(
                alpha: 0.1,
              ),
            ),
          ),
          child: child!,
        );
      },
      saveText: 'Save',
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser?.uid;

    return Stack(
      children: [
      Scaffold(
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
        stream: _roomStream,
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
            stream: _expensesStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data ?? [];
              final allExpenses = data
                  .map((m) => Expense.fromMap(m, m['id']))
                  .toList();

              // Filter by category if selected and search query and date range
              final expenses = allExpenses.where((e) {
                final matchesCategory =
                    _selectedCategory == null ||
                    e.category == _selectedCategory;

                final matchesSearch =
                    _searchQuery.isEmpty ||
                    e.description.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    e.amount.toString().contains(_searchQuery);

                bool matchesDate = true;
                if (_selectedDateRange != null) {
                  final start = _selectedDateRange!.start.copyWith(
                    hour: 0,
                    minute: 0,
                    second: 0,
                    millisecond: 0,
                    microsecond: 0,
                  );
                  final end = _selectedDateRange!.end.copyWith(
                    hour: 23,
                    minute: 59,
                    second: 59,
                    millisecond: 999,
                    microsecond: 999,
                  );
                  matchesDate =
                      e.createdAt.isAfter(
                        start.subtract(const Duration(milliseconds: 1)),
                      ) &&
                      e.createdAt.isBefore(
                        end.add(const Duration(milliseconds: 1)),
                      );
                }

                return matchesCategory && matchesSearch && matchesDate;
              }).toList();

              double total = 0;
              for (final e in expenses) {
                total += e.amount;
              }

              return CustomScrollView(
                slivers: [
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search expenses...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                    FocusScope.of(context).unfocus();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 1,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {});
                          _onSearchChanged(val);
                        },
                      ),
                    ),
                  ),

                  // Total Card
                  SliverToBoxAdapter(
                    child: Container(
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
                  ),

                  // Filter Chips
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Date Filter Chip
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedDateRange == null
                                        ? 'Date'
                                        : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                                    style: TextStyle(
                                      fontWeight: _selectedDateRange != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              selected: _selectedDateRange != null,
                              onSelected: (selected) {
                                if (!selected) {
                                  setState(() => _selectedDateRange = null);
                                } else {
                                  _pickDateRange();
                                }
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
                          // All Filter
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
                          // Categories
                          ...allCategories.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text('${cat.icon} ${cat.name}'),
                                selected: _selectedCategory == cat.name,
                                onSelected: (sel) {
                                  setState(
                                    () => _selectedCategory = sel
                                        ? cat.name
                                        : null,
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
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // Expenses List or Empty State
                  if (expenses.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.receipt_long_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching expenses'
                                  : 'No expenses yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_searchQuery.isEmpty)
                              Text(
                                'Tap + to add your first expense',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final e = expenses[i];
                          // Find category object
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
                            onTap: () => _showExpenseDetailPopup(context, e),
                            onDelete: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Expense?'),
                                  content: const Text(
                                    'Are you sure you want to delete this expense? This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await _fs.deleteExpense(widget.roomId, e.id);
                              }
                            },
                          );
                        }, childCount: expenses.length),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: FloatingActionButton(
          onPressed: () {
            _showExpenseOptionsMenu(context);
          },
          elevation: 8,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    ),
    // Bottom Ad Banner
    const Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AdBannerWidget(),
    ),
    ],
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

    // Show video ad first, then show export options
    if (!context.mounted) return;
    await showVideoAd(context, onComplete: () async {
      if (!mounted) return;
      await _showExportOptions(context);
    });
  }

  Future<void> _showExportOptions(BuildContext context) async {
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
