import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../Models/personal_expense.dart';

class ExpensePieChart extends StatefulWidget {
  final List<PersonalExpense> expenses;

  const ExpensePieChart({super.key, required this.expenses});

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.expenses.isEmpty) return const SizedBox.shrink();

    // Group by category
    final Map<String, double> categoryTotals = {};
    double totalSpent = 0;

    for (var e in widget.expenses) {
      // Filter for current month only? Or just showing what's passed?
      // Let's stick to the expenses passed in (which should ideally be filtered contextually,
      // but usually the screen passes all. Let's filter for CURRENT MONTH inside here for relevance)
      if (e.date.month == DateTime.now().month &&
          e.date.year == DateTime.now().year) {
        categoryTotals.update(
          e.category,
          (value) => value + e.amount,
          ifAbsent: () => e.amount,
        );
        totalSpent += e.amount;
      }
    }

    if (totalSpent == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          const Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2, // Space between sections
                      centerSpaceRadius: 22, // Donut hole
                      sections: _generateSections(categoryTotals, totalSpent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categoryTotals.entries.map((e) {
                    final percentage = (e.value / totalSpent * 100);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getColor(e.key),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateSections(
    Map<String, double> totals,
    double total,
  ) {
    return totals.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final amount = entry.value.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 52.0 : 44.0;
      final percentage = (amount / total * 100);

      return PieChartSectionData(
        color: _getColor(category),
        value: amount,
        title: isTouched ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Color _getColor(String category) {
    switch (category) {
      case 'Food':
        return Colors.orange;
      case 'Rent':
        return Colors.blue;
      case 'Travel':
        return Colors.purple;
      case 'Shopping':
        return Colors.pink;
      case 'Bills':
        return Colors.red;
      case 'Room Spent':
        return Colors.indigo; // Set color for Room Spent
      case 'Others':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }
}
