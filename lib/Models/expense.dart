// lib/Models/expense.dart
// Firestore helper: rooms, expenses, users
import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment.dart';

class Expense {
  final String id;
  final String roomId;
  final String description;
  final double amount;
  final String paidBy; // UID of person who paid
  final Map<String, double>? payers; // Optional: multi-payer breakdown
  final DateTime createdAt;
  final String category;
  final List<String> splitAmong; // UIDs of people to split among
  final Map<String, double> splits; // UID -> amount they owe
  final String? notes;
  final String? receiptUrl;
  final Map<String, bool> settledWith; // UID -> has this person settled?

  Expense({
    required this.id,
    required this.roomId,
    required this.description,
    required this.amount,
    required this.paidBy,
    this.payers,
    required this.createdAt,
    this.category = 'Other',
    required this.splitAmong,
    required this.splits,
    this.notes,
    this.receiptUrl,
    Map<String, bool>? settledWith,
  }) : settledWith = settledWith ?? {};

  factory Expense.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Expense(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0),
      paidBy: data['paidBy'] is String ? (data['paidBy'] as String) : '',
      payers: (data['payers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v is int ? v.toDouble() : (v as double)),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'Other',
      splitAmong: List<String>.from(data['splitAmong'] ?? []),
      splits:
          (data['splits'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value is int) ? value.toDouble() : value as double,
            ),
          ) ??
          {},
      notes: data['notes'],
      receiptUrl: data['receiptUrl'],
      settledWith: Map<String, bool>.from(data['settledWith'] ?? {}),
    );
  }

  // Backward/interop factory: build Expense from a plain map + id
  // Supports older simple expense documents and newer comprehensive ones.
  factory Expense.fromMap(Map<String, dynamic> map, String id) {
    // createdAt can be Timestamp/int(ms)/String
    final dynamic ts = map['createdAt'];
    DateTime createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else if (ts is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      createdAt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    // amount can be int/double/string
    final amountRaw = map['amount'];
    double amount;
    if (amountRaw is int) {
      amount = amountRaw.toDouble();
    } else if (amountRaw is double) {
      amount = amountRaw;
    } else if (amountRaw is String) {
      amount = double.tryParse(amountRaw) ?? 0.0;
    } else {
      amount = 0.0;
    }

    // Splits map may be absent in older docs; default to empty map
    final rawSplits = map['splits'] as Map<String, dynamic>?;
    final splits = rawSplits == null
        ? <String, double>{}
        : rawSplits.map(
            (k, v) => MapEntry(k, v is int ? v.toDouble() : (v as double)),
          );

    return Expense(
      id: id,
      roomId: map['roomId'] ?? '',
      description: map['description'] ?? '',
      amount: amount,
      paidBy: map['paidBy'] is String ? (map['paidBy'] as String) : '',
      payers: (map['payers'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v is int ? v.toDouble() : (v as double)),
      ),
      createdAt: createdAt,
      category: map['category'] ?? 'Other',
      splitAmong: List<String>.from(map['splitAmong'] ?? const <String>[]),
      splits: splits,
      notes: map['notes'],
      receiptUrl: map['receiptUrl'],
      settledWith: Map<String, bool>.from(
        map['settledWith'] ?? const <String, bool>{},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      if (payers != null && payers!.isNotEmpty) 'payers': payers,
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category,
      'splitAmong': splitAmong,
      'splits': splits,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'settledWith': settledWith,
    };
  }

  /// Return the multi-payer map if present; otherwise fall back to a single entry using paidBy/amount.
  Map<String, double> effectivePayers() {
    if (payers != null && payers!.isNotEmpty) return Map.of(payers!);
    if (paidBy.isNotEmpty) return {paidBy: amount};
    return const {};
  }

  // Calculate if expense is fully settled
  bool get isFullySettled {
    if (splits.isEmpty) return true;
    return splits.keys.every((uid) => settledWith[uid] == true);
  }

  // Get pending amount for a specific user
  double getPendingAmount(String uid) {
    if (settledWith[uid] == true) return 0.0;
    return splits[uid] ?? 0.0;
  }

  Expense copyWith({
    String? description,
    double? amount,
    String? category,
    List<String>? splitAmong,
    Map<String, double>? splits,
    String? notes,
    String? receiptUrl,
    Map<String, bool>? settledWith,
  }) {
    return Expense(
      id: id,
      roomId: roomId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy,
      createdAt: createdAt,
      category: category ?? this.category,
      splitAmong: splitAmong ?? this.splitAmong,
      splits: splits ?? this.splits,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      settledWith: settledWith ?? this.settledWith,
    );
  }
}

class ExpenseCategory {
  final String name;
  final String icon;
  final int colorValue;

  const ExpenseCategory({
    required this.name,
    required this.icon,
    required this.colorValue,
  });

  static const categories = [
    ExpenseCategory(name: 'Food', icon: '🍔', colorValue: 0xFFFF9800),
    ExpenseCategory(name: 'Groceries', icon: '🛒', colorValue: 0xFF4CAF50),
    ExpenseCategory(name: 'Utilities', icon: '💡', colorValue: 0xFFFFC107),
    ExpenseCategory(name: 'Rent', icon: '🏠', colorValue: 0xFF2196F3),
    ExpenseCategory(name: 'Transport', icon: '🚗', colorValue: 0xFF9C27B0),
    ExpenseCategory(name: 'Entertainment', icon: '🎬', colorValue: 0xFFE91E63),
    ExpenseCategory(name: 'Cleaning', icon: '🧹', colorValue: 0xFF009688),
    ExpenseCategory(name: 'Other', icon: '📝', colorValue: 0xFF607D8B),
  ];

  static ExpenseCategory getCategory(String name) {
    return categories.firstWhere(
      (cat) => cat.name == name,
      orElse: () => ExpenseCategory(
        name: name,
        icon: '🏷️', // Default icon for custom categories
        colorValue: 0xFF9E9E9E, // Grey for custom
      ),
    );
  }

  /// Create a custom category from user input
  static ExpenseCategory createCustom(String name, String emoji) {
    return ExpenseCategory(name: name, icon: emoji, colorValue: 0xFF9E9E9E);
  }
}

// Helper class to calculate balances
class Balance {
  final String personUid;
  final double amount; // Positive = they are owed, Negative = they owe

  Balance({required this.personUid, required this.amount});
}

class BalanceCalculator {
  // Calculate balances for all members in a room (expenses only)
  static Map<String, double> calculateBalances(List<Expense> expenses) {
    Map<String, double> balances = {};

    for (var expense in expenses) {
      // Credit each payer according to their contribution (multi-payer aware)
      final payers = expense.effectivePayers();
      payers.forEach((uid, paidAmount) {
        balances[uid] = (balances[uid] ?? 0) + paidAmount;
      });

      // People who owe get debited
      expense.splits.forEach((uid, amount) {
        if (expense.settledWith[uid] != true) {
          balances[uid] = (balances[uid] ?? 0) - amount;
        }
      });
    }

    return balances;
  }

  // Calculate balances including payments as settlements
  // Payments reduce the debt: if A pays B ₹200, A's balance increases by ₹200 and B's decreases by ₹200
  static Map<String, double> calculateBalancesWithPayments(
    List<Expense> expenses,
    List<Payment> payments,
  ) {
    // First calculate balances from expenses
    Map<String, double> balances = calculateBalances(expenses);

    // Then apply payments as settlements
    for (var payment in payments) {
      // Payer's balance increases (they paid, reducing their debt)
      balances[payment.payerId] =
          (balances[payment.payerId] ?? 0) + payment.amount;

      // Receiver's balance decreases (they received payment, reducing what they're owed)
      balances[payment.receiverId] =
          (balances[payment.receiverId] ?? 0) - payment.amount;
    }

    return balances;
  }

  // Simplify settlements (who should pay whom)
  static List<Settlement> simplifySettlements(Map<String, double> balances) {
    List<Settlement> settlements = [];

    // Separate creditors (people who are owed) and debtors (people who owe)
    List<MapEntry<String, double>> creditors = [];
    List<MapEntry<String, double>> debtors = [];

    balances.forEach((uid, balance) {
      if (balance > 0.01) {
        creditors.add(MapEntry(uid, balance));
      } else if (balance < -0.01) {
        debtors.add(MapEntry(uid, balance.abs()));
      }
    });

    // Sort by amount
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    int i = 0, j = 0;
    while (i < creditors.length && j < debtors.length) {
      var creditor = creditors[i];
      var debtor = debtors[j];

      double amount = creditor.value < debtor.value
          ? creditor.value
          : debtor.value;

      settlements.add(
        Settlement(from: debtor.key, to: creditor.key, amount: amount),
      );

      creditors[i] = MapEntry(creditor.key, creditor.value - amount);
      debtors[j] = MapEntry(debtor.key, debtor.value - amount);

      if (creditors[i].value < 0.01) i++;
      if (debtors[j].value < 0.01) j++;
    }

    return settlements;
  }
}

class Settlement {
  final String from;
  final String to;
  final double amount;

  Settlement({required this.from, required this.to, required this.amount});
}
