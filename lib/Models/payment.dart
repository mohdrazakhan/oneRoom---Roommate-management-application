import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for recording cash payments between members
/// e.g., "Member A paid Member B ₹500 in cash"
class Payment {
  final String id;
  final String roomId;
  final String payerId; // Who paid
  final String receiverId; // Who received
  final double amount;
  final String? note;
  final DateTime createdAt;
  final String createdBy;

  Payment({
    required this.id,
    required this.roomId,
    required this.payerId,
    required this.receiverId,
    required this.amount,
    this.note,
    required this.createdAt,
    required this.createdBy,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      payerId: data['payerId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'payerId': payerId,
      'receiverId': receiverId,
      'amount': amount,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
