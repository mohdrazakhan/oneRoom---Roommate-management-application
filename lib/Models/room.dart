// lib/Models/room.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'expense.dart';

class Room {
  final String id;
  final String name;
  final String createdBy; // uid of creator
  final List<String> members; // list of uids
  final DateTime createdAt;
  final String? photoUrl; // Room photo
  final String currency; // Currency for expenses (default: ₹)
  final String joinCode; // 6-digit code for joining
  final Map<String, dynamic> settings; // Flexible settings map
  final List<ExpenseCategory> customCategories;
  final Map<String, dynamic>
  guests; // Map of guestId -> {name, createdAt, isActive}

  Room({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.createdAt,
    this.photoUrl,
    this.currency = '₹',
    required this.joinCode,
    this.settings = const {},
    this.customCategories = const [],
    this.guests = const {},
  });

  /// Create from a DocumentSnapshot (Firestore)
  factory Room.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final dynamic ts = data['createdAt'];
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

    return Room(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      createdBy: (data['createdBy'] ?? '') as String,
      members: List<String>.from(data['members'] ?? const []),
      createdAt: createdAt,
      photoUrl: data['photoUrl'] as String?,
      currency: (data['currency'] ?? '₹') as String,
      joinCode: (data['joinCode'] ?? '') as String,
      settings: data['settings'] != null
          ? Map<String, dynamic>.from(data['settings'])
          : const {},
      customCategories:
          (data['customCategories'] as List<dynamic>?)
              ?.map(
                (c) => ExpenseCategory.createCustom(
                  c['name'] as String,
                  c['emoji'] as String,
                  color: c['colorValue'] as int?,
                ),
              )
              .toList() ??
          const [],
      guests: data['guests'] != null
          ? Map<String, dynamic>.from(data['guests'])
          : const {},
    );
  }

  /// Create from plain map (if you read map + id separately)
  factory Room.fromMap(Map<String, dynamic> map, String id) {
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

    return Room(
      id: id,
      name: map['name'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? const []),
      createdAt: createdAt,
      photoUrl: map['photoUrl'] as String?,
      currency: (map['currency'] ?? '₹') as String,
      joinCode: map['joinCode'] ?? '',
      settings: map['settings'] != null
          ? Map<String, dynamic>.from(map['settings'])
          : const {},
      customCategories:
          (map['customCategories'] as List<dynamic>?)
              ?.map(
                (c) => ExpenseCategory.createCustom(
                  c['name'] as String,
                  c['emoji'] as String,
                  color: c['colorValue'] as int?,
                ),
              )
              .toList() ??
          const [],
      guests: map['guests'] != null
          ? Map<String, dynamic>.from(map['guests'])
          : const {},
    );
  }

  /// Convert to a map ready to send to Firestore.
  Map<String, dynamic> toMapForCreate() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'currency': currency,
      'joinCode': joinCode,
      'settings': settings,
      'customCategories': customCategories
          .map(
            (c) => {
              'name': c.name,
              'emoji': c.icon,
              'colorValue': c.colorValue,
            },
          )
          .toList(),
      'guests': guests,
    };
  }

  /// If you want a plain map using a DateTime (e.g. for local caching)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      'photoUrl': photoUrl,
      'currency': currency,
      'joinCode': joinCode,
      'settings': settings,
      'customCategories': customCategories
          .map(
            (c) => {
              'name': c.name,
              'emoji': c.icon,
              'colorValue': c.colorValue,
            },
          )
          .toList(),
      'guests': guests,
    };
  }

  Room copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? members,
    DateTime? createdAt,
    String? photoUrl,
    String? currency,
    String? joinCode,
    Map<String, dynamic>? settings,
    List<ExpenseCategory>? customCategories,
    Map<String, dynamic>? guests,
  }) => Room(
    id: id ?? this.id,
    name: name ?? this.name,
    createdBy: createdBy ?? this.createdBy,
    members: members ?? List<String>.from(this.members),
    createdAt: createdAt ?? this.createdAt,
    photoUrl: photoUrl ?? this.photoUrl,
    currency: currency ?? this.currency,
    joinCode: joinCode ?? this.joinCode,
    settings: settings ?? Map.from(this.settings),
    customCategories: customCategories ?? List.from(this.customCategories),
    guests: guests ?? Map.from(this.guests),
  );
}
