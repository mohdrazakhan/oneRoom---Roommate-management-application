// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
  Map<String, double> _memberExpenses = {};
  double _totalExpenditure = 0.0;
  int _totalTransactions = 0;
  bool _isLoading = true;
  int _touchedIndex = -1;

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

      // Calculate totals by member
      final Map<String, double> expensesByMember = {};
      for (final expense in expenses) {
        expensesByMember[expense.paidBy] =
            (expensesByMember[expense.paidBy] ?? 0.0) + expense.amount;
      }

      final total = expenses.fold<double>(0.0, (sum, exp) => sum + exp.amount);

      if (mounted) {
        setState(() {
          _memberProfiles = profiles;
          _memberExpenses = expensesByMember;
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

    final sortedEntries = _memberExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      final percentage =
          (_memberExpenses[entry.key]! / _totalExpenditure) * 100;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 110.0 : 100.0;
      final fontSize = isTouched ? 18.0 : 14.0;

      sections.add(
        PieChartSectionData(
          color: _getMemberColor(index),
          value: _memberExpenses[entry.key],
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

  List<BarChartGroupData> _getBarChartGroups() {
    final groups = <BarChartGroupData>[];
    int index = 0;

    final sortedEntries = _memberExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedEntries) {
      groups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: entry.value,
              color: _getMemberColor(index),
              width: 40,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: _totalExpenditure,
                color: Colors.grey.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
      index++;
    }

    return groups;
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

                  // Pie Chart Card
                  _buildPieChartCard(),

                  const SizedBox(height: 24),

                  // Bar Chart Card
                  _buildBarChartCard(),

                  const SizedBox(height: 24),

                  // Detailed List
                  _buildDetailedList(),

                  const SizedBox(height: 40),
                ],
              ),
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
    if (_memberExpenses.isEmpty) {
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
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Spending Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildBarChartCard() {
    if (_memberExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = _memberExpenses.entries.toList()
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
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Comparison Chart',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: _totalExpenditure * 1.1,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.black87,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final memberName = _getMemberDisplayName(
                        sortedEntries[group.x.toInt()].key,
                      );
                      return BarTooltipItem(
                        '$memberName\n${widget.room.currency}${rod.toY.toStringAsFixed(2)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= sortedEntries.length) {
                          return const SizedBox.shrink();
                        }
                        final name = _getMemberDisplayName(
                          sortedEntries[value.toInt()].key,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            name.length > 8
                                ? '${name.substring(0, 8)}...'
                                : name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${widget.room.currency}${(value / 1000).toStringAsFixed(0)}k',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _totalExpenditure / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _getBarChartGroups(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    final sortedEntries = _memberExpenses.entries.toList()
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
    if (_memberExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = _memberExpenses.entries.toList()
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
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Detailed Breakdown',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedEntries.asMap().entries.map((entry) {
            final index = entry.key;
            final memberEntry = entry.value;
            final memberName = _getMemberDisplayName(memberEntry.key);
            final profile = _memberProfiles[memberEntry.key];
            final photoUrl = profile?['photoUrl'] as String?;
            final amount = memberEntry.value;
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
                      backgroundColor: photoUrl != null
                          ? null
                          : color.withValues(alpha: 0.1),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              memberName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: color,
                              ),
                            )
                          : null,
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
                                    value: percentage / 100,
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
                            child: const Text(
                              'Top Spender',
                              style: TextStyle(
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
