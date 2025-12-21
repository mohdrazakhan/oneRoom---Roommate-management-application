// lib/Models/expense_v2.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced Expense model with multiple payers, audit log, and edit history
class ExpenseV2 {
  final String id;
  final String roomId;
  final String description;
  final double amount;

  // MULTIPLE PAYERS SUPPORT
  final Map<String, double> paidBy; // UID -> amount they paid

  final DateTime purchaseDate; // When the expense occurred
  final DateTime createdAt; // When it was added to system
  final DateTime? updatedAt; // Last edit time

  final String category;
  final List<String> splitAmong; // UIDs of people to split among
  final Map<String, double> splits; // UID -> amount they owe
  final String? notes;
  final String? receiptUrl;
  final Map<String, bool> settledWith; // UID -> has this person settled?

  // AUDIT LOG
  final List<AuditEntry> auditLog; // All changes made to this expense
  final String createdBy; // UID of person who created this

  ExpenseV2({
    required this.id,
    required this.roomId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.purchaseDate,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.category = 'Other',
    required this.splitAmong,
    required this.splits,
    this.notes,
    this.receiptUrl,
    Map<String, bool>? settledWith,
    List<AuditEntry>? auditLog,
  }) : settledWith = settledWith ?? {},
       auditLog = auditLog ?? [];

  factory ExpenseV2.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse paidBy - support both old single payer and new multiple payers
    Map<String, double> paidByMap = {};
    final paidByData = data['paidBy'];
    if (paidByData is String) {
      // Old format - single payer
      paidByMap[paidByData] = (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0);
    } else if (paidByData is Map) {
      // New format - multiple payers
      paidByData.forEach((key, value) {
        paidByMap[key] = (value is int) ? value.toDouble() : (value as double);
      });
    }

    // Parse audit log
    List<AuditEntry> auditLog = [];
    final auditLogData = data['auditLog'] as List?;
    if (auditLogData != null) {
      auditLog = auditLogData
          .map((e) => AuditEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return ExpenseV2(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] ?? 0.0),
      paidBy: paidByMap,
      purchaseDate:
          (data['purchaseDate'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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
      auditLog: auditLog,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'category': category,
      'splitAmong': splitAmong,
      'splits': splits,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'settledWith': settledWith,
      'auditLog': auditLog.map((e) => e.toMap()).toList(),
    };
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

  // Get total amount paid by a specific user
  double getAmountPaidBy(String uid) {
    return paidBy[uid] ?? 0.0;
  }

  // Check if multiple people paid
  bool get hasMultiplePayers => paidBy.length > 1;

  // Get primary payer (who paid the most)
  String get primaryPayer {
    if (paidBy.isEmpty) return '';
    return paidBy.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

/// Audit log entry for tracking all changes
class AuditEntry {
  final String action; // 'created', 'updated', 'deleted'
  final String performedBy; // UID of person who made the change
  final DateTime timestamp;
  final Map<String, dynamic>? changes; // What was changed (optional)
  final String? notes; // Additional notes about the change

  AuditEntry({
    required this.action,
    required this.performedBy,
    required this.timestamp,
    this.changes,
    this.notes,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    return AuditEntry(
      action: map['action'] ?? 'unknown',
      performedBy: map['performedBy'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      changes: map['changes'] as Map<String, dynamic>?,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'performedBy': performedBy,
      'timestamp': Timestamp.fromDate(timestamp),
      if (changes != null) 'changes': changes,
      if (notes != null) 'notes': notes,
    };
  }

  // Create audit entry for creation
  static AuditEntry created(String performedBy, {String? notes}) {
    return AuditEntry(
      action: 'created',
      performedBy: performedBy,
      timestamp: DateTime.now(),
      notes: notes,
    );
  }

  // Create audit entry for update
  static AuditEntry updated(
    String performedBy,
    Map<String, dynamic> changes, {
    String? notes,
  }) {
    return AuditEntry(
      action: 'updated',
      performedBy: performedBy,
      timestamp: DateTime.now(),
      changes: changes,
      notes: notes,
    );
  }

  // Create audit entry for deletion
  static AuditEntry deleted(String performedBy, {String? notes}) {
    return AuditEntry(
      action: 'deleted',
      performedBy: performedBy,
      timestamp: DateTime.now(),
      notes: notes,
    );
  }
}

// Keep the existing ExpenseCategory class
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
      orElse: () => categories.last,
    );
  }
}
