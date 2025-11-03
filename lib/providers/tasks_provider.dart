// lib/providers/tasks_provider.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Models/task_category.dart';
import '../Models/task.dart';

class TasksProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
          'colorValue': color.value,
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
    );

    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .add(task.toMap());
  }

  Future<void> updateTask(String roomId, Task task) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .doc(task.id)
        .update(task.toMap());
  }

  Future<void> deleteTask(String roomId, String taskId) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  Future<void> toggleTaskActive(String roomId, Task task) async {
    await updateTask(roomId, task.copyWith(isActive: !task.isActive));
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
