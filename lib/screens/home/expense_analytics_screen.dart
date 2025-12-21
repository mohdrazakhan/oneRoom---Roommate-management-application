// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../widgets/safe_web_image.dart';
import '../../Models/room.dart';
import '../../services/firestore_service.dart';

class ExpenseAnalyticsScreen extends StatefulWidget {
  final Room room;

  const ExpenseAnalyticsScreen({super.key, required this.room});

  @override
  State<ExpenseAnalyticsScreen> createState() => _ExpenseAnalyticsScreenState();
}

class _ExpenseAnalyticsScreenState extends State<ExpenseAnalyticsScreen> {
  final _firestoreService = FirestoreService();
  Map<String, Map<String, dynamic>> _memberProfiles = {};
  Map<String, double> _memberExpenses = {}; // Paid by member
  Map<String, double> _memberConsumed = {}; // Consumed by member
  double _totalExpenditure = 0.0;
  int _totalTransactions = 0;
  bool _isLoading = true;
  int _touchedIndex = -1;
  bool _showBySpender = true; // Toggle state for breakdown

  // Color palette for charts
  final List<Color> _chartColors = [
    const Color(0xFF6366F1), // Indigo
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF10B981), // Green
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFEF4444), // Red
    const Color(0xFF14B8A6), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load member profiles
      final profiles = await _firestoreService.getUsersProfiles(
        widget.room.members,
      );

      // Load expenses
      final expenses = await _firestoreService
          .getExpenses(widget.room.id)
          .first;

      // Calculate totals by member (Spending)
      final Map<String, double> expensesByMember = {};
      final Map<String, double> consumedByMember = {};

      for (final expense in expenses) {
        // Spending
        String payerKey = expense.paidBy;
        if (payerKey.startsWith('guest_')) {
          payerKey = 'guests_aggregate';
        }

        expensesByMember[payerKey] =
            (expensesByMember[payerKey] ?? 0.0) + expense.amount;

        // Consumption
        if (expense.splits.isNotEmpty) {
          expense.splits.forEach((uid, amount) {
            String consumerKey = uid;
            if (consumerKey.startsWith('guest_')) {
              consumerKey = 'guests_aggregate';
            }
            consumedByMember[consumerKey] =
                (consumedByMember[consumerKey] ?? 0.0) + amount;
          });
        }
      }

      final total = expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);

      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _memberExpenses = expensesByMember;
          _memberConsumed = consumedByMember;
          _totalExpenditure = total;
          _totalTransactions = expenses.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading analytics data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMemberDisplayName(String uid) {
    if (uid == 'guests_aggregate') return 'Guests';
    final profile = _memberProfiles[uid];
    if (profile == null) return 'Member ${uid.substring(0, 4)}';

    if (profile['displayName'] != null &&
        profile['displayName'].toString().isNotEmpty) {
      return profile['displayName'];
    }

    if (profile['email'] != null) {
      final email = profile['email'].toString();
      final username = email.split('@')[0];
      return username;
    }

    return 'Member ${uid.substring(0, 4)}';
  }

  Color _getMemberColor(int index) {
    return _chartColors[index % _chartColors.length];
  }

  List<PieChartSectionData> _getPieChartSections() {
    final sections = <PieChartSectionData>[];
    int index = 0;

    final dataToUse = _showBySpender ? _memberExpenses : _memberConsumed;

    final sortedEntries = dataToUse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Use total expenditure for spending, but total consumption for consumer view?
    // In a closed system, they should be the same.
    final total = _totalExpenditure;

    for (final entry in sortedEntries) {
      final percentage = (entry.value / total) * 100;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 110.0 : 100.0;
      final fontSize = isTouched ? 18.0 : 14.0;

      sections.add(
        PieChartSectionData(
          color: _getMemberColor(index),
          value: entry.value,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
      );
      index++;
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Analytics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Total Summary Card
                  _buildTotalSummaryCard(),

                  const SizedBox(height: 24),

                  // Global Toggle
                  _buildToggleButtons(),

                  const SizedBox(height: 24),

                  // Pie Chart Card (Spending)
                  _buildPieChartCard(),

                  const SizedBox(height: 24),

                  // Detailed List (Toggleable)
                  _buildDetailedList(),

                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBySpender = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showBySpender
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'By Spender',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _showBySpender ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showBySpender = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showBySpender
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  'By Consumer',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: !_showBySpender ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.analytics_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Total Expenditure',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.room.currency}${_totalExpenditure.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_totalTransactions transactions • ${_memberExpenses.length} members',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard() {
    final dataToUse = _showBySpender ? _memberExpenses : _memberConsumed;
    if (dataToUse.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                color: _showBySpender
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _showBySpender
                    ? 'Spending Distribution'
                    : 'Consumption Distribution',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: _getPieChartSections(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final dataToUse = _showBySpender ? _memberExpenses : _memberConsumed;

    final sortedEntries = dataToUse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: sortedEntries.asMap().entries.map((entry) {
        final index = entry.key;
        final memberEntry = entry.value;
        final memberName = _getMemberDisplayName(memberEntry.key);
        final color = _getMemberColor(index);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                memberName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailedList() {
    final dataToUse = _showBySpender ? _memberExpenses : _memberConsumed;

    if (dataToUse.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = dataToUse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: _showBySpender
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _showBySpender ? 'Spender Breakdown' : 'Consumer Breakdown',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (sortedEntries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No data for this view'),
              ),
            ),

          ...sortedEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final memberEntry = entry.value;
            final memberName = _getMemberDisplayName(memberEntry.key);
            final profile = _memberProfiles[memberEntry.key];
            final photoUrl = profile?['photoUrl'] as String?;
            final amount = memberEntry.value;
            // For percentage, Spender view uses Total Expenditure.
            // Consumer view SHOULD also likely use Total Expenditure for context,
            // assuming total consumption == total expenditure (which it should in a zero-sum system).
            final percentage = (amount / _totalExpenditure) * 100;
            final color = _getMemberColor(index);

            return Column(
              children: [
                if (index > 0) const Divider(height: 24),
                Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.amber
                            : color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: index == 0 ? Colors.white : color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: memberEntry.key == 'guests_aggregate'
                          ? Colors.orange.withValues(alpha: 0.1)
                          : photoUrl != null
                          ? Colors.transparent
                          : color.withValues(alpha: 0.1),
                      child: memberEntry.key == 'guests_aggregate'
                          ? const Icon(Icons.people, color: Colors.orange)
                          : photoUrl != null
                          ? ClipOval(
                              child: SafeWebImage(
                                photoUrl,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      memberName.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: color,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Text(
                              memberName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: color,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Name and percentage
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage / 100 > 1.0
                                        ? 1.0
                                        : percentage / 100,
                                    backgroundColor: Colors.grey.withValues(
                                      alpha: 0.2,
                                    ),
                                    valueColor: AlwaysStoppedAnimation(color),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.room.currency}${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color,
                          ),
                        ),
                        if (index == 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _showBySpender ? 'Top Spender' : 'Top Consumer',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
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
      child: Column(
        children: [
          Icon(Icons.insert_chart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No Expenses Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add expenses to see analytics',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
