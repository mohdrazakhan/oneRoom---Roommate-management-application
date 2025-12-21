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
  final bool chatNotificationsEnabled;
  final bool expensePaymentAlertsEnabled;
  final List<String> roomOrder; // Custom defined order of rooms
  final String subscriptionTier; // 'free', 'standard', 'plus'

  // Backwards compatibility helpers
  bool get isPremium => true; // Premium features enabled for EVERYONE
  bool get isAdFree => subscriptionTier == 'plus';

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
    this.chatNotificationsEnabled = true,
    this.expensePaymentAlertsEnabled = true,
    List<String>? roomOrder,
    this.subscriptionTier = 'free',
  }) : joinedRooms = joinedRooms ?? [],
       roomOrder = roomOrder ?? [];

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    if (doc.data() == null) {
      // Handle the case where the document exists but has no data
      // This might happen if we just created the user auth but not the profile doc yet?
      // Or simply throw or return default.
      return UserProfile(uid: doc.id);
    }
    return UserProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    // Logic to determine tier
    String tier = map['subscriptionTier'] as String? ?? 'free';

    // Legacy mapping: if no tier defined, but isPremium is true, assume standard or plus.
    // Let's map legacy isPremium to Standard (or Plus if we want to be generous).
    // Given the user request "two premium plan", let's map legacy to Standard to maintain "ads remain same" functionality?
    // User said "unlimited access all app feature but ads remain same" is one plan.
    // The previous implementation had NO ads for premium.
    // So if a user was previously Premium, they expected NO ads.
    // Therefore, legacy isPremium should map to 'plus' (No Ads).
    if (tier == 'free' && map['isPremium'] == true) {
      tier = 'plus';
    }

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
      chatNotificationsEnabled: map['chatNotificationsEnabled'] ?? true,
      expensePaymentAlertsEnabled: map['expensePaymentAlertsEnabled'] ?? true,
      roomOrder: List<String>.from(map['roomOrder'] ?? const []),
      subscriptionTier: tier,
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
      'chatNotificationsEnabled': chatNotificationsEnabled,
      'expensePaymentAlertsEnabled': expensePaymentAlertsEnabled,
      'roomOrder': roomOrder,
      'subscriptionTier': subscriptionTier,
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
    bool? chatNotificationsEnabled,
    bool? expensePaymentAlertsEnabled,
    List<String>? roomOrder,
    String? subscriptionTier,
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
    chatNotificationsEnabled:
        chatNotificationsEnabled ?? this.chatNotificationsEnabled,
    expensePaymentAlertsEnabled:
        expensePaymentAlertsEnabled ?? this.expensePaymentAlertsEnabled,
    roomOrder: roomOrder ?? List<String>.from(this.roomOrder),
    subscriptionTier: subscriptionTier ?? this.subscriptionTier,
  );
}
