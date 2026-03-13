import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../Models/personal_expense.dart';
import '../../services/export_service.dart';
import 'all_personal_expenses_screen.dart';
import 'add_personal_expense_sheet.dart';
import 'udhar_view.dart';
import 'add_udhar_sheet.dart';
import 'fixed_bills_view.dart';
import 'expense_pie_chart.dart';

class PersonalExpensesListScreen extends StatefulWidget {
  const PersonalExpensesListScreen({super.key});

  @override
  State<PersonalExpensesListScreen> createState() =>
      _PersonalExpensesListScreenState();
}

class _PersonalExpensesListScreenState extends State<PersonalExpensesListScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late TabController _tabController;
  final PageController _cardPageController = PageController();
  DateTime _selectedExpenseMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  int _cardPage = 0;
  bool _isSyncing = false;

  // Real-time room expense sync listeners
  StreamSubscription<List<Map<String, dynamic>>>? _roomsSyncSub;
  final Map<String, StreamSubscription> _expenseSyncSubs = {};
  bool _syncListenerActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _cardPageController.addListener(() {
      final page = _cardPageController.page?.round() ?? 0;
      if (page != _cardPage) setState(() => _cardPage = page);
    });

    // Start real-time sync listener if preference is already ON
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _fs.streamUserProfile(uid).first.then((profile) {
        if (profile != null && profile['roomSyncEnabled'] == true) {
          _startRoomSyncListener(uid);
        }
      });
    });
  }

  @override
  void dispose() {
    _stopRoomSyncListeners();
    _tabController.dispose();
    _cardPageController.dispose();
    super.dispose();
  }

  // ── Real-time room sync helpers ──────────────────────────────────────────

  void _startRoomSyncListener(String uid) {
    _stopRoomSyncListeners();
    _syncListenerActive = true;

    _roomsSyncSub = _fs.roomsForUser(uid).listen((rooms) {
      final currentRoomIds = rooms.map((r) => r['id'] as String).toSet();

      // Cancel subs for rooms user left
      _expenseSyncSubs.removeWhere((roomId, sub) {
        if (!currentRoomIds.contains(roomId)) {
          sub.cancel();
          return true;
        }
        return false;
      });

      // Add listeners for new rooms
      for (final room in rooms) {
        final roomId = room['id'] as String;
        if (_expenseSyncSubs.containsKey(roomId)) continue;

        _expenseSyncSubs[roomId] = _fs.getExpensesStream(roomId).listen((_) {
          // Any change in room expenses → run idempotent sync
          if (_syncListenerActive) {
            _fs.syncRoomExpensesToPersonal(uid).catchError((_) => 0);
          }
        });
      }
    });
  }

  void _stopRoomSyncListeners() {
    _syncListenerActive = false;
    _roomsSyncSub?.cancel();
    _roomsSyncSub = null;
    for (final sub in _expenseSyncSubs.values) {
      sub.cancel();
    }
    _expenseSyncSubs.clear();
  }

  Future<void> _handleSyncToggle(
    BuildContext context,
    String uid,
    bool currentlyEnabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context); // capture before await
    final newValue = !currentlyEnabled;
    await _fs.setRoomSyncEnabled(uid, newValue);

    if (!newValue) {
      _stopRoomSyncListeners(); // stop watching before deleting
      setState(() => _isSyncing = true);
      try {
        final deleted = await _fs.deleteRoomSyncedExpenses(uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              deleted > 0
                  ? 'Room sync off — removed $deleted synced expense${deleted == 1 ? '' : 's'}'
                  : 'Room sync disabled.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } finally {
        if (mounted) setState(() => _isSyncing = false);
      }
      return;
    }

    // Sync ON — run initial sync then start real-time listener
    setState(() => _isSyncing = true);
    try {
      final added = await _fs.syncRoomExpensesToPersonal(uid);
      _startRoomSyncListener(uid); // keep watching for future changes
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? 'Synced $added room expense${added == 1 ? '' : 's'} ✓  (auto-sync ON)'
                : 'Auto-sync ON — watching for new room expenses ✓',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleExport(String type) async {
    final user = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).firebaseUser!;
    final messenger = ScaffoldMessenger.of(context);

    final snap = await _fs.personalExpensesRef(user.uid).get();
    final expenses = snap.docs.map((d) => PersonalExpense.fromDoc(d)).toList();

    if (expenses.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No data to export')),
        );
      }
      return;
    }

    final exportService = ExportService();
    try {
      if (type == 'PDF') {
        await exportService.exportExpensesToPdf(expenses);
      } else {
        await exportService.exportExpensesToExcel(expenses);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showAddSheet(BuildContext context) {
    if (_tabController.index == 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const AddPersonalExpenseSheet(),
      );
    } else if (_tabController.index == 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const AddUdharSheet(),
      );
    } else {
      FixedBillsView.showAddBillDialog(context);
    }
  }

  void _showAddExpenseSheet(BuildContext context, {PersonalExpense? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPersonalExpenseSheet(expenseToEdit: expense),
    );
  }

  void _showSetBudgetDialog(BuildContext context, double currentBudget) {
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Set Monthly Budget',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount (₹)',
            prefixIcon: Icon(Icons.currency_rupee_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0.0;
              final user = Provider.of<AuthProvider>(
                ctx,
                listen: false,
              ).firebaseUser!;
              await _fs.updateUserProfile(user.uid, {'monthlyBudget': amount});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  double _calculateMonthlySpent(
    List<PersonalExpense> expenses,
    DateTime month,
  ) {
    double total = 0;
    for (final e in expenses) {
      if (e.date.year == month.year && e.date.month == month.month) {
        total += e.amount;
      }
    }
    return total;
  }

  List<DateTime> _getAvailableExpenseMonths(List<PersonalExpense> expenses) {
    final months = <DateTime>{
      DateTime(DateTime.now().year, DateTime.now().month),
    };
    for (final e in expenses) {
      months.add(DateTime(e.date.year, e.date.month));
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  List<PersonalExpense> _monthFilteredExpenses(List<PersonalExpense> expenses) {
    return expenses
        .where(
          (e) =>
              e.date.year == _selectedExpenseMonth.year &&
              e.date.month == _selectedExpenseMonth.month,
        )
        .toList();
  }

  String _getFabLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Add Expense';
      case 1:
        return 'Add Udhar';
      case 2:
        return 'Add Bill';
      default:
        return 'Add';
    }
  }

  IconData _getFabIcon() {
    switch (_tabController.index) {
      case 0:
        return Icons.add_shopping_cart_rounded;
      case 1:
        return Icons.handshake_rounded;
      case 2:
        return Icons.receipt_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  String _getCategoryEmoji(String category) {
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
        return '🏠'; // Room Spent emoji
      case 'Other':
      case 'Others':
        return '📝';
      default:
        return '💰';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.firebaseUser;
    final cs = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FF),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.05),
              cs.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: cs.surface, // Solid background
              surfaceTintColor: Colors.transparent, // Prevent tinting on scroll
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Personal Finance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              centerTitle: true,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.download_rounded),
                  onSelected: _handleExport,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'PDF',
                      child: Text('Export as PDF'),
                    ),
                    const PopupMenuItem(
                      value: 'Excel',
                      child: Text('Export as Excel'),
                    ),
                  ],
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  height: 46,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
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
                      fontSize: 13,
                    ),
                    padding: const EdgeInsets.all(3),
                    tabs: const [
                      Tab(text: 'Expenses'),
                      Tab(text: 'Udhar'),
                      Tab(text: 'Fixed Bills'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // ─── TAB 1: Expenses ────────────────────────────────────
              MultiStreamBuilder(
                userStream: _fs.streamUserProfile(user.uid),
                expensesStream: _fs.streamPersonalExpenses(user.uid),
                builder: (context, userProfile, expenses) {
                  expenses = expenses ?? [];
                  final availableMonths = _getAvailableExpenseMonths(expenses);
                  final monthExpenses = _monthFilteredExpenses(expenses);
                  final budget =
                      (userProfile['monthlyBudget']?.toDouble()) ?? 0.0;
                  final monthlySpent = _calculateMonthlySpent(
                    expenses,
                    _selectedExpenseMonth,
                  );
                  final progress = budget > 0 ? (monthlySpent / budget) : 0.0;
                  final visualProgress = progress.clamp(0.0, 1.0);
                  final remaining = budget - monthlySpent;
                  final isExceeded = monthlySpent > budget;

                  Color progressBarColor = cs.primary;
                  if (progress >= 1.0) {
                    progressBarColor = Colors.red;
                  } else if (progress >= 0.9) {
                    progressBarColor = Colors.orange;
                  } else if (progress >= 0.7) {
                    progressBarColor = Colors.amber;
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── SWIPEABLE CARD CAROUSEL ─────────────────
                              SizedBox(
                                height: 245,
                                child: PageView(
                                  controller: _cardPageController,
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    // PAGE 1 — Budget Dashboard ─────────────
                                    _buildBudgetCard(
                                      context,
                                      cs: cs,
                                      uid: user.uid,
                                      selectedMonth: _selectedExpenseMonth,
                                      budget: budget,
                                      monthlySpent: monthlySpent,
                                      remaining: remaining,
                                      visualProgress: visualProgress,
                                      progress: progress,
                                      progressBarColor: progressBarColor,
                                      isExceeded: isExceeded,
                                      syncEnabled:
                                          userProfile['roomSyncEnabled'] ==
                                          true,
                                      isSyncing: _isSyncing,
                                    ),
                                    // PAGE 2 — Spending Breakdown ────────────
                                    _buildBreakdownCard(
                                      context,
                                      cs: cs,
                                      expenses: monthExpenses,
                                    ),
                                  ],
                                ),
                              ),

                              // ── Dot indicators ──────────────────────────
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(2, (i) {
                                    final isActive = _cardPage == i;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      width: isActive ? 22 : 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? cs.primary
                                            : cs.primary.withValues(
                                                alpha: 0.25,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  }),
                                ),
                              ),

                              SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: availableMonths.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final month = availableMonths[index];
                                    final isSelected =
                                        month.year ==
                                            _selectedExpenseMonth.year &&
                                        month.month ==
                                            _selectedExpenseMonth.month;
                                    return ChoiceChip(
                                      label: Text(
                                        DateFormat('MMM yyyy').format(month),
                                      ),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        setState(
                                          () => _selectedExpenseMonth = month,
                                        );
                                      },
                                      side: BorderSide.none,
                                      backgroundColor: Colors.white,
                                      selectedColor: cs.primary.withValues(
                                        alpha: 0.18,
                                      ),
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ── RECENT EXPENSES HEADER ───────────────────
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recent Expenses • ${DateFormat('MMMM yyyy').format(_selectedExpenseMonth)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (monthExpenses.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const AllPersonalExpensesScreen(),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'View All',
                                        style: TextStyle(color: cs.primary),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Empty state
                              if (monthExpenses.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(
                                            alpha: 0.08,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          size: 40,
                                          color: cs.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No expenses for ${DateFormat('MMMM yyyy').format(_selectedExpenseMonth)}',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Choose another month or add a new expense',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ── EXPENSE TILES LIST ───────────────────────────
                      if (monthExpenses.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final e = monthExpenses[index];
                                return PersonalExpenseTile(
                                  expense: e,
                                  emoji: _getCategoryEmoji(e.category),
                                  onTap: () {
                                    if (e.isRoomSync) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Room-synced expenses cannot be edited here.',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }
                                    _showAddExpenseSheet(context, expense: e);
                                  },
                                  onDelete: () async {
                                    await _fs.deletePersonalExpense(
                                      user.uid,
                                      e.id,
                                    );
                                  },
                                );
                              },
                              childCount: monthExpenses.length > 20
                                  ? 20
                                  : monthExpenses
                                        .length, // increased cap from 10 to 20 for scrolling
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const UdharView(),
              const FixedBillsView(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        label: Text(
          _getFabLabel(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        icon: Icon(_getFabIcon()),
      ),
    );
  }

  // ─── Budget Card  ───────────────────────────────────────────────────────────

  Widget _buildBudgetCard(
    BuildContext context, {
    required ColorScheme cs,
    required String uid,
    required DateTime selectedMonth,
    required double budget,
    required double monthlySpent,
    required double remaining,
    required double visualProgress,
    required double progress,
    required Color progressBarColor,
    required bool isExceeded,
    required bool syncEnabled,
    required bool isSyncing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.secondary],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month + Set Budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(selectedMonth),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showSetBudgetDialog(context, budget),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Set Budget',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining Limit',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${remaining.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: visualProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: AlwaysStoppedAnimation(progressBarColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            // Spent + Budget row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ₹${monthlySpent.toStringAsFixed(0)}  •  Budget: ₹${budget.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                // ── Room Sync toggle ─────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Room Sync',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isSyncing
                          ? null
                          : () => _handleSyncToggle(context, uid, syncEnabled),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 44,
                        height: 24,
                        decoration: BoxDecoration(
                          color: syncEnabled
                              ? Colors
                                    .white // White background when ON
                              : Colors.white.withValues(
                                  alpha: 0.3,
                                ), // Faded when OFF
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Stack(
                          children: [
                            // "ON" / "OFF" text inside the track
                            if (!isSyncing)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: syncEnabled
                                        ? MainAxisAlignment.start
                                        : MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        syncEnabled ? 'ON' : 'OFF',
                                        style: TextStyle(
                                          color: syncEnabled
                                              ? cs.primary
                                              : Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              top: 2,
                              left: syncEnabled ? 22 : 2,
                              right: syncEnabled ? 2 : 22,
                              bottom: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: syncEnabled
                                      ? cs.primary
                                      : Colors.white, // Purple thumb when ON
                                ),
                                child: isSyncing
                                    ? Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            syncEnabled
                                                ? Colors.white
                                                : cs.primary,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isExceeded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Budget Exceeded!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (progress >= 0.9) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${(progress * 100).toInt()}% of budget used!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Spending Breakdown Card ────────────────────────────────────────────────

  Widget _buildBreakdownCard(
    BuildContext context, {
    required ColorScheme cs,
    required List<PersonalExpense> expenses,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: expenses.isNotEmpty
            ? ExpensePieChart(expenses: expenses)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 44,
                      color: cs.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add expenses to see breakdown',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── Expense Tile ────────────────────────────────────────────────────────────

class PersonalExpenseTile extends StatelessWidget {
  final PersonalExpense expense;
  final String emoji;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const PersonalExpenseTile({
    super.key,
    required this.expense,
    required this.emoji,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSync = expense.isRoomSync;

    return Dismissible(
      key: ValueKey(expense.id),
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
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('Delete Expense'),
                content: Text(
                  isSync
                      ? 'Delete this room-synced expense from your personal list?'
                      : 'Delete "${expense.description}"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSync
                      ? cs.primary.withValues(alpha: 0.06)
                      : cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              // Small lock badge for synced expenses
              if (isSync)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sync_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            expense.description,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Row(
            children: [
              Text(
                DateFormat('MMM d').format(expense.date),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSync
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expense.paymentMode,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          trailing: Text(
            '₹${expense.amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

// ─── Multi Stream Builder ─────────────────────────────────────────────────────

class MultiStreamBuilder extends StatelessWidget {
  final Stream<Map<String, dynamic>?> userStream;
  final Stream<List<PersonalExpense>> expensesStream;
  final Widget Function(
    BuildContext,
    Map<String, dynamic> userProfile,
    List<PersonalExpense>? expenses,
  )
  builder;

  const MultiStreamBuilder({
    super.key,
    required this.userStream,
    required this.expensesStream,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: userStream,
      builder: (context, userAsync) {
        final userProfile = userAsync.data ?? {};
        return StreamBuilder<List<PersonalExpense>>(
          stream: expensesStream,
          builder: (context, expensesAsync) {
            if (expensesAsync.hasError) {
              return Center(child: Text('Error: ${expensesAsync.error}'));
            }
            if (expensesAsync.connectionState == ConnectionState.waiting &&
                !expensesAsync.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return builder(context, userProfile, expensesAsync.data);
          },
        );
      },
    );
  }
}
