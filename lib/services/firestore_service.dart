// ignore_for_file: avoid_print
// lib/services/firestore_service.dart
// Firestore helper: rooms, expenses, users
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:flutter/foundation.dart';
import '../Models/expense.dart';
import '../Models/room_notification.dart';
import '../Models/task.dart';
import '../Models/task_category.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Simple in-memory cache for user profiles to speed up repeated lookups
  final Map<String, Map<String, dynamic>> _profileCache = {};

  /// Top-level collection references
  CollectionReference get _rooms => _db.collection('rooms');
  CollectionReference get _users => _db.collection('users');

  /// ---------------------------
  ///            ROOMS
  /// ---------------------------

  /// Stream rooms where the given uid is a member.
  /// Each item in the emitted list is a `Map<String, dynamic>` and includes an 'id' field.
  Stream<List<Map<String, dynamic>>> roomsForUser(String uid) {
    return _rooms
        .where('members', arrayContains: uid)
        // Note: orderBy requires a composite index with array-contains
        // For now, we'll sort in-memory. Create the index in Firebase Console for better performance.
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            return {...m, 'id': d.id};
          }).toList();

          // Sort in-memory by createdAt
          docs.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // descending
          });

          return docs;
        });
  }

  /// Stream a single room document (map with 'id')
  Stream<Map<String, dynamic>?> streamRoomById(String roomId) {
    return _rooms.doc(roomId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final m = snap.data() as Map<String, dynamic>;
      return {...m, 'id': snap.id};
    });
  }

  /// Create a room and return the created document id.
  Future<String> createRoom({
    required String name,
    required String createdBy,
  }) async {
    final doc = _rooms.doc();
    await doc.set({
      'name': name,
      'createdBy': createdBy,
      'members': [createdBy],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Add a member uid to a room.members array
  Future<void> addMember(String roomId, String uid) async {
    await _rooms.doc(roomId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  /// Remove a member uid from a room.members array
  Future<void> removeMember(String roomId, String uid) async {
    await _rooms.doc(roomId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  /// Update room details
  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _rooms.doc(roomId).update(data);
  }

  /// Delete a room and all its subcollections
  Future<void> deleteRoom(String roomId) async {
    // Delete all expenses
    final expensesSnapshot = await expensesRef(roomId).get();
    for (var doc in expensesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete all tasks
    final tasksSnapshot = await _rooms.doc(roomId).collection('tasks').get();
    for (var doc in tasksSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete all task categories
    final categoriesSnapshot = await _rooms
        .doc(roomId)
        .collection('task_categories')
        .get();
    for (var doc in categoriesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the room itself
    await _rooms.doc(roomId).delete();
  }

  /// Get a one-time snapshot of room as a Map (includes 'id') or null if missing.
  Future<Map<String, dynamic>?> getRoomById(String roomId) async {
    final snap = await _rooms.doc(roomId).get();
    if (!snap.exists) return null;
    final m = snap.data() as Map<String, dynamic>;
    return {...m, 'id': snap.id};
  }

  /// ---------------------------
  /// EXPENSES (subcollection: rooms/{roomId}/expenses)
  /// ---------------------------

  CollectionReference expensesRef(String roomId) =>
      _rooms.doc(roomId).collection('expenses');

  /// Add a custom category to the room
  Future<void> addCategoryToRoom(
    String roomId,
    String name,
    String emoji,
  ) async {
    final categoryData = {'name': name, 'emoji': emoji};
    await _rooms.doc(roomId).update({
      'customCategories': FieldValue.arrayUnion([categoryData]),
    });
  }

  /// Remove a custom category from the room
  Future<void> removeCategoryFromRoom(
    String roomId,
    String name,
    String emoji,
  ) async {
    final categoryData = {'name': name, 'emoji': emoji};
    await _rooms.doc(roomId).update({
      'customCategories': FieldValue.arrayRemove([categoryData]),
    });
  }

  /// Add a guest to the room
  Future<String> addGuestToRoom(String roomId, String guestName) async {
    // We store guests in a map: guests.guestId = {name: ..., ...}
    // Generate a simple guest ID
    final guestId =
        'guest_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

    final guestData = {
      'name': guestName.trim(),
      'createdAt': Timestamp.now(),
      'isActive': true,
    };

    await _rooms.doc(roomId).update({'guests.$guestId': guestData});

    return guestId;
  }

  /// Resolve a user's display name by uid. Returns null if not found.
  Future<String?> getUserDisplayName(String uid) async {
    try {
      final snap = await _users.doc(uid).get();
      if (!snap.exists) return null;
      final m = snap.data() as Map<String, dynamic>;
      String? name = (m['displayName'] ?? m['name']) as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
      // fallback to email local-part
      final email = m['email'] as String?;
      if (email != null && email.contains('@')) {
        return email.split('@').first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Stream list of expenses for a room. Each expense map includes 'id'.
  Stream<List<Map<String, dynamic>>> expensesForRoom(String roomId) {
    return expensesRef(roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            return {...m, 'id': d.id};
          }).toList(),
        );
  }

  /// Add expense document to room's expenses subcollection.
  /// Returns the created expense doc id.
  Future<String> addExpense({
    required String roomId,
    required String description,
    required double amount,
    required String paidBy,
    Map<String, double>? payers,
    required String category,
    required List<String> splitAmong,
    required Map<String, double> splits,
    String? notes,
    String? receiptUrl,
    DateTime? createdAt,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final doc = expensesRef(roomId).doc();
    final payload = {
      'roomId': roomId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      if (payers != null && payers.isNotEmpty) 'payers': payers,
      'category': category,
      'splitAmong': splitAmong,
      'splits': splits,
      if (notes != null) 'notes': notes,
      if (receiptUrl != null) 'receiptUrl': receiptUrl,
      'settledWith': <String, bool>{}, // Initially no one has settled
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt)
          : FieldValue.serverTimestamp(),
    };
    await doc.set(payload);

    // Create notifications for all room members (except the creator)
    if (currentUserId != null) {
      final roomDoc = await _rooms.doc(roomId).get();
      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        final members = List<String>.from(roomData['members'] ?? []);
        final actorProfile = await getUserProfile(currentUserId);
        final actorName = actorProfile?['displayName'] ?? 'Someone';

        for (final memberId in members) {
          if (memberId != currentUserId) {
            await createNotification(
              roomId: roomId,
              userId: memberId,
              type: NotificationType.expenseAdded,
              title: 'New Expense',
              message:
                  '$actorName added "$description" - ₹${amount.toStringAsFixed(2)}',
              actorId: currentUserId,
              actorName: actorName,
              relatedId: doc.id,
            );
          }
        }
      }

      // Add Audit Log
      try {
        await _rooms.doc(roomId).collection('auditLog').add({
          'action': 'created',
          'performedBy': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'expenseDescription': description,
          'changes': {
            'amount': amount.toStringAsFixed(2),
            'paid by': paidBy,
            'category': category,
          },
        });
      } catch (_) {
        // Ignore audit failure
      }
    }

    return doc.id;
  }

  /// Update an expense
  Future<void> updateExpense({
    required String roomId,
    required String expenseId,
    String? description,
    double? amount,
    String? paidBy,
    Map<String, double>? payers,
    String? category,
    List<String>? splitAmong,
    Map<String, double>? splits,
    String? notes,
    String? receiptUrl,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final updates = <String, dynamic>{};
    if (description != null) updates['description'] = description;
    if (amount != null) updates['amount'] = amount;
    if (paidBy != null) updates['paidBy'] = paidBy;
    if (payers != null) updates['payers'] = payers;
    if (category != null) updates['category'] = category;
    if (splitAmong != null) updates['splitAmong'] = splitAmong;
    if (splits != null) updates['splits'] = splits;
    if (notes != null) updates['notes'] = notes;
    if (receiptUrl != null) updates['receiptUrl'] = receiptUrl;
    updates['updatedAt'] = FieldValue.serverTimestamp();

    if (updates.isNotEmpty) {
      await expensesRef(roomId).doc(expenseId).update(updates);

      // Create notifications for all room members (except the updater)
      if (currentUserId != null) {
        final roomDoc = await _rooms.doc(roomId).get();
        if (roomDoc.exists) {
          final roomData = roomDoc.data() as Map<String, dynamic>;
          final members = List<String>.from(roomData['members'] ?? []);
          final actorProfile = await getUserProfile(currentUserId);
          final actorName = actorProfile?['displayName'] ?? 'Someone';

          final expenseDescription = description ?? 'an expense';

          for (final memberId in members) {
            if (memberId != currentUserId) {
              await createNotification(
                roomId: roomId,
                userId: memberId,
                type: NotificationType.expenseEdited,
                title: 'Expense Updated',
                message: '$actorName updated "$expenseDescription"',
                actorId: currentUserId,
                actorName: actorName,
                relatedId: expenseId,
              );
            }
          }
        }

        // Add Audit Log
        try {
          final changesForLog = <String, String>{};
          if (amount != null) {
            changesForLog['amount'] = amount.toStringAsFixed(2);
          }
          if (paidBy != null) changesForLog['paid by'] = paidBy;
          if (category != null) changesForLog['category'] = category;
          if (description != null) changesForLog['description'] = description;

          await _rooms.doc(roomId).collection('auditLog').add({
            'action': 'updated',
            'performedBy': currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
            'expenseDescription': description ?? 'Expense',
            'changes': changesForLog,
          });
        } catch (_) {
          // Ignore audit failure
        }
      }
    }
  }

  /// Delete an expense document
  Future<void> deleteExpense(String roomId, String expenseId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final expRef = expensesRef(roomId).doc(expenseId);

    // Fetch minimal info before deleting for the audit entry
    String? description;
    double? amount;
    String? paidByUid;
    String? createdOnFormatted;
    try {
      final snap = await expRef.get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        description = data['description'] as String?;
        amount = (data['amount'] is int)
            ? (data['amount'] as int).toDouble()
            : (data['amount'] as double?);
        paidByUid = data['paidBy'] as String?;
        final createdTs = data['createdAt'] as Timestamp?;
        // Store as human friendly string later in changes map
        if (createdTs != null) {
          final d = createdTs.toDate();
          // dd/MM/yyyy format
          final dd = d.day.toString().padLeft(2, '0');
          final mm = d.month.toString().padLeft(2, '0');
          final yyyy = d.year.toString();
          // temporarily stash using paidByUid variable? better create a local
          // We'll add directly to changes map after we create it below via closure variable
          // Using a temp variable here for readability
          final createdOnStr = '$dd/$mm/$yyyy';
          createdOnFormatted = createdOnStr;
        }
      }
    } catch (_) {}

    // Delete the expense
    await expRef.delete();

    // Create notifications for all room members (except the deleter)
    if (currentUserId != null && description != null) {
      final roomDoc = await _rooms.doc(roomId).get();
      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        final members = List<String>.from(roomData['members'] ?? []);
        final actorProfile = await getUserProfile(currentUserId);
        final actorName = actorProfile?['displayName'] ?? 'Someone';

        for (final memberId in members) {
          if (memberId != currentUserId) {
            await createNotification(
              roomId: roomId,
              userId: memberId,
              type: NotificationType.expenseDeleted,
              title: 'Expense Deleted',
              message: '$actorName deleted "$description"',
              actorId: currentUserId,
              actorName: actorName,
              relatedId: expenseId,
            );
          }
        }
      }
    }

    // Write immutable audit log entry (best-effort)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Resolve a nice display for paidBy if possible
      String? paidByDisplay;
      if (paidByUid != null && paidByUid.isNotEmpty) {
        try {
          final userSnap = await _users.doc(paidByUid).get();
          if (userSnap.exists) {
            final u = userSnap.data() as Map<String, dynamic>;
            paidByDisplay = (u['displayName'] ?? u['name']) as String?;
            paidByDisplay ??= (u['email'] is String)
                ? (u['email'] as String).split('@')[0]
                : null;
          }
        } catch (_) {}
      }

      final changes = <String, String>{};
      if (amount != null) {
        changes['amount'] = amount.toStringAsFixed(2);
      }
      if (paidByUid != null) {
        changes['paid by'] = paidByDisplay ?? paidByUid;
      }
      if (createdOnFormatted != null) {
        changes['created on'] = createdOnFormatted;
      }

      await _rooms.doc(roomId).collection('auditLog').add({
        'action': 'deleted',
        'performedBy': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'expenseDescription': description,
        if (changes.isNotEmpty) 'changes': changes,
        // No changes map on delete
      });
    } catch (_) {
      // Ignore audit failures so delete still succeeds
    }
  }

  /// Get one expense (one-time)
  Future<Map<String, dynamic>?> getExpense(
    String roomId,
    String expenseId,
  ) async {
    final snap = await expensesRef(roomId).doc(expenseId).get();
    if (!snap.exists) return null;
    final m = snap.data() as Map<String, dynamic>;
    return {...m, 'id': snap.id};
  }

  /// Stream expenses as Expense objects
  Stream<List<Expense>> getExpensesStream(String roomId) {
    return expensesRef(roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Expense.fromDoc(doc)).toList());
  }

  /// Get expenses as Stream of `List<Expense>` (alias for better clarity)
  Stream<List<Expense>> getExpenses(String roomId) {
    return getExpensesStream(roomId);
  }

  /// Mark an expense as settled for a specific member
  Future<void> settleExpense({
    required String roomId,
    required String expenseId,
    required String settlerUid,
  }) async {
    await expensesRef(
      roomId,
    ).doc(expenseId).update({'settledWith.$settlerUid': true});

    // Add audit log entry
    try {
      final expenseDoc = await expensesRef(roomId).doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>?;
      final description = expenseData?['description'] ?? 'Unknown expense';

      await _rooms.doc(roomId).collection('auditLog').add({
        'action': 'settled',
        'performedBy': settlerUid,
        'timestamp': FieldValue.serverTimestamp(),
        'expenseDescription': description,
      });
    } catch (_) {
      // Ignore audit failures so settle still succeeds
    }
  }

  /// Mark an expense as unsettled for a specific member
  Future<void> unsettleExpense({
    required String roomId,
    required String expenseId,
    required String settlerUid,
  }) async {
    await expensesRef(
      roomId,
    ).doc(expenseId).update({'settledWith.$settlerUid': false});

    // Add audit log entry
    try {
      final expenseDoc = await expensesRef(roomId).doc(expenseId).get();
      final expenseData = expenseDoc.data() as Map<String, dynamic>?;
      final description = expenseData?['description'] ?? 'Unknown expense';

      await _rooms.doc(roomId).collection('auditLog').add({
        'action': 'unsettled',
        'performedBy': settlerUid,
        'timestamp': FieldValue.serverTimestamp(),
        'expenseDescription': description,
      });
    } catch (_) {
      // Ignore audit failures so unsettle still succeeds
    }
  }

  /// Get a single expense as a stream for real-time updates
  Stream<Expense?> getExpenseStream(String roomId, String expenseId) {
    return expensesRef(roomId).doc(expenseId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>;
      return Expense.fromMap(data, snapshot.id);
    });
  }

  /// Get room as a Map (for accessing member UIDs)
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    return getRoomById(roomId);
  }

  /// Upload receipt image to Firebase Storage
  Future<String> uploadReceipt(dynamic receiptFile, String roomId) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(
        'receipts/$roomId/$fileName',
      );

      if (receiptFile is File) {
        await ref.putFile(receiptFile);
      } else if (receiptFile is Uint8List) {
        await ref.putData(receiptFile);
      } else {
        throw Exception('Unsupported file type');
      }

      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading receipt: $e');
      rethrow;
    }
  }

  /// ---------------------------
  /// USERS
  /// ---------------------------

  /// Get user profile doc (one-time). Returns map including 'id' (uid) or null.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (_profileCache.containsKey(uid)) {
      return _profileCache[uid];
    }

    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    final m = snap.data() as Map<String, dynamic>;
    final data = {...m, 'id': snap.id};

    _profileCache[uid] = data; // Store in cache
    return data;
  }

  /// Stream user profile changes (map with 'id')
  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final m = snap.data() as Map<String, dynamic>;
      return {...m, 'id': snap.id};
    });
  }

  /// Update (merge) user profile fields
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Update just the room order for a user
  Future<void> updateUserRoomOrder(String uid, List<String> order) async {
    await _users.doc(uid).update({'roomOrder': order});
  }

  /// ---------------------------
  /// UTILITIES / ADMIN HELPERS
  /// ---------------------------

  /// Simple helper: ensure user is added to room.members (idempotent)
  Future<void> joinRoom(String roomId, String uid) async {
    await _rooms.doc(roomId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
    // optionally update users/{uid}.joinedRooms - keep denormalization decision to you
  }

  /// Simple helper: leave room
  Future<void> leaveRoom(String roomId, String uid) async {
    await _rooms.doc(roomId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  /// Get a single task by ID
  Future<Task?> getTask(String roomId, String taskId) async {
    try {
      final doc = await _rooms
          .doc(roomId)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!doc.exists) return null;
      return Task.fromFirestore(doc);
    } catch (e) {
      print('Error getting task: $e');
      return null;
    }
  }

  /// Get a single task category by ID
  Future<TaskCategory?> getCategory(String roomId, String categoryId) async {
    try {
      final doc = await _rooms
          .doc(roomId)
          .collection('task_categories')
          .doc(categoryId)
          .get();

      if (!doc.exists) return null;
      return TaskCategory.fromFirestore(doc);
    } catch (e) {
      print('Error getting category: $e');
      return null;
    }
  }

  /// Get total count of tasks across all rooms the user is a member of
  Future<int> getTotalTasksCount(String uid) async {
    int totalTasks = 0;

    // Get all rooms where user is a member
    final roomsSnapshot = await _rooms
        .where('members', arrayContains: uid)
        .get();

    // Count tasks in each room
    for (var roomDoc in roomsSnapshot.docs) {
      final tasksSnapshot = await _rooms
          .doc(roomDoc.id)
          .collection('tasks')
          .get();
      totalTasks += tasksSnapshot.docs.length;
    }

    return totalTasks;
  }

  /// Get users data for multiple UIDs
  Future<Map<String, Map<String, dynamic>>> getUsersProfiles(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return {};

    final Map<String, Map<String, dynamic>> profiles = {};

    // Parallel fetch for speed
    final futures = uids.map((uid) => getUserProfile(uid));
    final results = await Future.wait(futures);

    for (final profile in results) {
      if (profile != null) {
        final uid = profile['id'] as String;
        profiles[uid] = profile;
      }
    }

    return profiles;
  }

  /// Get audit log stream for a room (for transparency)
  /// Returns a list of plain maps to avoid runtime type issues in widgets.
  Stream<List<Map<String, dynamic>>> getRoomAuditLogStream(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('auditLog')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'action': data['action'] ?? 'unknown',
              'performedBy': data['performedBy'] ?? '',
              'timestamp':
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'expenseDescription': data['expenseDescription'],
              'changes': data['changes'] as Map<String, dynamic>?,
            };
          }).toList();
        });
  }

  /// ---------------------------
  /// PAYMENTS (subcollection: rooms/{roomId}/payments)
  /// ---------------------------

  CollectionReference paymentsRef(String roomId) =>
      _rooms.doc(roomId).collection('payments');

  /// Add a payment record (Member A paid Member B)
  /// Add a payment record (Member A paid Member B)
  Future<void> addPayment({
    required String roomId,
    required String payerId,
    required String receiverId,
    required double amount,
    String? note,
    required String createdBy,
  }) async {
    await paymentsRef(roomId).add({
      'roomId': roomId,
      'payerId': payerId,
      'receiverId': receiverId,
      'amount': amount,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    });

    // Add Audit Log
    try {
      final payerProfile = await getUserProfile(payerId);
      final receiverProfile = await getUserProfile(receiverId);
      final payerName = payerProfile?['displayName'] ?? 'Unknown';
      final receiverName = receiverProfile?['displayName'] ?? 'Unknown';

      await _rooms.doc(roomId).collection('auditLog').add({
        'action':
            'created', // Using generic 'created' or 'payment' if supported
        'performedBy': createdBy,
        'timestamp': FieldValue.serverTimestamp(),
        'expenseDescription': 'Payment: $payerName → $receiverName',
        'changes': {'amount': '$amount'},
      });
    } catch (_) {
      // Ignore audit failure
    }

    // Send Notification
    try {
      // If Payer added it, notify Receiver
      if (createdBy == payerId) {
        final payerProfile = await getUserProfile(payerId);
        final payerName = payerProfile?['displayName'] ?? 'Member';
        await createNotification(
          roomId: roomId,
          userId: receiverId,
          type: NotificationType.paymentRecorded,
          title: 'Payment Received',
          message: '$payerName recorded a payment of $amount to you.',
          actorId: payerId,
          actorName: payerName,
        );
      }
      // If Receiver added it, notify Payer
      else if (createdBy == receiverId) {
        final receiverProfile = await getUserProfile(receiverId);
        final receiverName = receiverProfile?['displayName'] ?? 'Member';
        await createNotification(
          roomId: roomId,
          userId: payerId,
          type: NotificationType.paymentRecorded,
          title: 'Payment Recorded',
          message: '$receiverName recorded a payment of $amount from you.',
          actorId: receiverId,
          actorName: receiverName,
        );
      }
      // If someone else added it, notify both (optional, but good practice)
      else {
        // ... logic for 3rd party adding payment if needed
      }
    } catch (e) {
      print('Failed to send payment notification: $e');
    }
  }

  /// Stream all payments for a room
  Stream<List<Map<String, dynamic>>> paymentsForRoom(String roomId) {
    return paymentsRef(
      roomId,
    ).orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();
    });
  }

  /// Delete a payment
  /// Delete a payment
  Future<void> deletePayment(
    String roomId,
    String paymentId,
    String deletedBy,
  ) async {
    await paymentsRef(roomId).doc(paymentId).delete();

    // Add Audit Log
    try {
      await _rooms.doc(roomId).collection('auditLog').add({
        'action': 'deleted',
        'performedBy': deletedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'expenseDescription': 'Payment deleted',
      });
    } catch (_) {
      // Ignore audit failure
    }
  }

  /// ---------------------------
  /// TASK INSTANCES & MANAGEMENT
  /// ---------------------------

  // ---------- Real-time Helper ----------

  /// Combines streams from all rooms a user is in.
  /// 1. Listens to the user's room list.
  /// 2. Subscribes to a query for each room.
  /// 3. Emits a combined, sorted list whenever ANY data changes.
  Stream<List<Map<String, dynamic>>> _roomsTaskStream({
    required String userId,
    required Query Function(String roomId) queryBuilder,
    required int Function(Map<String, dynamic> a, Map<String, dynamic> b)
    sorter,
  }) {
    // We use a StreamController to emit the final combined list
    // We can't use rxdart without adding the dependency, so we implement a manual SwitchMap + CombineLatest style logic.
    StreamController<List<Map<String, dynamic>>>? controller;

    // The subscription to the list of rooms
    StreamSubscription? roomsSubscription;

    // Map of RoomId -> Subscription to that room's tasks
    final Map<String, StreamSubscription> roomSubscriptions = {};

    // Map of RoomId -> List of tasks (latest data)
    final Map<String, List<Map<String, dynamic>>> roomData = {};

    // Helper to emit the current state
    void emit() {
      if (controller == null || controller.isClosed) return;
      final all = roomData.values.expand((x) => x).toList();
      all.sort(sorter);
      controller.add(all);
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        // 1. Subscribe to the user's rooms
        roomsSubscription = _rooms
            .where('members', arrayContains: userId)
            .snapshots()
            .listen((roomsSnap) {
              final currentRoomIds = roomsSnap.docs.map((d) => d.id).toSet();

              // A. Remove stale subscriptions
              final staleIds = roomSubscriptions.keys
                  .where((id) => !currentRoomIds.contains(id))
                  .toList();
              for (final id in staleIds) {
                roomSubscriptions[id]?.cancel();
                roomSubscriptions.remove(id);
                roomData.remove(id);
              }

              // B. Add new subscriptions or update existing
              for (final doc in roomsSnap.docs) {
                final roomId = doc.id;
                final roomName =
                    (doc.data() as Map<String, dynamic>)['name'] ?? 'Room';

                if (!roomSubscriptions.containsKey(roomId)) {
                  // Create query using the provided builder
                  final query = queryBuilder(roomId);

                  roomSubscriptions[roomId] = query.snapshots().listen((
                    taskSnap,
                  ) {
                    // Process these tasks
                    final tasks = taskSnap.docs.map((d) {
                      final m = d.data() as Map<String, dynamic>;
                      return {
                        ...m,
                        'taskInstanceId': d.id,
                        'roomId': roomId,
                        'roomName': roomName,
                      };
                    }).toList();

                    // Client-side filtering if needed (e.g. for assignedTo)
                    // We assume the queryBuilder does most of the heavy lifting,
                    // but we might need to filter 'assignedTo' if the query didn't cover it fully
                    // (e.g. if avoiding composite indexes).
                    // For simplicity, we'll let the caller handle complex filtering if they strictly query by date
                    // or we can filter here.
                    // Let's rely on the queryBuilder to be specific.

                    roomData[roomId] = tasks;
                    emit();
                  });
                }
              }

              // If no rooms, emit empty
              if (currentRoomIds.isEmpty) {
                roomData.clear();
                emit();
              }
            });
      },
      onCancel: () {
        roomsSubscription?.cancel();
        for (final sub in roomSubscriptions.values) {
          sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  /// Get today's tasks for a user (Real-time)
  Stream<List<Map<String, dynamic>>> getTodayTasksForUser(String userId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startOfDayTs = Timestamp.fromDate(startOfDay);
    final endOfDayTs = Timestamp.fromDate(endOfDay);

    return _roomsTaskStream(
      userId: userId,
      queryBuilder: (roomId) {
        // Query by Date
        return _rooms
            .doc(roomId)
            .collection('taskInstances')
            .where('scheduledDate', isGreaterThanOrEqualTo: startOfDayTs)
            .where('scheduledDate', isLessThan: endOfDayTs);
      },
      sorter: (a, b) {
        final aDate = (a['scheduledDate'] as Timestamp).toDate();
        final bDate = (b['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      },
    ).map((allTasks) {
      // Filter by AssignedTo (client-side to avoid composite index)
      return allTasks.where((t) {
        final assignedTo = t['assignedTo'];
        return assignedTo == userId || assignedTo == 'volunteer';
      }).toList();
    });
  }

  /// Get upcoming tasks for a user (Real-time)
  Stream<List<Map<String, dynamic>>> getUpcomingTasksForUser(String userId) {
    final today = DateTime.now();
    final tomorrow = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));
    final nextThirtyDays = tomorrow.add(const Duration(days: 30));
    final tomorrowTs = Timestamp.fromDate(tomorrow);
    final nextThirtyDaysTs = Timestamp.fromDate(nextThirtyDays);

    return _roomsTaskStream(
      userId: userId,
      queryBuilder: (roomId) {
        return _rooms
            .doc(roomId)
            .collection('taskInstances')
            .where('scheduledDate', isGreaterThanOrEqualTo: tomorrowTs)
            .where('scheduledDate', isLessThan: nextThirtyDaysTs);
      },
      sorter: (a, b) {
        final aDate = (a['scheduledDate'] as Timestamp).toDate();
        final bDate = (b['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      },
    ).map((allTasks) {
      return allTasks.where((t) {
        final assignedTo = t['assignedTo'];
        return assignedTo == userId || assignedTo == 'volunteer';
      }).toList();
    });
  }

  /// Mark a task instance as completed or pending
  Future<void> markTaskInstanceAsCompleted(
    String roomId,
    String taskInstanceId,
    bool isCompleted,
  ) async {
    await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .update({
          'isCompleted': isCompleted,
          'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
        });
  }

  /// Get room members with their profiles
  Future<List<Map<String, dynamic>>> getRoomMembers(String roomId) async {
    final roomDoc = await _rooms.doc(roomId).get();
    if (!roomDoc.exists) return [];

    final roomData = roomDoc.data() as Map<String, dynamic>;
    final members = List<String>.from(roomData['members'] ?? []);

    final membersWithProfiles = <Map<String, dynamic>>[];

    for (final uid in members) {
      final profile = await getUserProfile(uid);
      if (profile != null) {
        membersWithProfiles.add({
          'uid': uid,
          'displayName': profile['displayName'] ?? 'Member',
          ...profile,
        });
      }
    }

    return membersWithProfiles;
  }

  /// Get pending swap requests for a user (either direct or open) - Scoped to Room
  Stream<List<Map<String, dynamic>>> getPendingSwapRequests(
    String roomId,
    String currentUserId,
  ) {
    return _rooms
        .doc(roomId)
        .collection('taskInstances')
        .where('swapRequest.status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['taskInstanceId'] = doc.id;
                data['roomId'] = roomId;
                return data;
              })
              .where((data) {
                final request = data['swapRequest'] as Map<String, dynamic>?;
                if (request == null) return false;

                final targetId = request['targetId'] as String?;
                final requesterId = request['requesterId'] as String?;
                final offeredId = request['offeredTaskInstanceId'] as String?;

                // Phase 1: No offer yet.
                if (offeredId == null) {
                  if (requesterId == currentUserId) return false;
                  return targetId == null || targetId == currentUserId;
                }
                return false;
              })
              .toList();
        });
  }

  /// Get swap offers for a user (tasks I requested a swap for, and someone replied)
  Stream<List<Map<String, dynamic>>> getSwapOffersForUser(String userId) {
    // We need to query all rooms for tasks where:
    // 1. swapRequest.requesterId == userId
    // 2. swapRequest.status == 'pending_approval' (Phase 2 complete)

    // Using collectionGroup query would require a composite index on requesterId + status.
    // To avoid index creation during this session, we'll reuse the rooms-based approach.

    return _rooms.where('members', arrayContains: userId).snapshots().asyncMap((
      roomsSnap,
    ) async {
      final List<Map<String, dynamic>> allOffers = [];

      for (final room in roomsSnap.docs) {
        final roomId = room.id;
        final roomData = room.data() as Map<String, dynamic>;
        final roomName = roomData['name'] ?? 'Room';

        final snap = await _rooms
            .doc(roomId)
            .collection('taskInstances')
            .where('swapRequest.requesterId', isEqualTo: userId)
            .where('swapRequest.status', isEqualTo: 'pending_approval')
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          allOffers.add({
            ...data,
            'taskInstanceId': doc.id,
            'roomId': roomId,
            'roomName': roomName,
          });
        }
      }
      return allOffers;
    });
  }

  /// Withdraw a pending swap request
  Future<void> withdrawSwapRequest({
    required String roomId,
    required String taskInstanceId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .update({'swapRequest': FieldValue.delete()});
  }

  /// Create a swap request
  Future<void> createSwapRequest({
    required String roomId,
    required String taskInstanceId,
    required String? targetUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    // Get requester and target names
    final requesterProfile = await getUserProfile(currentUserId);
    final requesterName = requesterProfile?['displayName'] ?? 'Member';

    String targetName = 'Anyone';
    if (targetUserId != null) {
      final targetProfile = await getUserProfile(targetUserId);
      targetName = targetProfile?['displayName'] ?? 'Member';
    }

    await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .update({
          'swapRequest': {
            'requesterId': currentUserId,
            'requesterName': requesterName,
            'targetId': targetUserId, // can be null
            'targetName': targetName,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          },
        });

    // Create notification
    if (targetUserId != null) {
      try {
        await createNotification(
          roomId: roomId,
          userId: targetUserId,
          type: NotificationType.taskSwapRequest,
          title: 'Task Swap Request',
          message: '$requesterName wants to swap tasks with you',
          actorId: currentUserId,
          actorName: requesterName,
          taskInstanceId: taskInstanceId,
        );
      } catch (e) {
        print('❌ Error creating swap notification: $e');
      }
    } else {
      // Notify all other members
      try {
        final members = await getRoomMembers(roomId);
        for (final m in members) {
          if (m['uid'] != currentUserId) {
            await createNotification(
              roomId: roomId,
              userId: m['uid'],
              type: NotificationType.taskSwapRequest,
              title: 'Open Swap Request',
              message: '$requesterName is looking to swap a task with anyone',
              actorId: currentUserId,
              actorName: requesterName,
              taskInstanceId: taskInstanceId,
            );
          }
        }
      } catch (e) {
        print('❌ Error creating broadcast notification: $e');
      }
    }
  }

  /// Step 2: Responder proposes a task to swap
  Future<void> proposeSwap({
    required String roomId,
    required String taskInstanceId,
    required String offeredTaskInstanceId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    final responderProfile = await getUserProfile(currentUserId);
    final responderName = responderProfile?['displayName'] ?? 'Member';

    // Get offered task details for notification context
    final offeredTaskDoc = await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(offeredTaskInstanceId)
        .get();
    final offeredTaskTitle = offeredTaskDoc.data()?['title'] ?? 'Task';
    final offeredTaskDate =
        (offeredTaskDoc.data()?['scheduledDate'] as Timestamp?)?.toDate();

    await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .update({
          'swapRequest.responderId': currentUserId,
          'swapRequest.responderName': responderName,
          'swapRequest.offeredTaskInstanceId': offeredTaskInstanceId,
          'swapRequest.offeredTaskTitle': offeredTaskTitle,
          'swapRequest.offeredTaskDate': offeredTaskDate != null
              ? Timestamp.fromDate(offeredTaskDate)
              : null,
          'swapRequest.status': 'pending_approval',
          'swapRequest.respondedAt': FieldValue.serverTimestamp(),
        });

    // Notify original requester
    final taskDoc = await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .get();
    final requesterId = taskDoc.data()?['swapRequest']['requesterId'];

    if (requesterId != null) {
      await createNotification(
        roomId: roomId,
        userId: requesterId,
        type: NotificationType.taskSwapRequest,
        title: 'Swap Offer Received',
        message: '$responderName offered "$offeredTaskTitle" for your task',
        actorId: currentUserId,
        actorName: responderName,
        taskInstanceId: taskInstanceId,
      );
    }
  }

  /// Step 3: Initiator finalizes the swap (Accept/Reject)
  Future<void> finalizeSwap({
    required String roomId,
    required String taskInstanceId,
    required bool approve,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    final taskRef = _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId);
    final taskDoc = await taskRef.get();
    if (!taskDoc.exists) throw Exception('Task not found');

    final data = taskDoc.data()!;
    final swapRequest = data['swapRequest'] as Map<String, dynamic>;
    final responderId = swapRequest['responderId'] as String;
    final offeredTaskInstanceId =
        swapRequest['offeredTaskInstanceId'] as String;

    if (approve) {
      // 1. Get offered task
      final offeredTaskRef = _rooms
          .doc(roomId)
          .collection('taskInstances')
          .doc(offeredTaskInstanceId);
      final offeredDoc = await offeredTaskRef.get();

      if (!offeredDoc.exists) throw Exception('Offered task no longer exists');

      final requesterName = swapRequest['requesterName'] ?? 'Member';
      final responderName = swapRequest['responderName'] ?? 'Member';

      final requestTaskTitle = data['title'] ?? 'Task';
      final requestDate = data['scheduledDate'];
      final offeredDate = offeredDoc.data()?['scheduledDate'];

      // 2. Perform Swap
      final batch = _db.batch();

      // Update Initiator's Task (assigned to Responder)
      batch.update(taskRef, {
        'assignedTo': responderId,
        'swapRequest': FieldValue.delete(), // Clear request
        'swappedWith': {
          'userId': responderId,
          'userName': responderName,
          'originalDate': offeredDate,
          'swappedAt': FieldValue.serverTimestamp(),
          'swappedBy': requesterName,
        },
      });

      // Update Responder's Task (assigned to Initiator)
      batch.update(offeredTaskRef, {
        'assignedTo': currentUserId,
        'swappedWith': {
          'userId': currentUserId,
          'userName': requesterName,
          'originalDate': requestDate,
          'swappedAt': FieldValue.serverTimestamp(),
          'swappedBy': requesterName,
        },
      });

      await batch.commit();

      // 3. Notify Responder
      await createNotification(
        roomId: roomId,
        userId: responderId,
        type: NotificationType.taskSwapApproved,
        title: 'Swap Finalized',
        message:
            '$requesterName accepted your offer. You are now assigned "$requestTaskTitle".',
        actorId: currentUserId,
        actorName: requesterName,
        taskInstanceId: taskInstanceId,
      );
    } else {
      // Reject
      await taskRef.update({
        'swapRequest.status': 'rejected',
        'swapRequest.rejectedAt': FieldValue.serverTimestamp(),
      });

      await createNotification(
        roomId: roomId,
        userId: responderId,
        type: NotificationType.taskSwapRejected,
        title: 'Swap Offer Rejected',
        message: 'Your swap offer was rejected.',
        actorId: currentUserId,
        actorName: 'Member',
        taskInstanceId: taskInstanceId,
      );
    }
  }

  /// Generate task instances for a room (for the next 30 days)
  Future<void> generateTaskInstancesForRoom(
    String roomId, {
    int daysAhead = 30,
  }) async {
    final tasksSnapshot = await _rooms
        .doc(roomId)
        .collection('tasks')
        .where('isActive', isEqualTo: true)
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var taskDoc in tasksSnapshot.docs) {
      final taskData = taskDoc.data();
      final taskId = taskDoc.id;
      final frequency = taskData['frequency'] as String?;
      final rotationType = taskData['rotationType'] as String?;
      final weekDays =
          (taskData['weekDays'] as List<dynamic>?)?.cast<int>() ?? [];
      final monthDay = taskData['monthDay'] as int?;
      final memberIds = List<String>.from(
        taskData['memberIds'] ?? [],
      ); // Restored

      // Try to get title from multiple possible field names
      final title =
          (taskData['title'] as String?) ??
          (taskData['name'] as String?) ??
          'Untitled Task';

      final categoryId = taskData['categoryId'] as String? ?? '';
      final timeSlot = taskData['timeSlot'] as Map<String, dynamic>?;
      final estimatedMinutes = taskData['estimatedMinutes'] as int? ?? 30;
      final currentRotationIndex =
          taskData['currentRotationIndex'] as int? ?? 0;

      if (memberIds.isEmpty) continue;

      // Generate instances for the next X days
      for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
        final targetDate = today.add(Duration(days: dayOffset));

        bool shouldGenerate = false;
        switch (frequency) {
          case 'daily':
            shouldGenerate = true;
            break;
          case 'weekly':
            if (weekDays.isNotEmpty) {
              if (weekDays.contains(targetDate.weekday)) shouldGenerate = true;
            } else {
              // Fallback: use created day of week if no specific days set
              // Or default to Monday (1)
              shouldGenerate = targetDate.weekday == 1;
            }
            break;
          case 'monthly':
            if (monthDay != null) {
              shouldGenerate = targetDate.day == monthDay;
            } else {
              // Fallback
              shouldGenerate = targetDate.day == 1;
            }
            break;
          case 'biweekly':
            // Calculate weeks since creation
            final daysSinceCreation = targetDate
                .difference(
                  taskData['createdAt'] != null
                      ? (taskData['createdAt'] as Timestamp).toDate()
                      : today,
                )
                .inDays;
            final weekIndex = (daysSinceCreation / 7).floor();

            // Check if it's an "active" week (every 2nd week)
            if (weekIndex % 2 == 0) {
              if (weekDays.isNotEmpty) {
                if (weekDays.contains(targetDate.weekday)) {
                  shouldGenerate = true;
                }
              } else {
                // Fallback to creation day of week or Monday
                final createdWeekday = taskData['createdAt'] != null
                    ? (taskData['createdAt'] as Timestamp).toDate().weekday
                    : 1;
                shouldGenerate = targetDate.weekday == createdWeekday;
              }
            }
            break;

          case 'custom':
            final repeatInterval = taskData['repeatInterval'] as int? ?? 1;
            final createdAt = taskData['createdAt'] != null
                ? (taskData['createdAt'] as Timestamp).toDate()
                : today;
            final daysSinceCreation = targetDate.difference(createdAt).inDays;

            shouldGenerate = daysSinceCreation % repeatInterval == 0;
            break;
        }

        if (!shouldGenerate) continue;

        final scheduledDate = Timestamp.fromDate(targetDate);

        // Use deterministic document ID to prevent duplicates: taskId_YYYYMMDD
        final docId = _taskInstanceDocId(taskId, targetDate);

        // Check if instance already exists using direct get (atomic, prevents race condition)
        final existingDoc = await _rooms
            .doc(roomId)
            .collection('taskInstances')
            .doc(docId)
            .get();

        if (existingDoc.exists) {
          continue; // Instance already exists, skip
        }

        // Calculate assignee based on rotation
        // Use frequency-specific rotation seed to ensure correct stepping
        int rotationSeed;
        final daysSinceEpoch = targetDate.millisecondsSinceEpoch ~/ 86400000;

        switch (frequency) {
          case 'daily':
            rotationSeed = daysSinceEpoch;
            break;
          case 'weekly':
            // Rotate once per week
            rotationSeed = daysSinceEpoch ~/ 7;
            break;
          case 'biweekly':
            // Rotate once every 2 weeks
            rotationSeed = (daysSinceEpoch ~/ 7) ~/ 2;
            break;
          case 'monthly':
            // Rotate once per month
            rotationSeed = targetDate.year * 12 + targetDate.month;
            break;
          case 'custom':
            final repeatInterval = taskData['repeatInterval'] as int? ?? 1;
            rotationSeed = daysSinceEpoch ~/ repeatInterval;
            break;
          default:
            rotationSeed = daysSinceEpoch;
        }

        String? assignedTo;
        if (rotationType == 'volunteer') {
          assignedTo = 'volunteer';
        } else if (rotationType == 'roundRobin') {
          final assigneeIndex =
              (currentRotationIndex + rotationSeed).abs() % memberIds.length;
          assignedTo = memberIds[assigneeIndex];
        } else {
          // Manual: Always assign to the first selected member
          assignedTo = memberIds.isNotEmpty ? memberIds[0] : null;
        }

        // Create task instance with deterministic ID
        await _rooms.doc(roomId).collection('taskInstances').doc(docId).set(
          {
            'taskId': taskId,
            'roomId': roomId,
            'title': title,
            'categoryId': categoryId,
            'assignedTo': assignedTo,
            'scheduledDate': scheduledDate,
            'timeSlot': timeSlot,
            'estimatedMinutes': estimatedMinutes,
            'isCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ); // merge=true prevents overwriting if doc exists
      }
    }
  }

  /// Generate task instances for all rooms a user is in
  Future<void> generateTaskInstancesForUser(String userId) async {
    final roomsSnapshot = await _rooms
        .where('members', arrayContains: userId)
        .get();

    for (var roomDoc in roomsSnapshot.docs) {
      await generateTaskInstancesForRoom(roomDoc.id);
    }
  }

  /// Delete all task instances for a room (useful for regenerating)
  Future<void> deleteAllTaskInstances(String roomId) async {
    final instancesSnapshot = await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .get();

    for (var doc in instancesSnapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Delete all task instances for a specific task
  Future<void> deleteTaskInstancesForTask(String roomId, String taskId) async {
    final snapshot = await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .where('taskId', isEqualTo: taskId)
        .get();
    for (final d in snapshot.docs) {
      await d.reference.delete();
    }
  }

  /// Generate task instances only for a specific task
  Future<void> generateTaskInstancesForTask(
    String roomId,
    String taskId, {
    int daysAhead = 30,
    bool checkExisting = true,
  }) async {
    final taskDoc = await _rooms
        .doc(roomId)
        .collection('tasks')
        .doc(taskId)
        .get();
    if (!taskDoc.exists) return;
    final taskData = taskDoc.data() as Map<String, dynamic>;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final frequency = taskData['frequency'] as String?;
    final rotationType = taskData['rotationType'] as String?;
    final weekDays =
        (taskData['weekDays'] as List<dynamic>?)?.cast<int>() ?? [];
    final monthDay = taskData['monthDay'] as int?;
    final memberIds = List<String>.from(
      taskData['memberIds'] ?? [],
    ); // Restored

    final title =
        (taskData['title'] as String?) ??
        (taskData['name'] as String?) ??
        'Untitled Task';
    final categoryId = taskData['categoryId'] as String? ?? '';
    final timeSlot = taskData['timeSlot'] as Map<String, dynamic>?;
    final estimatedMinutes = taskData['estimatedMinutes'] as int? ?? 30;
    final currentRotationIndex = taskData['currentRotationIndex'] as int? ?? 0;

    if (memberIds.isEmpty && rotationType != 'volunteer') return;

    // Use a single batch for performance and deterministic doc IDs for idempotency.
    final batch = _rooms.firestore.batch();

    for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));

      bool shouldGenerate = false;
      switch (frequency) {
        case 'daily':
          shouldGenerate = true;
          break;
        case 'weekly':
          if (weekDays.isNotEmpty) {
            if (weekDays.contains(targetDate.weekday)) {
              shouldGenerate = true;
            }
          } else {
            shouldGenerate = targetDate.weekday == 1; // Default Mon
          }
          break;
        case 'monthly':
          if (monthDay != null) {
            shouldGenerate = targetDate.day == monthDay;
          } else {
            shouldGenerate = targetDate.day == 1; // Default 1st
          }
          break;
        case 'biweekly':
          final createdAt = taskData['createdAt'] != null
              ? (taskData['createdAt'] as Timestamp).toDate()
              : today; // Use today as fallback if createdAt is null
          final daysSinceCreation = targetDate.difference(createdAt).inDays;
          final weekIndex = (daysSinceCreation / 7).floor();
          if (weekIndex % 2 == 0) {
            if (weekDays.isNotEmpty) {
              if (weekDays.contains(targetDate.weekday)) shouldGenerate = true;
            } else {
              shouldGenerate = targetDate.weekday == createdAt.weekday;
            }
          }
          break;
        case 'custom':
          final repeatInterval = taskData['repeatInterval'] as int? ?? 1;
          final createdAt = taskData['createdAt'] != null
              ? (taskData['createdAt'] as Timestamp).toDate()
              : today;
          final daysSinceCreation = targetDate.difference(createdAt).inDays;

          shouldGenerate = daysSinceCreation % repeatInterval == 0;
          break;
      }

      if (!shouldGenerate) continue;

      final docId = _taskInstanceDocId(taskId, targetDate);

      if (checkExisting) {
        final existing = await _rooms
            .doc(roomId)
            .collection('taskInstances')
            .doc(docId)
            .get();

        if (existing.exists) continue;
      }

      final scheduledDate = Timestamp.fromDate(targetDate);

      // Calculate assignee based on rotation
      int rotationSeed;
      final daysSinceEpoch = targetDate.millisecondsSinceEpoch ~/ 86400000;

      switch (frequency) {
        case 'daily':
          rotationSeed = daysSinceEpoch;
          break;
        case 'weekly':
          // Rotate once per week
          rotationSeed = daysSinceEpoch ~/ 7;
          break;
        case 'biweekly':
          // Rotate once every 2 weeks
          rotationSeed = (daysSinceEpoch ~/ 7) ~/ 2;
          break;
        case 'monthly':
          // Rotate once per month
          rotationSeed = targetDate.year * 12 + targetDate.month;
          break;
        case 'custom':
          final repeatInterval = taskData['repeatInterval'] as int? ?? 1;
          rotationSeed = daysSinceEpoch ~/ repeatInterval;
          break;
        default:
          rotationSeed = daysSinceEpoch;
      }

      String? assignedTo;
      if (rotationType == 'volunteer') {
        assignedTo = 'volunteer';
      } else if (rotationType == 'roundRobin') {
        assignedTo =
            memberIds[(currentRotationIndex + rotationSeed).abs() %
                memberIds.length];
      } else {
        // Manual: Always assign to the first selected member
        assignedTo = memberIds.isNotEmpty ? memberIds[0] : null;
      }

      final ref = _rooms.doc(roomId).collection('taskInstances').doc(docId);
      batch.set(
        ref,
        {
          'taskId': taskId,
          'roomId': roomId,
          'title': title,
          'categoryId': categoryId,
          'assignedTo': assignedTo,
          'scheduledDate': scheduledDate,
          'timeSlot': timeSlot,
          'estimatedMinutes': estimatedMinutes,
          'isCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      ); // Ensure merge true so existing data (like completion) isn't wiped
    }

    await batch.commit();
  }

  // ---------- Task instance utilities ----------

  String _taskInstanceDocId(String taskId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${taskId}_$y$m$d';
  }

  /// Stream the task instance document for a given task on a specific date (or null if missing)
  Stream<Map<String, dynamic>?> watchTaskInstanceForDate(
    String roomId,
    String taskId,
    DateTime date,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    final docId = _taskInstanceDocId(taskId, day);
    final ref = _rooms.doc(roomId).collection('taskInstances').doc(docId);
    return ref.snapshots().asyncMap((snap) async {
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        return {...data, 'taskInstanceId': snap.id};
      }
      // Fallback for legacy instances created before deterministic IDs
      final targetDate = Timestamp.fromDate(day);
      final q = await _rooms
          .doc(roomId)
          .collection('taskInstances')
          .where('taskId', isEqualTo: taskId)
          .limit(10)
          .get();

      // Client-side filtering for the date to avoid composite index
      for (final doc in q.docs) {
        final data = doc.data();
        if (data['scheduledDate'] == targetDate) {
          return {...data, 'taskInstanceId': doc.id};
        }
      }
      return null;
    });
  }

  /// Get task instances for a room within a date range
  Stream<List<Map<String, dynamic>>> getTaskInstancesStream(
    String roomId,
    DateTime start,
    DateTime end,
  ) {
    final startTs = Timestamp.fromDate(start);
    final endTs = Timestamp.fromDate(end);

    return _rooms
        .doc(roomId)
        .collection('taskInstances')
        .where('scheduledDate', isGreaterThanOrEqualTo: startTs)
        .where('scheduledDate', isLessThanOrEqualTo: endTs)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'taskInstanceId': doc.id};
          }).toList();
        });
  }

  /// Count overdue daily instances (not completed) looking back up to [lookbackDays]
  Future<int> countOverdueTaskInstances(
    String roomId,
    String taskId, {
    int lookbackDays = 30,
  }) async {
    final now = DateTime.now();
    int count = 0;
    for (int i = 1; i <= lookbackDays; i++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final docId = _taskInstanceDocId(taskId, day);
      final ref = _rooms.doc(roomId).collection('taskInstances').doc(docId);
      final snap = await ref.get();
      if (!snap.exists) continue;
      final data = snap.data() as Map<String, dynamic>;
      final completed = (data['isCompleted'] as bool?) ?? false;
      if (!completed) count++;
    }
    return count;
  }

  /// ---------------------------
  /// NOTIFICATIONS
  /// ---------------------------

  /// Get the notifications collection reference
  CollectionReference _notificationsRef() => _db.collection('notifications');

  /// Create a notification
  Future<void> createNotification({
    required String roomId,
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? actorId,
    String? actorName,
    String? relatedId,
    String? taskInstanceId,
    Map<String, dynamic>? additionalData,
  }) async {
    final notification = RoomNotification(
      id: '',
      roomId: roomId,
      userId: userId,
      type: type,
      title: title,
      message: message,
      isRead: false,
      createdAt: DateTime.now(),
      actorId: actorId,
      actorName: actorName,
      relatedId: relatedId,
      taskInstanceId: taskInstanceId,
      additionalData: additionalData,
    );

    print(
      '📝 Creating notification: $title for user: $userId in room: $roomId',
    );
    await _notificationsRef().add(notification.toMap());
    print('✅ Notification created successfully in Firestore');
  }

  /// Stream notifications for a user in a specific room
  Stream<List<RoomNotification>> getNotificationsStream({
    required String roomId,
    required String userId,
    bool unreadOnly = false,
  }) {
    // Simplified query to avoid composite index initially
    // We'll filter and sort in memory
    Query query = _notificationsRef()
        .where('roomId', isEqualTo: roomId)
        .where('userId', isEqualTo: userId);

    if (unreadOnly) {
      query = query.where('isRead', isEqualTo: false);
    }

    return query.snapshots().map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => RoomNotification.fromFirestore(doc))
          .toList();

      // Sort by createdAt in memory (descending - newest first)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Limit to 50
      return notifications.take(50).toList();
    });
  }

  /// Get unread notification count for a room
  Stream<int> getUnreadNotificationCount({
    required String roomId,
    required String userId,
  }) {
    return _notificationsRef()
        .where('roomId', isEqualTo: roomId)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _notificationsRef().doc(notificationId).update({'isRead': true});
  }

  /// Mark all notifications as read for a room
  Future<void> markAllNotificationsAsRead({
    required String roomId,
    required String userId,
  }) async {
    final snapshot = await _notificationsRef()
        .where('roomId', isEqualTo: roomId)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _notificationsRef().doc(notificationId).delete();
  }

  /// Delete all notifications for a room
  Future<void> deleteAllNotifications({
    required String roomId,
    required String userId,
  }) async {
    final snapshot = await _notificationsRef()
        .where('roomId', isEqualTo: roomId)
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _db.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
