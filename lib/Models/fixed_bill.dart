import 'package:cloud_firestore/cloud_firestore.dart';

class FixedBill {
  final String id;
  final String userId;
  final String name; // e.g. Netflix, Rent
  final double amount;
  final int dueDay; // 1-31
  final bool isAutoReminder;
  final String? category;
  final DateTime createdAt;

  FixedBill({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.dueDay,
    this.isAutoReminder = true,
    this.category,
    required this.createdAt,
  });

  factory FixedBill.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FixedBill(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0),
      dueDay: data['dueDay'] ?? 1,
      isAutoReminder: data['isAutoReminder'] ?? true,
      category: data['category'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'amount': amount,
      'dueDay': dueDay,
      'isAutoReminder': isAutoReminder,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
