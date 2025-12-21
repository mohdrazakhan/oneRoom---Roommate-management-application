// lib/providers/tasks_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/task_category.dart';
import '../Models/task.dart';
import '../services/firestore_service.dart';
import '../services/notification_helper.dart';

class TasksProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // ==================== CATEGORIES ====================

  Stream<List<TaskCategory>> getCategoriesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('task_categories')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskCategory.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> createCategory({
    required String roomId,
    required String name,
    required IconData icon,
    required Color color,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('task_categories')
        .add({
          'name': name,
          'iconCodePoint': icon.codePoint,
          'colorValue': color.toARGB32(),
          'roomId': roomId,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteCategory(String roomId, String categoryId) async {
    // Delete all tasks in this category first
    final tasksSnapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .where('categoryId', isEqualTo: categoryId)
        .get();

    final batch = _firestore.batch();
    for (var doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the category
    batch.delete(
      _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('task_categories')
          .doc(categoryId),
    );

    await batch.commit();
  }

  Future<void> renameCategory(
    String roomId,
    String categoryId,
    String newName,
  ) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('task_categories')
        .doc(categoryId)
        .update({'name': newName});
  }

  // ==================== TASKS ====================

  Stream<List<Task>> getTasksStream(String roomId, String categoryId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .where('categoryId', isEqualTo: categoryId)
        // Note: orderBy with where requires a composite index
        // Sorting in-memory instead to avoid index requirement
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs
              .map((doc) => Task.fromFirestore(doc))
              .toList();
          // Sort in-memory by createdAt ascending
          tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return tasks;
        });
  }

  Future<int> getTaskCount(String roomId, String categoryId) async {
    final snapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .where('categoryId', isEqualTo: categoryId)
        .get();
    return snapshot.docs.length;
  }

  Future<int> getTotalTaskCount(String roomId) async {
    final snapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> getCategoryCount(String roomId) async {
    final snapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('task_categories')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> createTask({
    required String roomId,
    required String categoryId,
    required String title,
    String? description,
    required TaskFrequency frequency,
    required RotationType rotationType,
    required List<String> memberIds,
    TimeOfDay? timeSlot,
    int estimatedMinutes = 30,
    List<int>? weekDays,
    int? monthDay,
  }) async {
    final task = Task(
      id: '',
      title: title,
      description: description,
      categoryId: categoryId,
      roomId: roomId,
      frequency: frequency,
      rotationType: rotationType,
      memberIds: memberIds,
      timeSlot: timeSlot,
      estimatedMinutes: estimatedMinutes,
      createdAt: DateTime.now(),
      weekDays: weekDays,
      monthDay: monthDay,
    );

    final docRef = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .add(task.toMap());

    // Generate first few instances immediately so dashboard updates fast,
    // then generate the rest in the background.
    try {
      // OPTIMIZATION: checkExisting: false because this is a brand new task.
      await _firestoreService.generateTaskInstancesForTask(
        roomId,
        docRef.id,
        daysAhead: 3,
        checkExisting: false,
      );
    } catch (e) {
      debugPrint('createTask: immediate generation (3 days) failed -> $e');
    }

    _firestoreService
        .generateTaskInstancesForTask(roomId, docRef.id, daysAhead: 30)
        .catchError((e) {
          debugPrint('createTask: background generation failed -> $e');
        });

    // Send notification to room members in BACKGROUND (don't await)
    // This allows the UI to pop immediately without waiting for extra reads/writes.
    Future.microtask(() async {
      try {
        final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
        final roomName = roomDoc.data()?['name'] as String? ?? 'Room';
        final categoryDoc = await _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('task_categories')
            .doc(categoryId)
            .get();
        final categoryName = categoryDoc.data()?['name'] as String? ?? 'Tasks';

        await NotificationHelper.notifyTaskCreated(
          roomId: roomId,
          roomName: roomName,
          taskTitle: title,
          categoryName: categoryName,
        );
      } catch (e) {
        debugPrint('createTask: notification failed -> $e');
      }
    });
  }

  Future<void> updateTask(String roomId, Task task) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .doc(task.id)
        .update(task.toMap());

    // If task becomes inactive, remove its scheduled instances.
    // If it stays active, you may want to regenerate to reflect changes.
    try {
      if (task.isActive == false) {
        await _firestoreService.deleteTaskInstancesForTask(roomId, task.id);
      }
    } catch (e) {
      debugPrint('updateTask: instance sync warning -> $e');
    }

    // Send notification
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final roomName = roomDoc.data()?['name'] as String? ?? 'Room';

      await NotificationHelper.notifyTaskEdited(
        roomId: roomId,
        roomName: roomName,
        taskTitle: task.title,
      );
    } catch (e) {
      debugPrint('updateTask: notification failed -> $e');
    }
  }

  Future<void> deleteTask(String roomId, String taskId) async {
    // Get task title for notification before deleting
    String taskTitle = 'Task';
    try {
      final taskDoc = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('tasks')
          .doc(taskId)
          .get();
      taskTitle = taskDoc.data()?['title'] as String? ?? 'Task';
    } catch (e) {
      debugPrint('deleteTask: failed to get task title -> $e');
    }

    // Delete the task document
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .doc(taskId)
        .delete();

    // Delete all task instances for this task
    final taskInstancesSnapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('taskInstances')
        .where('taskId', isEqualTo: taskId)
        .get();

    for (var doc in taskInstancesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Send notification
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final roomName = roomDoc.data()?['name'] as String? ?? 'Room';

      await NotificationHelper.notifyTaskDeleted(
        roomId: roomId,
        roomName: roomName,
        taskTitle: taskTitle,
      );
    } catch (e) {
      debugPrint('deleteTask: notification failed -> $e');
    }
  }

  Future<void> toggleTaskActive(String roomId, Task task) async {
    final newActive = !task.isActive;
    final updated = task.copyWith(isActive: newActive);
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .doc(task.id)
        .update(updated.toMap());

    // Sync taskInstances with activation state
    try {
      if (!newActive) {
        // Turning OFF: delete all instances for this task
        await _firestoreService.deleteTaskInstancesForTask(roomId, task.id);
      } else {
        // Turning ON: ensure future instances exist
        await _firestoreService.generateTaskInstancesForTask(roomId, task.id);
      }
    } catch (e) {
      debugPrint('toggleTaskActive: instance sync warning -> $e');
    }
  }

  // ==================== ROTATION ====================

  Future<void> rotateTask(String roomId, Task task) async {
    if (task.rotationType != RotationType.roundRobin) return;

    final newIndex = (task.currentRotationIndex + 1) % task.memberIds.length;
    await updateTask(roomId, task.copyWith(currentRotationIndex: newIndex));
  }

  String? getCurrentAssignee(Task task) {
    if (task.memberIds.isEmpty) return null;
    if (task.rotationType != RotationType.roundRobin) return null;

    return task.memberIds[task.currentRotationIndex % task.memberIds.length];
  }
}
