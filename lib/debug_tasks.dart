// Temporary debug script to check task data
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> debugTasks() async {
  final db = FirebaseFirestore.instance;

  // Get all rooms
  final roomsSnapshot = await db.collection('rooms').get();

  for (var roomDoc in roomsSnapshot.docs) {
    debugPrint('\n=== Room: ${roomDoc.id} (${roomDoc.data()['name']}) ===');

    // Get all tasks for this room
    final tasksSnapshot = await db
        .collection('rooms')
        .doc(roomDoc.id)
        .collection('tasks')
        .get();

    for (var taskDoc in tasksSnapshot.docs) {
      final data = taskDoc.data();
      debugPrint('Task ID: ${taskDoc.id}');
      debugPrint('  Title: ${data['title']}');
      debugPrint('  Name: ${data['name']}');
      debugPrint('  All fields: ${data.keys.toList()}');
      debugPrint('---');
    }
  }
}
