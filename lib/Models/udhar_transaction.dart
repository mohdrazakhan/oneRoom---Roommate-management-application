import 'package:cloud_firestore/cloud_firestore.dart';

class UdharPaymentRecord {
  final double amount;
  final double remainingAfter;
  final DateTime recordedAt;

  UdharPaymentRecord({
    required this.amount,
    required this.remainingAfter,
    required this.recordedAt,
  });

  factory UdharPaymentRecord.fromMap(Map<String, dynamic> data) {
    return UdharPaymentRecord(
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0),
      remainingAfter: (data['remainingAfter'] is int)
          ? (data['remainingAfter'] as int).toDouble()
          : (data['remainingAfter'] ?? 0.0),
      recordedAt:
          (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'remainingAfter': remainingAfter,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }
}

class UdharReminderRecord {
  final String id;
  final DateTime remindAt;
  final String message;
  final bool isSent;
  final DateTime? sentAt;

  UdharReminderRecord({
    required this.id,
    required this.remindAt,
    required this.message,
    this.isSent = false,
    this.sentAt,
  });

  factory UdharReminderRecord.fromMap(Map<String, dynamic> data) {
    return UdharReminderRecord(
      id: data['id'] ?? '',
      remindAt: (data['remindAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      message: data['message'] ?? '',
      isSent: data['isSent'] ?? false,
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'remindAt': Timestamp.fromDate(remindAt),
      'message': message,
      'isSent': isSent,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
    };
  }

  UdharReminderRecord copyWith({
    String? id,
    DateTime? remindAt,
    String? message,
    bool? isSent,
    DateTime? sentAt,
  }) {
    return UdharReminderRecord(
      id: id ?? this.id,
      remindAt: remindAt ?? this.remindAt,
      message: message ?? this.message,
      isSent: isSent ?? this.isSent,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}

class UdharTransaction {
  static const String interestTypeNone = 'NONE';
  static const String interestTypePercent = 'PERCENT';
  static const String interestTypeFixed = 'FIXED';

  static const String interestFrequencyDaily = 'DAILY';
  static const String interestFrequencyMonthly = 'MONTHLY';

  static const String interestStartFromCreated = 'FROM_CREATED';
  static const String interestStartFromDueDate = 'FROM_DUE_DATE';

  final String id;
  final String userId; // The app user
  final String personName; // The person given to/taken from
  final double amount; // Principal amount
  final String type; // 'GIVEN' (You expect back) or 'TAKEN' (You owe)
  final String status; // 'PENDING', 'PAID'
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? phoneNumber;
  final String? personImageUrl;
  final String? receiptUrl;
  final String interestType;
  final String interestFrequency;
  final double interestValue;
  final String interestStartRule;
  final double settledAmount;
  final List<UdharPaymentRecord> paymentHistory;
  final List<UdharReminderRecord> reminderHistory;
  final String? notes;

  UdharTransaction({
    required this.id,
    required this.userId,
    required this.personName,
    required this.amount,
    required this.type,
    required this.status,
    this.dueDate,
    required this.createdAt,
    this.phoneNumber,
    this.personImageUrl,
    this.receiptUrl,
    this.interestType = interestTypeNone,
    this.interestFrequency = interestFrequencyDaily,
    this.interestValue = 0.0,
    this.interestStartRule = interestStartFromCreated,
    this.settledAmount = 0.0,
    this.paymentHistory = const [],
    this.reminderHistory = const [],
    this.notes,
  });

  factory UdharTransaction.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UdharTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      personName: data['personName'] ?? '',
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0),
      type: data['type'] ?? 'GIVEN',
      status: data['status'] ?? 'PENDING',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      phoneNumber: data['phoneNumber'],
      personImageUrl: data['personImageUrl'],
      receiptUrl: data['receiptUrl'],
      interestType: data['interestType'] ?? interestTypeNone,
      interestFrequency: data['interestFrequency'] ?? interestFrequencyDaily,
      interestValue: (data['interestValue'] is int)
          ? (data['interestValue'] as int).toDouble()
          : (data['interestValue'] ?? 0.0),
      interestStartRule: data['interestStartRule'] ?? interestStartFromCreated,
      settledAmount: (data['settledAmount'] is int)
          ? (data['settledAmount'] as int).toDouble()
          : (data['settledAmount'] ?? 0.0),
      paymentHistory: (data['paymentHistory'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(UdharPaymentRecord.fromMap)
          .toList(),
      reminderHistory: (data['reminderHistory'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(UdharReminderRecord.fromMap)
          .toList(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'personName': personName,
      'amount': amount,
      'type': type,
      'status': status,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'phoneNumber': phoneNumber,
      'personImageUrl': personImageUrl,
      'receiptUrl': receiptUrl,
      'interestType': interestType,
      'interestFrequency': interestFrequency,
      'interestValue': interestValue,
      'interestStartRule': interestStartRule,
      'settledAmount': settledAmount,
      'paymentHistory': paymentHistory.map((e) => e.toMap()).toList(),
      'reminderHistory': reminderHistory.map((e) => e.toMap()).toList(),
      'notes': notes,
    };
  }

  bool get hasInterest => interestType != interestTypeNone && interestValue > 0;

  DateTime? get interestStartDate {
    if (!hasInterest) return null;
    if (interestStartRule == interestStartFromDueDate && dueDate != null) {
      return dueDate;
    }
    return createdAt;
  }

  int elapsedInterestPeriods([DateTime? asOf]) {
    if (!hasInterest) return 0;

    final end = asOf ?? DateTime.now();
    final start = interestStartDate;
    if (start == null || !end.isAfter(start)) return 0;

    if (interestFrequency == interestFrequencyMonthly) {
      var months = (end.year - start.year) * 12 + (end.month - start.month);
      if (end.day < start.day) {
        months -= 1;
      }
      return months < 0 ? 0 : months;
    }

    final days = end.difference(start).inDays;
    return days < 0 ? 0 : days;
  }

  double accruedInterest([DateTime? asOf]) {
    if (!hasInterest) return 0.0;

    final periods = elapsedInterestPeriods(asOf);
    if (periods <= 0) return 0.0;

    if (interestType == interestTypePercent) {
      return amount * (interestValue / 100) * periods;
    }

    return interestValue * periods;
  }

  double totalDue([DateTime? asOf]) {
    return amount + accruedInterest(asOf);
  }

  double get remainingAmount {
    final remaining = totalDue() - settledAmount;
    return remaining < 0 ? 0 : remaining;
  }

  double remainingAmountAt([DateTime? asOf]) {
    final remaining = totalDue(asOf) - settledAmount;
    return remaining < 0 ? 0 : remaining;
  }

  String get interestLabel {
    if (!hasInterest) return 'No interest';

    final frequencyLabel = interestFrequency == interestFrequencyMonthly
        ? 'month'
        : 'day';
    if (interestType == interestTypePercent) {
      return '${interestValue.toStringAsFixed(interestValue % 1 == 0 ? 0 : 2)}% / $frequencyLabel';
    }
    return '₹${interestValue.toStringAsFixed(interestValue % 1 == 0 ? 0 : 2)} / $frequencyLabel';
  }

  String get interestStartLabel {
    return interestStartRule == interestStartFromDueDate
        ? 'Starts after due date'
        : 'Starts from lending date';
  }

  UdharTransaction copyWith({
    String? personName,
    double? amount,
    String? type,
    String? status,
    DateTime? dueDate,
    String? phoneNumber,
    String? personImageUrl,
    String? receiptUrl,
    String? interestType,
    String? interestFrequency,
    double? interestValue,
    String? interestStartRule,
    double? settledAmount,
    List<UdharPaymentRecord>? paymentHistory,
    List<UdharReminderRecord>? reminderHistory,
    String? notes,
  }) {
    return UdharTransaction(
      id: id,
      userId: userId,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      personImageUrl: personImageUrl ?? this.personImageUrl,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      interestType: interestType ?? this.interestType,
      interestFrequency: interestFrequency ?? this.interestFrequency,
      interestValue: interestValue ?? this.interestValue,
      interestStartRule: interestStartRule ?? this.interestStartRule,
      settledAmount: settledAmount ?? this.settledAmount,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      reminderHistory: reminderHistory ?? this.reminderHistory,
      notes: notes ?? this.notes,
    );
  }
}
