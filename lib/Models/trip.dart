import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final String currency;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  Trip({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory Trip.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Trip(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      members: List<String>.from(data['members'] ?? const []),
      currency: (data['currency'] ?? 'Rs.').toString(),
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'currency': currency,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
