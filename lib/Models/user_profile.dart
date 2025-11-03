// lib/Models/user_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? phoneNumber;
  final String? tagline;
  final DateTime? dateOfBirth;
  final List<String> joinedRooms; // optional list of roomIds
  final bool notificationsEnabled;
  final bool taskRemindersEnabled;
  final bool expenseRemindersEnabled;

  UserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.phoneNumber,
    this.tagline,
    this.dateOfBirth,
    List<String>? joinedRooms,
    this.notificationsEnabled = true,
    this.taskRemindersEnabled = true,
    this.expenseRemindersEnabled = true,
  }) : joinedRooms = joinedRooms ?? [];

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'],
      email: data['email'],
      photoUrl: data['photoUrl'],
      phoneNumber: data['phoneNumber'],
      tagline: data['tagline'],
      dateOfBirth: data['dateOfBirth'] != null
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : null,
      joinedRooms: List<String>.from(data['joinedRooms'] ?? const []),
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      taskRemindersEnabled: data['taskRemindersEnabled'] ?? true,
      expenseRemindersEnabled: data['expenseRemindersEnabled'] ?? true,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'],
      email: map['email'],
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      tagline: map['tagline'],
      dateOfBirth: map['dateOfBirth'] != null
          ? (map['dateOfBirth'] as Timestamp).toDate()
          : null,
      joinedRooms: List<String>.from(map['joinedRooms'] ?? const []),
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      taskRemindersEnabled: map['taskRemindersEnabled'] ?? true,
      expenseRemindersEnabled: map['expenseRemindersEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMapForCreate() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'tagline': tagline,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'joinedRooms': joinedRooms,
      'notificationsEnabled': notificationsEnabled,
      'taskRemindersEnabled': taskRemindersEnabled,
      'expenseRemindersEnabled': expenseRemindersEnabled,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? phoneNumber,
    String? tagline,
    DateTime? dateOfBirth,
    List<String>? joinedRooms,
    bool? notificationsEnabled,
    bool? taskRemindersEnabled,
    bool? expenseRemindersEnabled,
  }) => UserProfile(
    uid: uid ?? this.uid,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    photoUrl: photoUrl ?? this.photoUrl,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    tagline: tagline ?? this.tagline,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    joinedRooms: joinedRooms ?? List<String>.from(this.joinedRooms),
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
    expenseRemindersEnabled:
        expenseRemindersEnabled ?? this.expenseRemindersEnabled,
  );
}
