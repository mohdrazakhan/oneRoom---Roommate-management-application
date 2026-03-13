// lib/Models/personal_expense.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PersonalExpense {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String? notes;
  final String userId;
  final String paymentMode; // 'Cash', 'UPI', 'Card', 'Room Sync'

  // Room sync metadata
  final bool isRoomSync;
  final String? sourceRoomExpenseId; // Firestore expense ID, for dedup

  PersonalExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.notes,
    required this.userId,
    this.paymentMode = 'Cash',
    this.isRoomSync = false,
    this.sourceRoomExpenseId,
  });

  factory PersonalExpense.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PersonalExpense(
      id: doc.id,
      description: data['description'] ?? '',
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'Other',
      notes: data['notes'],
      userId: data['userId'] ?? '',
      paymentMode: data['paymentMode'] ?? 'Cash',
      isRoomSync: data['isRoomSync'] ?? false,
      sourceRoomExpenseId: data['sourceRoomExpenseId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'notes': notes,
      'userId': userId,
      'paymentMode': paymentMode,
      'isRoomSync': isRoomSync,
      if (sourceRoomExpenseId != null)
        'sourceRoomExpenseId': sourceRoomExpenseId,
    };
  }
}
