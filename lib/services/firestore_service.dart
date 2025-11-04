// lib/services/firestore_service.dart
// Firestore helper: rooms, expenses, users
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Models/expense.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Top-level collection references
  CollectionReference get _rooms => _db.collection('rooms');
  CollectionReference get _users => _db.collection('users');

  /// ---------------------------
  /// ROOMS
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
    }
  }

  /// Delete an expense document
  Future<void> deleteExpense(String roomId, String expenseId) async {
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

  /// Get expenses as Stream of List<Expense> (alias for better clarity)
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
  }

  /// Get room as a Map (for accessing member UIDs)
  Future<Map<String, dynamic>?> getRoom(String roomId) async {
    return getRoomById(roomId);
  }

  /// Upload receipt image to Firebase Storage
  Future<String> uploadReceipt(dynamic receiptFile, String roomId) async {
    // This method would need Firebase Storage implementation
    // For now, return empty string - implement with firebase_storage package
    throw UnimplementedError(
      'Receipt upload requires firebase_storage package',
    );
  }

  /// ---------------------------
  /// USERS
  /// ---------------------------

  /// Get user profile doc (one-time). Returns map including 'id' (uid) or null.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    final m = snap.data() as Map<String, dynamic>;
    return {...m, 'id': snap.id};
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

    for (var uid in uids) {
      final profile = await getUserProfile(uid);
      if (profile != null) {
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
  Future<void> deletePayment(String roomId, String paymentId) async {
    await paymentsRef(roomId).doc(paymentId).delete();
  }

  /// ---------------------------
  /// TASK INSTANCES & MANAGEMENT
  /// ---------------------------

  /// Get today's tasks for a user across all their rooms (live collectionGroup stream)
  Stream<List<Map<String, dynamic>>> getTodayTasksForUser(String userId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Fallback index-friendly query: filter by assignee only and apply date range client-side
    // Re-enable server-side date filters once the composite index is confirmed active.
    // DEBUG: Using client-side date filtering to avoid composite index during rollout
    // ignore: avoid_print
    print(
      'FirestoreService.getTodayTasksForUser: client-side date filter active for user: ' +
          userId,
    );
    return _rooms.where('members', arrayContains: userId).snapshots().asyncMap((
      roomsSnap,
    ) async {
      final List<Map<String, dynamic>> all = [];
      for (final room in roomsSnap.docs) {
        final roomId = room.id;
        final roomName =
            (room.data() as Map<String, dynamic>)['name'] ?? 'Room';
        final q = _rooms
            .doc(roomId)
            .collection('taskInstances')
            .where('assignedTo', isEqualTo: userId)
            .where(
              'scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay));
        final snap = await q.get();
        for (final d in snap.docs) {
          final m = d.data();
          all.add({
            ...m,
            'taskInstanceId': d.id,
            'roomId': roomId,
            'roomName': roomName,
          });
        }
      }
      all.sort((a, b) {
        final aDate = (a['scheduledDate'] as Timestamp).toDate();
        final bDate = (b['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });
      return all;
    });
  }

  /// Get upcoming tasks for a user (next 30 days)
  Stream<List<Map<String, dynamic>>> getUpcomingTasksForUser(String userId) {
    final today = DateTime.now();
    final tomorrow = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 1));
    final nextThirtyDays = tomorrow.add(const Duration(days: 30));

    // DEBUG: Using client-side date filtering to avoid composite index during rollout
    // ignore: avoid_print
    print(
      'FirestoreService.getUpcomingTasksForUser (30 days): client-side date filter active for user: ' +
          userId,
    );
    return _rooms.where('members', arrayContains: userId).snapshots().asyncMap((
      roomsSnap,
    ) async {
      final List<Map<String, dynamic>> all = [];
      for (final room in roomsSnap.docs) {
        final roomId = room.id;
        final roomName =
            (room.data() as Map<String, dynamic>)['name'] ?? 'Room';
        final q = _rooms
            .doc(roomId)
            .collection('taskInstances')
            .where('assignedTo', isEqualTo: userId)
            .where(
              'scheduledDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrow),
            )
            .where(
              'scheduledDate',
              isLessThan: Timestamp.fromDate(nextThirtyDays),
            );
        final snap = await q.get();
        for (final d in snap.docs) {
          final m = d.data();
          all.add({
            ...m,
            'taskInstanceId': d.id,
            'roomId': roomId,
            'roomName': roomName,
          });
        }
      }
      all.sort((a, b) {
        final aDate = (a['scheduledDate'] as Timestamp).toDate();
        final bDate = (b['scheduledDate'] as Timestamp).toDate();
        return aDate.compareTo(bDate);
      });
      return all;
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

  /// Create a swap request
  Future<void> createSwapRequest({
    required String roomId,
    required String taskInstanceId,
    required String targetUserId,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    // Get requester and target names
    final requesterProfile = await getUserProfile(currentUserId);
    final targetProfile = await getUserProfile(targetUserId);

    await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .update({
          'swapRequest': {
            'requesterId': currentUserId,
            'requesterName': requesterProfile?['displayName'] ?? 'Member',
            'targetId': targetUserId,
            'targetName': targetProfile?['displayName'] ?? 'Member',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          },
        });
  }

  /// Respond to a swap request
  Future<void> respondToSwapRequest({
    required String roomId,
    required String taskInstanceId,
    required bool approve,
  }) async {
    final taskInstanceRef = _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId);
    final taskInstanceDoc = await taskInstanceRef.get();

    if (!taskInstanceDoc.exists) throw Exception('Task instance not found');

    final taskData = taskInstanceDoc.data()!;
    final swapRequest = taskData['swapRequest'] as Map<String, dynamic>?;

    if (swapRequest == null) throw Exception('No swap request found');

    if (approve) {
      final requesterId = swapRequest['requesterId'];
      final currentAssignee = taskData['assignedTo'];

      // Swap the assignees
      await taskInstanceRef.update({
        'assignedTo': requesterId,
        'swapRequest.status': 'approved',
        'swapRequest.approvedAt': FieldValue.serverTimestamp(),
      });

      // Find the requester's task on the same date and swap
      final scheduledDate = taskData['scheduledDate'] as Timestamp;
      final requesterTasksSnapshot = await _rooms
          .doc(roomId)
          .collection('taskInstances')
          .where('assignedTo', isEqualTo: requesterId)
          .where('scheduledDate', isEqualTo: scheduledDate)
          .limit(1)
          .get();

      if (requesterTasksSnapshot.docs.isNotEmpty) {
        await requesterTasksSnapshot.docs.first.reference.update({
          'assignedTo': currentAssignee,
        });
      }
    } else {
      await taskInstanceRef.update({
        'swapRequest.status': 'rejected',
        'swapRequest.rejectedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Request reschedule
  Future<void> requestReschedule({
    required String roomId,
    required String taskInstanceId,
    required DateTime newDate,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('User not logged in');

    await _rooms
        .doc(roomId)
        .collection('taskInstances')
        .doc(taskInstanceId)
        .update({
          'rescheduleRequest': {
            'requestedBy': currentUserId,
            'newDate': Timestamp.fromDate(newDate),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          },
        });
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
      final memberIds = List<String>.from(taskData['memberIds'] ?? []);

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
      if (frequency != 'daily') continue; // Only handle daily tasks for now

      // Generate instances for the next X days
      for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
        final targetDate = today.add(Duration(days: dayOffset));
        final scheduledDate = Timestamp.fromDate(targetDate);

        // Check if instance already exists for this task on this date
        final existingInstances = await _rooms
            .doc(roomId)
            .collection('taskInstances')
            .where('taskId', isEqualTo: taskId)
            .where('scheduledDate', isEqualTo: scheduledDate)
            .limit(1)
            .get();

        if (existingInstances.docs.isNotEmpty) {
          continue; // Instance already exists
        }

        // Calculate assignee based on rotation
        String assignedTo;
        if (rotationType == 'roundRobin') {
          // Auto-rotate: assign based on day offset + current index
          final assigneeIndex =
              (currentRotationIndex + dayOffset) % memberIds.length;
          assignedTo = memberIds[assigneeIndex];
        } else {
          // Manual or other: assign to current rotation index
          assignedTo = memberIds[currentRotationIndex % memberIds.length];
        }

        // Create task instance
        await _rooms.doc(roomId).collection('taskInstances').add({
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
        });
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
    final memberIds = List<String>.from(taskData['memberIds'] ?? []);
    final title =
        (taskData['title'] as String?) ??
        (taskData['name'] as String?) ??
        'Untitled Task';
    final categoryId = taskData['categoryId'] as String? ?? '';
    final timeSlot = taskData['timeSlot'] as Map<String, dynamic>?;
    final estimatedMinutes = taskData['estimatedMinutes'] as int? ?? 30;
    final currentRotationIndex = taskData['currentRotationIndex'] as int? ?? 0;

    if (memberIds.isEmpty) return;
    if (frequency != 'daily') return;

    // Use a single batch for performance and deterministic doc IDs for idempotency.
    final batch = _rooms.firestore.batch();

    for (int dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final scheduledDate = Timestamp.fromDate(targetDate);

      final assignedTo = (rotationType == 'roundRobin')
          ? memberIds[(currentRotationIndex + dayOffset) % memberIds.length]
          : memberIds[currentRotationIndex % memberIds.length];

      final docId = _taskInstanceDocId(taskId, targetDate);
      final ref = _rooms.doc(roomId).collection('taskInstances').doc(docId);
      batch.set(ref, {
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
      }, SetOptions(merge: false));
    }

    await batch.commit();
  }

  // ---------- Task instance utilities ----------

  String _taskInstanceDocId(String taskId, DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${taskId}_${y}${m}${d}';
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
      final q = await _rooms
          .doc(roomId)
          .collection('taskInstances')
          .where('taskId', isEqualTo: taskId)
          .where('scheduledDate', isEqualTo: Timestamp.fromDate(day))
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first;
        final data = d.data();
        return {...data, 'taskInstanceId': d.id};
      }
      return null;
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
}
