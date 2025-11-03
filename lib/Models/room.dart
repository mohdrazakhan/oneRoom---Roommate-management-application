// lib/Models/room.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String name;
  final String createdBy; // uid of creator
  final List<String> members; // list of uids
  final DateTime? createdAt;
  final String? photoUrl; // Room photo
  final String currency; // Currency for expenses (default: ₹)

  Room({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    this.createdAt,
    this.photoUrl,
    this.currency = '₹',
  });

  /// Create from a DocumentSnapshot (Firestore)
  factory Room.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final dynamic ts = data['createdAt'];
    DateTime? createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else if (ts is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      createdAt = DateTime.tryParse(ts);
    }

    return Room(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      createdBy: (data['createdBy'] ?? '') as String,
      members: List<String>.from(data['members'] ?? const []),
      createdAt: createdAt,
      photoUrl: data['photoUrl'] as String?,
      currency: (data['currency'] ?? '₹') as String,
    );
  }

  /// Create from plain map (if you read map + id separately)
  factory Room.fromMap(Map<String, dynamic> map, String id) {
    final dynamic ts = map['createdAt'];
    DateTime? createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else if (ts is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      createdAt = DateTime.tryParse(ts);
    }

    return Room(
      id: id,
      name: map['name'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? const []),
      createdAt: createdAt,
      photoUrl: map['photoUrl'] as String?,
      currency: (map['currency'] ?? '₹') as String,
    );
  }

  /// Convert to a map ready to send to Firestore.
  /// If createdAt is null, use server timestamp when writing.
  Map<String, dynamic> toMapForCreate() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'currency': currency,
    };
  }

  /// If you want a plain map using a DateTime (e.g. for local caching)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'members': members,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'photoUrl': photoUrl,
      'currency': currency,
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
  }) => Room(
    id: id ?? this.id,
    name: name ?? this.name,
    createdBy: createdBy ?? this.createdBy,
    members: members ?? List<String>.from(this.members),
    createdAt: createdAt ?? this.createdAt,
    photoUrl: photoUrl ?? this.photoUrl,
    currency: currency ?? this.currency,
  );
}
