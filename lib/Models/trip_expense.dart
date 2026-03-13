import 'package:cloud_firestore/cloud_firestore.dart';

class TripExpense {
  final String id;
  final String tripId;
  final String description;
  final double amount;
  final String paidBy;
  final String category;
  final List<String> splitAmong;
  final Map<String, double> splits;
  final DateTime createdAt;
  final String? notes;

  TripExpense({
    required this.id,
    required this.tripId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.category,
    required this.splitAmong,
    required this.splits,
    required this.createdAt,
    this.notes,
  });

  factory TripExpense.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TripExpense(
      id: doc.id,
      tripId: (data['tripId'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : ((data['amount'] ?? 0.0) as num).toDouble(),
      paidBy: (data['paidBy'] ?? '').toString(),
      category: (data['category'] ?? 'Other').toString(),
      splitAmong: List<String>.from(data['splitAmong'] ?? const []),
      splits: (data['splits'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'category': category,
      'splitAmong': splitAmong,
      'splits': splits,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
  }
}
