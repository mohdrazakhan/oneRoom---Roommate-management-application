// lib/Models/task_category.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final String roomId;
  final DateTime createdAt;

  TaskCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.roomId,
    required this.createdAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  factory TaskCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskCategory(
      id: doc.id,
      name: data['name'] ?? '',
      iconCodePoint: data['iconCodePoint'] ?? Icons.task_alt_rounded.codePoint,
      colorValue: data['colorValue'] ?? Colors.blue.value,
      roomId: data['roomId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'roomId': roomId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
