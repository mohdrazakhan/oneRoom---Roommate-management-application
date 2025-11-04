// Temporary debug script to check task data
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugTasks() async {
  final db = FirebaseFirestore.instance;

  // Get all rooms
  final roomsSnapshot = await db.collection('rooms').get();

  for (var roomDoc in roomsSnapshot.docs) {
    print('\n=== Room: ${roomDoc.id} (${roomDoc.data()['name']}) ===');

    // Get all tasks for this room
    final tasksSnapshot = await db
        .collection('rooms')
        .doc(roomDoc.id)
        .collection('tasks')
        .get();

    for (var taskDoc in tasksSnapshot.docs) {
      final data = taskDoc.data();
      print('Task ID: ${taskDoc.id}');
      print('  Title: ${data['title']}');
      print('  Name: ${data['name']}');
      print('  All fields: ${data.keys.toList()}');
      print('---');
    }
  }
}
